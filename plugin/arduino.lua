if vim.g.loaded_arduino then
  return
end
vim.g.loaded_arduino = 1

local arduino = require 'arduino'
local config = require 'arduino.config'

-- Setup with defaults if not already done by user in init.lua
if not config.is_setup then
  arduino.setup()
end

vim.api.nvim_create_user_command('ArduinoAttach', function(opts)
  arduino.attach(opts.args ~= '' and opts.args or nil)
end, { nargs = '?' })

vim.api.nvim_create_user_command('ArduinoChooseBoard', function()
  arduino.choose_board()
end, {})

vim.api.nvim_create_user_command('ArduinoChooseProgrammer', function()
  arduino.choose_programmer()
end, {})

vim.api.nvim_create_user_command('ArduinoVerify', function()
  arduino.verify()
end, {})

vim.api.nvim_create_user_command('ArduinoUpload', function()
  arduino.upload()
end, {})

vim.api.nvim_create_user_command('ArduinoSerial', function()
  arduino.serial()
end, {})

vim.api.nvim_create_user_command('ArduinoUploadAndSerial', function()
  arduino.upload_and_serial()
end, {})

vim.api.nvim_create_user_command('ArduinoGetInfo', function()
  arduino.get_info()
end, {})

vim.api.nvim_create_user_command('ArduinoInfo', function()
  arduino.get_info()
end, {})

vim.api.nvim_create_user_command('ArduinoChoosePort', function()
  arduino.choose_port()
end, {})

vim.api.nvim_create_user_command('ArduinoSetBaud', function(opts)
  arduino.set_baud(opts.args)
end, { nargs = 1 })
