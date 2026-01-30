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

vim.api.nvim_create_user_command('ArduinoSelectBoard', function()
  arduino.choose_board()
end, {})

vim.api.nvim_create_user_command('ArduinoSelectProgrammer', function()
  arduino.choose_programmer()
end, {})

vim.api.nvim_create_user_command('ArduinoVerify', function()
  arduino.verify()
end, {})

vim.api.nvim_create_user_command('ArduinoUpload', function()
  arduino.upload()
end, {})

vim.api.nvim_create_user_command('ArduinoMonitor', function()
  arduino.serial()
end, {})

vim.api.nvim_create_user_command('ArduinoUploadAndMonitor', function()
  arduino.upload_and_serial()
end, {})

vim.api.nvim_create_user_command('ArduinoCheckLogs', function()
  arduino.check_logs()
end, {})

vim.api.nvim_create_user_command('ArduinoLibraryManager', function()
  arduino.library_manager()
end, {})

vim.api.nvim_create_user_command('ArduinoCoreManager', function()
  arduino.core_manager()
end, {})

vim.api.nvim_create_user_command('ArduinoThirdPartyCore', function()
  arduino.add_third_party_core()
end, {})

vim.api.nvim_create_user_command('ArduinoGetInfo', function()
  arduino.get_info()
end, {})

vim.api.nvim_create_user_command('ArduinoSelectPort', function()
  arduino.choose_port()
end, {})

vim.api.nvim_create_user_command('ArduinoSetBaud', function(opts)
  arduino.set_baud(opts.args ~= '' and opts.args or nil)
end, { nargs = '?' })

vim.api.nvim_create_user_command('ArduinoSimulateAndMonitor', function()
  arduino.simulate_and_monitor()
end, {})

vim.api.nvim_create_user_command('ArduinoSimulateAndDebug', function()
  arduino.simulate_and_debug()
end, {})

vim.api.nvim_create_user_command('ArduinoSelectSimulator', function()
  arduino.select_simulator()
end, {})

vim.api.nvim_create_user_command('ArduinoResetSimulation', function()
  arduino.reset_simulation()
end, {})
