local config = require 'arduino.config'
local util = require 'arduino.util'
local M = {}

function M.get_ports(include_cli_discovery)
  local ports = {}
  -- Fast glob discovery
  for _, pattern in ipairs(config.options.serial_port_globs) do
    local found = vim.fn.glob(pattern, true, true)
    for _, port in ipairs(found) do
      table.insert(ports, port)
    end
  end

  -- Detailed discovery via arduino-cli (matched boards)
  if include_cli_discovery then
    local handle = io.popen 'arduino-cli board list --format json'
    if handle then
      local result = handle:read '*a'
      handle:close()
      local ok, data = pcall(vim.json.decode, result)
      if ok and data then
        for _, item in ipairs(data) do
          if item.port and item.port.address then
            -- Avoid duplicates from globs
            local exists = false
            for _, p in ipairs(ports) do
              if p == item.port.address then
                exists = true
                break
              end
            end
            if not exists then
              table.insert(ports, item.port.address)
            end
          end
        end
      end
    end
  end
  return ports
end

function M.guess_serial_port()
  -- Use only fast globs for guessing to avoid latency
  local ports = M.get_ports(false)
  if #ports > 0 then
    return ports[1]
  end
  return nil
end

function M.get_port()
  if vim.g.arduino_serial_port then
    return vim.g.arduino_serial_port
  end
  -- Check sketch config
  local sketch_cpu = util.get_sketch_config()
  if sketch_cpu and sketch_cpu.port then
    local p = sketch_cpu.port
    if p:match '^serial://' then
      return p:sub(10)
    end
    return p
  end
  return M.guess_serial_port()
end

function M.get_build_path()
  if not config.options.build_path or config.options.build_path == '' then
    return nil
  end
  local path = config.options.build_path
  path = path:gsub('{file}', vim.fn.expand '%:p')
  path = path:gsub('{project_dir}', vim.fn.expand '%:p:h')
  return path
end

function M.get_compile_command(extra_args)
  local build_path = M.get_build_path()

  -- Check sketch config for board preference
  local sketch_cpu = util.get_sketch_config()
  local board = (sketch_cpu and sketch_cpu.fqbn) or config.options.board

  local cmd = 'arduino-cli compile'
  if board then
    cmd = cmd .. ' -b ' .. board
  end

  if build_path then
    cmd = cmd .. ' --build-path "' .. build_path .. '"'
  end
  if extra_args then
    cmd = cmd .. ' ' .. extra_args
  end
  cmd = cmd .. ' ' .. config.options.cli_args
  cmd = cmd .. ' "' .. vim.fn.expand '%:p' .. '"'
  return cmd
end

function M.get_upload_command()
  local cmd = M.get_compile_command()
  local port = M.get_port()

  cmd = cmd:gsub('^arduino%-cli compile', 'arduino-cli compile -u')
  if port then
    cmd = cmd .. ' -p ' .. port
  end
  if config.options.programmer and config.options.programmer ~= '' then
    cmd = cmd .. ' -P ' .. config.options.programmer
  end
  return cmd
end

function M.get_upload_only_command()
  local build_path = M.get_build_path()
  local sketch_cpu = util.get_sketch_config()
  local board = (sketch_cpu and sketch_cpu.fqbn) or config.options.board
  local port = M.get_port()

  local cmd = 'arduino-cli upload'
  if board then
    cmd = cmd .. ' -b ' .. board
  end
  if port then
    cmd = cmd .. ' -p ' .. port
  end
  if build_path then
    cmd = cmd .. ' --input-dir "' .. build_path .. '"'
  end
  if config.options.programmer and config.options.programmer ~= '' then
    cmd = cmd .. ' -P ' .. config.options.programmer
  end
  cmd = cmd .. ' ' .. config.options.cli_args
  return cmd
end

function M.get_serial_command()
  local port = M.get_port()
  if not port then
    util.notify('No serial port found.', vim.log.levels.ERROR)
    return nil
  end

  local cmd = config.options.serial_cmd

  -- Expand simple tool names into templates
  if cmd == 'arduino-cli' then
    cmd = 'arduino-cli monitor -p {port} --config baudrate={baud}'
  elseif cmd == 'screen' then
    cmd = 'screen {port} {baud}'
  elseif cmd == 'minicom' then
    cmd = 'minicom -D {port} -b {baud}'
  elseif cmd == 'picocom' then
    cmd = 'picocom {port} -b {baud} -l'
  end

  -- Check if the first word of the command is executable
  local exe = cmd:match '^%S+'
  if vim.fn.executable(exe) ~= 1 then
    -- Fallback to arduino-cli monitor if the configured tool isn't available
    if exe ~= 'arduino-cli' then
      util.notify('Configured serial tool "' .. exe .. '" not found, falling back to arduino-cli.', vim.log.levels.WARN)
      cmd = 'arduino-cli monitor -p {port} --config baudrate={baud}'
    else
      util.notify('arduino-cli not found in PATH.', vim.log.levels.ERROR)
      return nil
    end
  end

  cmd = cmd:gsub('{port}', port)
  cmd = cmd:gsub('{baud}', config.options.serial_baud)
  return cmd
end

function M.get_board_details(fqbn)
  -- Strip existing options from FQBN if present to get base details
  local base_fqbn = fqbn:match '^([^:]+:[^:]+:[^:]+)' or fqbn

  local cmd = 'arduino-cli board details -b ' .. base_fqbn .. ' --format json'
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read '*a'
    handle:close()
    local ok, data = pcall(vim.json.decode, result)
    if ok then
      return data
    end
  end
  return nil
end

return M