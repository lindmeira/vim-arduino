local util = require 'arduino.util'
local config = require 'arduino.config'
local storage = require 'arduino.storage'

local M = {}

function M.read()
  return storage.get('build')
end

-- Write a build receipt. fqbn may be nil to use sketch/config default. mode is 'release' or 'debug'
function M.write(fqbn, mode)
  local sketch_cpu = util.get_sketch_config()
  local final_fqbn = (sketch_cpu and sketch_cpu.fqbn) or config.options.board
  if fqbn and fqbn ~= '' then final_fqbn = fqbn end

  local final_mode = mode or 'release'

  storage.update('build', { fqbn = final_fqbn, build_mode = final_mode })
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
