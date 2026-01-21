local M = {}

M.defaults = {
  board = 'arduino:avr:uno',
  programmer = '',
  args = '--verbose-upload',
  cli_args = '-v',
  serial_cmd = 'screen {port} {baud}',
  build_path = '{project_dir}/build',
  serial_baud = 9600,
  auto_baud = true,
  serial_port_globs = {
    '/dev/ttyACM*',
    '/dev/ttyUSB*',
    '/dev/tty.usbmodem*',
    '/dev/tty.usbserial*',
    '/dev/tty.wchusbserial*',
  },
  use_cli = true,
  hardware_dirs = {},
  use_telescope = true,
}

M.options = {}
M.is_setup = false

function M.setup(opts)
  M.is_setup = true
  opts = opts or {}

  -- Check for global variables for backward compatibility or user overrides
  local globals = {
    board = vim.g.arduino_board,
    programmer = vim.g.arduino_programmer,
    args = vim.g.arduino_args,
    cli_args = vim.g.arduino_cli_args,
    serial_cmd = vim.g.arduino_serial_cmd,
    build_path = vim.g.arduino_build_path,
    serial_baud = vim.g.arduino_serial_baud,
    auto_baud = vim.g.arduino_auto_baud,
    serial_port_globs = vim.g.arduino_serial_port_globs,
    use_cli = vim.g.arduino_use_cli,
  }

  -- Merge defaults, globals, and passed opts
  M.options = vim.tbl_deep_extend('force', M.defaults, globals, opts)

  -- Detect arduino-cli if use_cli is null/nil (though we defaulted to true above, let's be smart)
  if M.options.use_cli == nil then
    M.options.use_cli = vim.fn.executable 'arduino-cli' == 1
  end
end

return M
