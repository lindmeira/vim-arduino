local config = require 'arduino.config'
local cli = require 'arduino.cli'

local M = {}

function M.string()
  if vim.bo.filetype ~= 'arduino' then
    return ''
  end

  local board = config.options.board or 'No Board'
  local port = cli.get_port() or 'No Port'

  return string.format('[%s] (%s)', board, port)
end

return M
