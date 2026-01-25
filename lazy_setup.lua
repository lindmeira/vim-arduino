-- Typical arduino.nvim setup for LazyVim
return {
  'meira/vim-arduino',
  dependencies = {
    'nvim-telescope/telescope.nvim', -- Optional: for better UI/UX
  },
  ft = 'arduino',
  config = function()
    require('arduino').setup {
      use_cli = true, -- Use arduino-cli if available
      auto_baud = true,
      serial_baud = 57600,
      -- use_telescope = false, -- Defaults to true if available
      -- library_manager_emoji = false,
      -- build_path = "{project_dir}/build",
      -- serial_cmd = 'arduino-cli monitor -p {port} --config baudrate={baud}',
      --floating_window = { -- Configure floating windows style (logs, monitor)
      --  style = 'telescope', -- 'telescope' (default) or 'lualine'
      --},
    }
  end,
  keys = {
    { '<leader>aa', '<cmd>ArduinoAttach<cr>', desc = 'Attach Board' },
    { '<leader>ab', '<cmd>ArduinoChooseBoard<cr>', desc = 'Select Board' },
    { '<leader>ac', '<cmd>ArduinoVerify<cr>', desc = 'Compile/Verify' },
    { '<leader>af', '<cmd>ArduinoUpload<cr>', desc = 'Flash Firmware' },
    { '<leader>ai', '<cmd>ArduinoInfo<cr>', desc = 'Current Settings' },
    { '<leader>al', '<cmd>ArduinoCheckLogs<cr>', desc = 'Check Logs' },
    { '<leader>ap', '<cmd>ArduinoChoosePort<cr>', desc = 'Select Port' },
    { '<leader>ar', '<cmd>ArduinoSetBaud<cr>', desc = 'Baud Rate' },
    { '<leader>as', '<cmd>ArduinoSerial<cr>', desc = 'Serial Monitor' },
    { '<leader>at', '<cmd>ArduinoChooseProgrammer<cr>', desc = 'Select Programmer' },
    { '<leader>au', '<cmd>ArduinoUploadAndSerial<cr>', desc = 'Flash and Monitor' },
    -- Hidden shortcuts
    { '<leader>av', '<cmd>ArduinoVerify<cr>', desc = 'which_key_ignore' },
    -- Grouped shortcuts
    { '<leader>am', group = '+managers' },
    { '<leader>amc', '<cmd>ArduinoCoreManager<cr>', desc = 'Core Manager' },
    { '<leader>aml', '<cmd>ArduinoLibraryManager<cr>', desc = 'Library Manager' },
  },
}
