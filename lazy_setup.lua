return {
  'meira/vim-arduino',
  dependencies = {
    -- Optional: if you want a better UI for board/port selection
    'nvim-telescope/telescope.nvim',
  },
  ft = 'arduino',
  config = function()
    require('arduino').setup {
      -- Default configuration (can be omitted)
      use_cli = true, -- Use arduino-cli if available
      auto_baud = true,
      serial_baud = 9600,
      -- build_path = "{project_dir}/build",
    }
  end,
  keys = {
    { '<leader>ac', '<cmd>ArduinoVerify<cr>', desc = 'Verify/Compile' },
    { '<leader>ab', '<cmd>ArduinoChooseBoard<cr>', desc = 'Select Board' },
    { '<leader>ap', '<cmd>ArduinoChoosePort<cr>', desc = 'Select Port' },
    { '<leader>as', '<cmd>ArduinoSerial<cr>', desc = 'Serial Monitor' },
    { '<leader>au', '<cmd>ArduinoUpload<cr>', desc = 'Upload' },
  },
}
