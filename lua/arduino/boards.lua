local config = require 'arduino.config'
local util = require 'arduino.util'
local M = {}

-- Cache for hardware directories
M.hardware_dirs = {}

function M.reload_boards()
  M.hardware_dirs = {}
  -- Search arduino system install
  local arduino_dir = util.get_arduino_dir()
  local sys_boards = vim.fn.globpath(arduino_dir .. '/hardware', '**/boards.txt', true, true)
  for _, filename in ipairs(sys_boards) do
    local pieces = vim.split(filename, '/')
    -- This logic assumes a specific path structure.
    -- pieces[-3] is package, pieces[-2] is arch
    if #pieces >= 3 then
      local package_name = pieces[#pieces - 2]
      local arch = pieces[#pieces - 1]
      M.add_hardware_dir(package_name, arch, filename)
    end
  end

  -- Search user packages
  local arduino_home_dir = util.get_arduino_home_dir()
  local packagedirs = vim.fn.globpath(arduino_home_dir .. '/packages', '*', true, true)
  for _, packagedir in ipairs(packagedirs) do
    local package_name = vim.fn.fnamemodify(packagedir, ':t')
    local archdirs = vim.fn.globpath(packagedir .. '/hardware', '*', true, true)
    for _, archdir in ipairs(archdirs) do
      local arch = vim.fn.fnamemodify(archdir, ':t')
      local filenames = vim.fn.globpath(archdir, '**/boards.txt', true, true)
      for _, filename in ipairs(filenames) do
        M.add_hardware_dir(package_name, arch, filename)
      end
    end
  end

  if vim.fn.filereadable '/etc/arduino/boards.txt' == 1 then
    M.add_hardware_dir('arduino', 'avr', '/etc/arduino/boards.txt')
  end
end

function M.add_hardware_dir(package_name, arch, file)
  local filepath = file
  if vim.fn.isdirectory(file) == 0 then
    filepath = vim.fn.fnamemodify(file, ':h')
  end
  if vim.fn.isdirectory(filepath) == 0 then
    return
  end

  M.hardware_dirs[filepath] = {
    package = package_name,
    arch = arch,
  }
end

function M.get_boards()
  local boards = {}
  if config.options.use_cli then
    local cmd = 'arduino-cli board listall --format json'
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read '*a'
      handle:close()
      local ok, data = pcall(vim.json.decode, result)
      if ok and data.boards then
        for _, board in ipairs(data.boards) do
          table.insert(boards, {
            label = board.name,
            value = board.fqbn,
          })
        end
      end
    end
  else
    M.reload_boards()
    local seen = {}
    for dir, meta in pairs(M.hardware_dirs) do
      local filename = dir .. '/boards.txt'
      if vim.fn.filereadable(filename) == 1 then
        local lines = vim.fn.readfile(filename)
        for _, line in ipairs(lines) do
          -- Match line like 'uno.name=Arduino Uno'
          local id, name = line:match '^([^.]+)%.name=(.*)$'
          if id and name then
            local fqbn = meta.package .. ':' .. meta.arch .. ':' .. id
            if not seen[fqbn] then
              seen[fqbn] = true
              table.insert(boards, {
                label = name,
                value = fqbn,
              })
            end
          end
        end
      end
    end
  end
  table.sort(boards, function(a, b)
    return a.label < b.label
  end)
  return boards
end

function M.get_programmers()
  local programmers = { { label = '-None-', value = '' } }
  if config.options.use_cli then
    local board = config.options.board
    if not board then
      util.notify('Please select a board first.', vim.log.levels.WARN)
      return programmers
    end
    local cmd = 'arduino-cli board details -b ' .. board .. ' --list-programmers --format json'
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read '*a'
      handle:close()
      local ok, data = pcall(vim.json.decode, result)
      if ok and data.programmers then
        for _, entry in ipairs(data.programmers) do
          table.insert(programmers, {
            label = entry.name,
            value = entry.id,
          })
        end
      end
    end
    if #programmers > 1 then
      return programmers
    end
  end

  -- Fallback to boards.txt/programmers.txt parsing
  local seen = {}
  for dir, meta in pairs(M.hardware_dirs) do
    local filename = dir .. '/programmers.txt'
    if vim.fn.filereadable(filename) == 1 then
      local lines = vim.fn.readfile(filename)
      for _, line in ipairs(lines) do
        local id, name = line:match '^([^.]+)%.name=(.*)$'
        if id and name then
          local prog_id = meta.package .. ':' .. id
          if not seen[prog_id] then
            seen[prog_id] = true
            table.insert(programmers, {
              label = name,
              value = prog_id,
            })
          end
        end
      end
    end
  end
  return programmers
end

return M
