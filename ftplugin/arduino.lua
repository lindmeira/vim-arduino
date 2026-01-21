if vim.b.did_arduino_ftplugin then
  return
end

-- Ensure sketch.yaml exists for LSP
require('arduino.util').ensure_sketch_config()

vim.b.did_arduino_ftplugin = 1

local config = require 'arduino.config'

-- Ensure config is initialized (lazy loading compatibility)
if not config.is_setup then
  require('arduino').setup()
end

local cli = require 'arduino.cli'

-- Use C rules for indentation
vim.bo.cindent = true

-- Set makeprg
-- This allows users to use :make to compile
vim.bo.makeprg = cli.get_compile_command()

if config.options.auto_baud then
  local function sync_baud()
    if config.options.manual_baud then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local detected_baud = require('arduino.util').detect_baud_rate(lines)
    require('arduino').set_baud(detected_baud, true)
  end

  -- Trigger detection immediately for current buffer
  sync_baud()

  -- Also set up autocmd for future writes
  vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
    buffer = 0,
    callback = sync_baud,
  })
end

-- Check for LSP attachment
local bufnr = vim.api.nvim_get_current_buf()
vim.defer_fn(function()
  if vim.api.nvim_buf_is_valid(bufnr) then
    local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'arduino_language_server' }
    if #clients == 0 then
      vim.notify('Arduino LSP failed to attach.', vim.log.levels.WARN, { title = 'Arduino' })
    end
  end
end, 1000)
