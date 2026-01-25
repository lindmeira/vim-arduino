local util = require 'arduino.util'
local M = {}

function M.get_boards()
  local boards = {}
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
  table.sort(boards, function(a, b)
    return a.label < b.label
  end)
  return boards
end

function M.get_programmers()
  local programmers = { { label = '-None-', value = '' } }
  local board = require('arduino.config').options.board
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
  return programmers
end

return M