if vim.b.did_arduino_ftplugin then
  return
end

-- Ensure sketch.yaml exists for LSP
require('arduino.util').ensure_sketch_config()

vim.b.did_arduino_ftplugin = 1

local config = require 'arduino.config'
local cli = require 'arduino.cli'

-- Use C rules for indentation
vim.bo.cindent = true

-- Set makeprg
-- This allows users to use :make to compile
vim.bo.makeprg = cli.get_compile_command()

if config.options.auto_baud then
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    buffer = 0,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      for _, line in ipairs(lines) do
        local baud = line:match 'Serial[0-9]*%.begin%((%d+)%)'
        if baud then
          require('arduino').set_baud(baud)
          break
        end
      end
    end,
  })
end

-- Check for LSP attachment
local bufnr = vim.api.nvim_get_current_buf()
vim.defer_fn(function()
  if vim.api.nvim_buf_is_valid(bufnr) then
    local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'arduino_language_server' })
    if #clients == 0 then
      vim.notify('Arduino LSP failed to attach.', vim.log.levels.WARN, { title = 'Arduino' })
    end
  end
end, 1000)