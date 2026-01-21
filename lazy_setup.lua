return {
  'meira/vim-arduino',
  dependencies = {
    -- Optional: if you want a better UI for board/port selection
    -- 'nvim-telescope/telescope.nvim',
  },
  ft = 'arduino',
  config = function()
    require('arduino').setup {
      -- Default configuration (can be omitted)
      use_cli = true, -- Use arduino-cli if available
      auto_baud = true,
      serial_baud = 57600,
      use_telescope = false, -- Use Telescope for UI if available
      -- build_path = "{project_dir}/build",
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
    { '<leader>as', '<cmd>ArduinoSerial<cr>', desc = 'Serial Monitor' },
    { '<leader>at', '<cmd>ArduinoChooseProgrammer<cr>', desc = 'Select Programmer' },
    { '<leader>au', '<cmd>ArduinoUploadAndSerial<cr>', desc = 'Flash and Monitor' },
    { '<leader>av', '<cmd>ArduinoVerify<cr>', desc = 'which_key_ignore' },
  },
}
