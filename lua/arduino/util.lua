local config = require 'arduino.config'
local M = {}

M.os = vim.uv.os_uname().sysname

function M.get_arduino_home_dir()
  if vim.g.arduino_home_dir then
    return vim.g.arduino_home_dir
  end
  if M.os == 'Darwin' then
    return os.getenv 'HOME' .. '/Library/Arduino15'
  end
  return os.getenv 'HOME' .. '/.arduino15'
end

function M.read_json(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local content = f:read '*a'
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if ok then
    return data
  else
    return nil
  end
end

function M.read_yaml_simple(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local content = f:read '*a'
  f:close()

  local data = { cpu = {} }
  -- Very basic parsing
  local cpu = data.cpu

  for line in content:gmatch '[^\r\n]+' do
    local key, value = line:match '^%s*([%w_]+):%s*(.+)$'
    if key and value then
      -- Remove quotes safely
      if value:sub(1, 1) == '"' and value:sub(-1) == '"' then
        value = value:sub(2, -2)
      elseif value:sub(1, 1) == "'" and value:sub(-1) == "'" then
        value = value:sub(2, -2)
      end

      if key == 'fqbn' or key == 'default_fqbn' then
        cpu.fqbn = value
      elseif key == 'port' or key == 'default_port' then
        cpu.port = value
      elseif key == 'programmer' or key == 'default_programmer' then
        cpu.programmer = value
      end
    end
  end
  return data
end

function M.write_json(path, data)
  local f = io.open(path, 'w')
  if not f then
    return false
  end
  local ok, content = pcall(vim.json.encode, data)
  if ok then
    f:write(content)
    f:close()
    return true
  else
    f:close()
    return false
  end
end

function M.notify(msg, level)
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        vim.defer_fn(function()
          vim.notify(msg, level or vim.log.levels.INFO, { title = 'Arduino' })
        end, 200)
      end,
      once = true,
    })
  else
    vim.notify(msg, level or vim.log.levels.INFO, { title = 'Arduino' })
  end
end

function M.find_sketch_config(dir)
  dir = dir or vim.fn.expand '%:p:h'
  -- local root = dir
  while true do
    local sketch_yaml = dir .. '/sketch.yaml'
    if vim.fn.filereadable(sketch_yaml) == 1 then
      return sketch_yaml, 'yaml'
    end
    local sketch_json = dir .. '/sketch.json'
    if vim.fn.filereadable(sketch_json) == 1 then
      return sketch_json, 'json'
    end
    local next_dir = vim.fn.fnamemodify(dir, ':h')
    if next_dir == dir then
      break
    end
    dir = next_dir
  end
  return nil, nil
end

function M.get_sketch_config(dir)
  local sketch_file, type = M.find_sketch_config(dir)
  if sketch_file then
    if type == 'yaml' then
      local data = M.read_yaml_simple(sketch_file)
      if data and data.cpu then
        return data.cpu
      end
    else
      local data = M.read_json(sketch_file)
      if data and data.cpu then
        return data.cpu
      end
    end
  end
  return nil
end

function M.update_sketch_config(key, value, dir)
  dir = dir or vim.fn.expand '%:p:h'
  local sketch_file, type = M.find_sketch_config(dir)

  -- Always use YAML (sketch.yaml) for arduino-cli projects
  local path = (type == 'yaml' and sketch_file) or (dir .. '/sketch.yaml')
  local cpu = M.get_sketch_config(dir) or {}

  if key == 'fqbn' then
    cpu.fqbn = value
  elseif key == 'port' then
    cpu.port = value
  elseif key == 'programmer' then
    cpu.programmer = value
  end

  local f = io.open(path, 'w')
  if f then
    if cpu.fqbn and cpu.fqbn ~= '' then
      f:write('default_fqbn: ' .. cpu.fqbn .. '\n')
    end
    if cpu.port and cpu.port ~= '' then
      f:write('default_port: ' .. cpu.port .. '\n')
    end
    if cpu.programmer and cpu.programmer ~= '' then
      f:write('default_programmer: ' .. cpu.programmer .. '\n')
    end
    f:close()
    if key == 'fqbn' then
      M.restart_lsp()
    end
  else
    M.notify('Failed to update sketch.yaml.', vim.log.levels.ERROR)
  end
end

function M.ensure_sketch_config(dir)
  dir = dir or vim.fn.expand '%:p:h'
  if not dir or dir == '' or dir == '.' then
    return
  end
  local sketch_file, _ = M.find_sketch_config(dir)
  if not sketch_file then
    local default_yaml = 'default_fqbn: arduino:avr:uno\n'
    local path = dir .. '/sketch.yaml'
    local f = io.open(path, 'w')
    if f then
      f:write(default_yaml)
      f:close()
      M.notify 'Created default sketch.yaml.'
    else
      M.notify('Failed to create sketch.yaml.', vim.log.levels.ERROR)
    end
  end
end

function M.restart_lsp()
  -- Try LspRestart if available (part of nvim-lspconfig)
  if vim.fn.exists ':LspRestart' == 2 then
    -- Only restart if arduino_language_server is active
    local clients = vim.lsp.get_clients { name = 'arduino_language_server' }
    if #clients > 0 then
      M.notify 'Restarting Arduino LSP...'
      vim.cmd 'LspRestart arduino_language_server'
    end
  else
    M.notify('LspRestart not available, please restart editor to apply LSP changes.', vim.log.levels.WARN)
  end
end

--- Remove C/C++/Arduino style comments from a line
---@param line string: The line to clean
---@return string: Line with comments removed
local function strip_comments(line)
  -- Remove /* */ block comments (handles multi-line blocks on single lines)
  line = line:gsub('/%*.-%*/', '')
  -- Remove // line comments
  line = line:gsub('//.*', '')
  -- Trim whitespace
  return line:match '^%s*(.-)%s*$' or line
end

--- Detect baud rate from Arduino sketch content
---@param lines table: Array of buffer lines to analyze
---@return number: Detected baud rate (falls back to configured serial_baud or 9600)
function M.detect_baud_rate(lines)
  local default_baud = tonumber(config.options.original_baud) or tonumber(config.options.serial_baud) or 9600

  -- Look for Serial.begin() calls and return the first valid match
  for _, line in ipairs(lines) do
    -- Strip comments before pattern matching to avoid false positives
    local clean_line = strip_comments(line)
    local baud_str = clean_line:match 'Serial[0-9]*%.begin%s*%(%s*(%d+)%s*%)'
    if baud_str then
      local baud = tonumber(baud_str)
      if baud and config.VALID_BAUD_RATES[baud] then
        return baud
      end
      -- Found a Serial.begin but the baud rate is invalid
      M.notify('Invalid baud rate: ' .. baud_str, vim.log.levels.ERROR)
      return default_baud
    end
  end

  -- No valid Serial.begin() found, return the configured default
  return default_baud
end

--- Format bytes to human readable string
---@param b number|string: Bytes
---@return string: Formatted string
local function format_bytes(b)
  local val = tonumber(b)
  if not val then
    return '0B'
  end
  if val >= 1048576 then
    return string.format('%.1fMB', val / 1048576)
  elseif val >= 1024 then
    return string.format('%.1fKB', val / 1024)
  end
  return val .. 'B'
end

--- Parse memory usage from logs and return a formatted string
---@return string|nil: Formatted memory usage string or nil if not found
function M.get_memory_usage_info()
  local log_data = require('arduino.log').get()
  local flash_used, flash_perc, flash_max
  local ram_used, ram_perc, ram_max

  for _, line in ipairs(log_data) do
    -- Program storage (Flash)
    local f_used, f_perc, f_max = line:match 'Sketch uses (%d+) bytes %((%d+)%%%).-Maximum is (%d+) bytes'
    if f_used then
      flash_used, flash_perc, flash_max = f_used, f_perc, f_max
    end

    -- Dynamic memory (RAM)
    local r_used, r_perc, r_max = line:match 'Global variables use (%d+) bytes %((%d+)%%%).-Maximum is (%d+) bytes'
    if r_used then
      ram_used, ram_perc, ram_max = r_used, r_perc, r_max
    end
  end

  if flash_used and ram_used then
    return string.format(
      'Flash: %s%% (%s/%s), RAM: %s%% (%s/%s).',
      flash_perc,
      format_bytes(flash_used),
      format_bytes(flash_max),
      ram_perc,
      format_bytes(ram_used),
      format_bytes(ram_max)
    )
  end
  return nil
end

-- UI Helper
function M.select_item(items, prompt, callback)
  -- items: list of {label=..., value=...}
  local telescope_avail = false
  if config.options.use_telescope then
    local ok, _ = pcall(require, 'telescope')
    telescope_avail = ok
  end

  if telescope_avail then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt,
        finder = finders.new_table {
          results = items,
          entry_maker = function(entry)
            return {
              value = entry.value,
              display = entry.label,
              ordinal = entry.label,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        -- attach_mappings = function(prompt_bufnr, map)
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              callback(selection.value)
            end
          end)
          return true
        end,
      })
      :find()
    return
  end

  -- Fallback to vim.ui.select
  local on_choice = function(item)
    if item then
      callback(item.value)
    end
  end

  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    on_choice(choice)
  end)
end

return M
