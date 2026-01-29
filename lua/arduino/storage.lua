local util = require 'arduino.util'

local M = {}

local function get_file_path()
  local sketch_file, _ = util.find_sketch_config(vim.fn.expand '%:p:h')
  local dir
  if sketch_file then
    dir = vim.fn.fnamemodify(sketch_file, ':h')
  else
    dir = vim.fn.expand '%:p:h'
  end
  return dir .. '/.arduino.nvim.json'
end

function M.load()
  local path = get_file_path()
  if not path or vim.fn.filereadable(path) == 0 then
    return {}
  end
  local f = io.open(path, 'r')
  if not f then return {} end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or {}
end

function M.save(data)
  local path = get_file_path()
  if not path then return end
  
  local f = io.open(path, 'w')
  if f then
    f:write(vim.json.encode(data))
    f:close()
  end
end

function M.update(key, value)
  local data = M.load()
  data[key] = value
  M.save(data)
end

function M.get(key)
  local data = M.load()
  return data[key]
end

return M
