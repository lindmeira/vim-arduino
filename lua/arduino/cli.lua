local config = require 'arduino.config'
local util = require 'arduino.util'
local M = {}

function M.get_ports()
  local ports = {}
  for _, pattern in ipairs(config.options.serial_port_globs) do
    local found = vim.fn.glob(pattern, true, true)
    for _, port in ipairs(found) do
      table.insert(ports, port)
    end
  end
  -- Could also use arduino-cli board list
  if config.options.use_cli then
    local handle = io.popen 'arduino-cli board list --format json'
    if handle then
      local result = handle:read '*a'
      handle:close()
      local ok, data = pcall(vim.json.decode, result)
      if ok and data then
        for _, item in ipairs(data) do
          if item.port and item.port.address then
            -- Check if already in ports to avoid duplicates
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
  local ports = M.get_ports()
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
  local cmd = ''
  local build_path = M.get_build_path()

  -- Check sketch config for board preference
  local sketch_cpu = util.get_sketch_config()
  local board = (sketch_cpu and sketch_cpu.fqbn) or config.options.board
  local programmer = config.options.programmer

  if config.options.use_cli then
    cmd = 'arduino-cli compile'
    -- If no sketch.json overrides, add flags
    -- Logic: The original checked s:SKETCHFILE == v:null.
    -- We check if we are using the global config or sketch config.
    -- Actually, arduino-cli picks up sketch.json automatically if in dir.
    -- But we might need to be explicit if we want to enforce vim global settings over it?
    -- The original script appended flags only if sketch.json was NOT found (s:SKETCHFILE is null).
    -- BUT, it also updated s:SKETCHFILE when found.

    -- Let's try to pass flags. If sketch.json exists, arduino-cli might warn or override.
    -- Safer to pass flags if we want to enforce current vim settings.

    if board then
      cmd = cmd .. ' -b ' .. board
    end
    local port = M.get_port()
    if port then
      cmd = cmd .. ' -p ' .. port
    end
    if programmer and programmer ~= '' then
      cmd = cmd .. ' -P ' .. programmer
    end
    if build_path then
      cmd = cmd .. ' --build-path "' .. build_path .. '"'
    end
    if extra_args then
      cmd = cmd .. ' ' .. extra_args
    end
    cmd = cmd .. ' ' .. config.options.cli_args
  else
    -- Old arduino executable
    local exe = util.get_arduino_executable()
    if config.options.run_headless then
      exe = vim.fn.fnamemodify(vim.api.nvim_get_runtime_file('bin/run-headless', false)[1], ':p') .. ' ' .. exe
      -- Note: run-headless path resolution might need adjustment
    end
    cmd = exe .. ' --verify --board ' .. board
    local port = M.get_port()
    if port then
      cmd = cmd .. ' --port ' .. port
    end
    if programmer and programmer ~= '' then
      cmd = cmd .. ' --pref programmer=' .. programmer
    end
    if build_path then
      cmd = cmd .. ' --pref build.path=' .. build_path
    end
    cmd = cmd .. ' ' .. config.options.args
  end

  cmd = cmd .. ' "' .. vim.fn.expand '%:p' .. '"'
  return cmd
end

function M.get_upload_command()
  if config.options.use_cli then
    return M.get_compile_command '-u'
  else
    local cmd = M.get_compile_command()
    cmd = cmd:gsub('%-%-verify', '') -- Remove verify
    if config.options.programmer and config.options.programmer ~= '' then
      cmd = cmd .. ' --upload --useprogrammer'
    else
      cmd = cmd .. ' --upload'
    end
    return cmd
  end
end

function M.get_serial_command()
  local port = M.get_port()
  if not port then
    util.notify('No serial port found', vim.log.levels.ERROR)
    return nil
  end
  local cmd = config.options.serial_cmd
  cmd = cmd:gsub('{port}', port)
  cmd = cmd:gsub('{baud}', config.options.serial_baud)
  return cmd
end

return M
