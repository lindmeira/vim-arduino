local config = require 'arduino.config'
local util = require 'arduino.util'
local boards = require 'arduino.boards'
local cli = require 'arduino.cli'
local term = require 'arduino.term'

local M = {}

function M.setup(opts)
  config.setup(opts)

  local function check_deps()
    if vim.fn.executable 'arduino-cli' ~= 1 then
      vim.notify_once('Application arduino-cli not found.', vim.log.levels.WARN, { title = 'Arduino' })
    end
  end

  -- Simple deferred check to allow UI plugins to initialize
  if vim.v.vim_did_enter == 1 then
    vim.defer_fn(check_deps, 200)
  else
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        vim.defer_fn(check_deps, 200)
      end,
      once = true,
    })
  end

  -- Auto-detect board from sketch config
  local cpu = util.get_sketch_config()
  if cpu and cpu.fqbn then
    config.options.board = cpu.fqbn
  end

  M.reload_boards()

  -- Automatic Lualine integration
  local has_lualine, lualine = pcall(require, 'lualine')
  if has_lualine then
    local lualine_config = lualine.get_config()
    local extensions = lualine_config.extensions or {}

    -- Check if arduino extension already exists
    local has_arduino_ext = false
    for _, ext in ipairs(extensions) do
      if type(ext) == 'table' and ext.filetypes and vim.tbl_contains(ext.filetypes, 'arduino') then
        has_arduino_ext = true
        break
      end
    end

    if not has_arduino_ext then
      -- Create an extension that inherits from global sections but adds ours
      local sections = vim.deepcopy(lualine_config.sections or {})

      -- Inject into lualine_x (or lualine_c if preferred, but x is usually auxiliary)
      -- If lualine_x doesn't exist, create it
      sections.lualine_x = sections.lualine_x or {}

      -- Prepend our component
      table.insert(sections.lualine_x, 1, require('arduino.status').string)

      local arduino_extension = {
        sections = sections,
        filetypes = { 'arduino' },
      }

      table.insert(extensions, arduino_extension)
      lualine_config.extensions = extensions
      lualine.setup(lualine_config)
    end
  end
end

function M.reload_boards()
  -- Only needed for non-cli or cache warming
  if not config.options.use_cli then
    boards.reload_boards()
  end
end

-- UI Helper
local function select_item(items, prompt, callback)
  -- items: list of {label=..., value=...}
  local on_choice = function(item)
    if item then
      callback(item.value)
    end
  end

  local telescope_avail, telescope = pcall(require, 'telescope')
  -- Logic to choose UI
  -- Use vim.ui.select as standard
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    on_choice(choice)
  end)
end

function M.attach(port)
  if not config.options.use_cli then
    util.notify('ArduinoAttach requires arduino-cli', vim.log.levels.ERROR)
    return
  end

  local function perform_attach(p)
    local cmd = { 'arduino-cli', 'board', 'attach', '-p', p }
    -- This command needs to run in the background, not terminal
    vim.fn.jobstart(cmd, {
      on_exit = function(id, code, _)
        if code == 0 then
          vim.g.arduino_serial_port = p
          -- Update sketch config
          util.get_sketch_config(vim.fn.expand '%:p:h') -- Refresh cache/lookup

          -- Try to detect the board from the port we just attached to
          if config.options.use_cli then
            local handle = io.popen 'arduino-cli board list --format json'
            if handle then
              local result = handle:read '*a'
              handle:close()
              local ok, data = pcall(vim.json.decode, result)
              if ok and data then
                for _, item in ipairs(data) do
                  if item.port and item.port.address == p and item.matching_boards and #item.matching_boards > 0 then
                    config.options.board = item.matching_boards[1].fqbn
                    break
                  end
                end
              end
            end
          end

          util.notify('Arduino attached to ' .. (config.options.board or 'unknown'))
        else
          util.notify('Failed to attach', vim.log.levels.ERROR)
        end
      end,
    })
  end

  if port then
    perform_attach(port)
  else
    local ports = cli.get_ports(true)
    if #ports == 0 then
      util.notify('No serial ports found', vim.log.levels.WARN)
    elseif #ports == 1 then
      perform_attach(ports[1])
    else
      local items = {}
      for _, p in ipairs(ports) do
        table.insert(items, { label = p, value = p })
      end
      select_item(items, 'Select Port to Attach', perform_attach)
    end
  end
end

function M.choose_board()
  local b_list = boards.get_boards()
  select_item(b_list, 'Select Board', function(value)
    config.options.board = value
    util.notify('Selected board: ' .. value)
    -- Also update sketch.json if exists?
    -- The original did s:WriteSketchKey('fqbn', g:arduino_board)
    util.update_sketch_config('fqbn', value)
  end)
end

function M.choose_programmer()
  local p_list = boards.get_programmers()
  select_item(p_list, 'Select Programmer', function(value)
    config.options.programmer = value
    util.notify('Selected programmer: ' .. value)
    -- util.update_sketch_config('programmer', value) -- Not standard sketch.json key?
  end)
end

function M.choose_port()
  local ports = cli.get_ports(true)
  if #ports == 0 then
    util.notify('No serial ports found', vim.log.levels.WARN)
    return
  end
  local items = {}
  for _, p in ipairs(ports) do
    table.insert(items, { label = p, value = p })
  end
  select_item(items, 'Select Port', function(value)
    vim.g.arduino_serial_port = value -- Set global as overrides
    -- Update sketch config
    util.update_sketch_config('port', value)
    util.notify('Selected port: ' .. value)
  end)
end

function M.verify()
  local cmd = cli.get_compile_command()
  term.run(cmd)
end

function M.upload()
  local cmd = cli.get_upload_command()
  term.run(cmd)
end

function M.serial()
  local cmd = cli.get_serial_command()
  if cmd then
    term.run(cmd)
  end
end

function M.upload_and_serial()
  local upload_cmd = cli.get_upload_command()
  term.run_and_callback(upload_cmd, function()
    M.serial()
  end)
end

function M.get_info()
  local info = {}
  table.insert(info, 'Board: ' .. (config.options.board or 'None'))
  table.insert(info, 'Programmer: ' .. (config.options.programmer or 'None'))
  table.insert(info, 'Port: ' .. (cli.get_port() or 'None'))
  table.insert(info, 'Baud: ' .. config.options.serial_baud)
  if config.options.use_cli then
    table.insert(info, 'Verify Cmd: ' .. cli.get_compile_command())
  end
  print(table.concat(info, '\n'))
end

function M.set_baud(baud)
  config.options.serial_baud = baud
  print('Baud rate set to ' .. baud)
end

return M
