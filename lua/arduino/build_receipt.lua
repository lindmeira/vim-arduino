local util = require 'arduino.util'
local config = require 'arduino.config'

local M = {}

local function get_path()
  local sketch_file, _ = util.find_sketch_config(vim.fn.expand '%:p:h')
  local dir
  if sketch_file then
    dir = vim.fn.fnamemodify(sketch_file, ':h')
  else
    dir = vim.fn.expand '%:p:h'
  end
  return dir .. '/.build_receipt.json'
end

function M.read()
  local path = get_path()
  if not path or vim.fn.filereadable(path) == 0 then
    return nil
  end
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if ok and data then return data end
  return nil
end

-- Write a build receipt. fqbn may be nil to use sketch/config default. mode is 'release' or 'debug'
function M.write(fqbn, mode)
  local path = get_path()
  if not path then return end
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  local sketch_cpu = util.get_sketch_config()
  local final_fqbn = (sketch_cpu and sketch_cpu.fqbn) or config.options.board
  if fqbn and fqbn ~= '' then final_fqbn = fqbn end

  local final_mode = mode or 'release'

  local f = io.open(path, 'w')
  if f then
    f:write(vim.json.encode({ fqbn = final_fqbn, build_mode = final_mode }))
    f:close()
  end
end

-- Check whether current receipt matches current sketch FQBN and (optionally) desired mode
function M.matches(desired_mode)
  local data = M.read()
  if not data or not data.fqbn then return false end

  local sketch_cpu = util.get_sketch_config()
  local current_fqbn = (sketch_cpu and sketch_cpu.fqbn) or config.options.board
  if data.fqbn ~= current_fqbn then return false end

  if desired_mode and data.build_mode ~= desired_mode then return false end
  return true
end

return M
