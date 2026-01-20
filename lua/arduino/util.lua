local config = require 'arduino.config'
local M = {}

M.os = vim.loop.os_uname().sysname

function M.get_arduino_executable()
  if vim.g.arduino_cmd then
    return vim.g.arduino_cmd
  elseif M.os == 'Darwin' then
    return '/Applications/Arduino.app/Contents/MacOS/Arduino'
  else
    return 'arduino'
  end
end

function M.get_arduino_dir()
  if vim.g.arduino_dir then
    return vim.g.arduino_dir
  end
  local executable = M.get_arduino_executable()
  local arduino_cmd = vim.fn.exepath(executable)
  local arduino_dir = vim.fn.fnamemodify(arduino_cmd, ':h')
  if M.os == 'Darwin' then
    arduino_dir = vim.fn.fnamemodify(arduino_dir, ':h') .. '/Java'
  end
  return arduino_dir
end

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
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'Arduino' })
end

function M.find_sketch_config(dir)
  dir = dir or vim.fn.expand '%:p:h'
  local root = dir
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

  -- If using CLI and either no config exists or it's YAML, use manual YAML update with specific format
  if config.options.use_cli and (not sketch_file or type == 'yaml') then
    local path = sketch_file or (dir .. '/sketch.yaml')
    local cpu = M.get_sketch_config(dir) or {}

    if key == 'fqbn' then
      cpu.fqbn = value
    elseif key == 'port' then
      cpu.port = value
    end

    local f = io.open(path, 'w')
    if f then
      f:write('default_fqbn: ' .. (cpu.fqbn or '') .. '\n')
      f:write('default_port: ' .. (cpu.port or '') .. '\n')
      f:close()
      M.restart_lsp()
    else
      M.notify('Failed to update sketch.yaml', vim.log.levels.ERROR)
    end
    return
  end

  -- Fallback to JSON manipulation
  if not sketch_file then
    sketch_file = dir .. '/sketch.json'
  end

  local data = M.read_json(sketch_file) or {}
  data.cpu = data.cpu or {}
  data.cpu[key] = value
  M.write_json(sketch_file, data)
  M.restart_lsp()
end

function M.ensure_sketch_config(dir)
  dir = dir or vim.fn.expand '%:p:h'
  local sketch_file, _ = M.find_sketch_config(dir)
  if not sketch_file then
    local default_yaml = 'default_fqbn: arduino:avr:uno\ndefault_port: /dev/ttyUSB0\n'
    local path = dir .. '/sketch.yaml'
    local f = io.open(path, 'w')
    if f then
      f:write(default_yaml)
      f:close()
      M.notify 'Created default sketch.yaml'
    else
      M.notify('Failed to create sketch.yaml', vim.log.levels.ERROR)
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
    M.notify('LspRestart not available, please restart editor to apply LSP changes', vim.log.levels.WARN)
  end
end

return M

