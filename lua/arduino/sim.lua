local util = require 'arduino.util'
local config = require 'arduino.config'
local cli = require 'arduino.cli'
local term = require 'arduino.term'

local M = {}

-- Supported simulators
local SIMULATORS = {
  { label = 'SimAVR', value = 'simavr' },
}

-- SimAVR Mappings (FQBN -> MCU)
-- Frequency is usually standard for these boards but we'll verify
local FQBN_MAP = {
  ['arduino:avr:uno'] = { mcu = 'atmega328p', freq = 16000000 },
  ['arduino:avr:nano'] = { mcu = 'atmega328p', freq = 16000000 },
  ['arduino:avr:mega'] = { mcu = 'atmega2560', freq = 16000000 },
  ['arduino:avr:leonardo'] = { mcu = 'atmega32u4', freq = 16000000 },
  ['arduino:avr:micro'] = { mcu = 'atmega32u4', freq = 16000000 },
  ['arduino:avr:yun'] = { mcu = 'atmega32u4', freq = 16000000 },
}

local function get_config_path()
  local build_path = cli.get_build_path()
  if not build_path then
    return nil
  end
  return build_path .. '/simulation.yaml'
end

local function read_simulation_config()
  local path = get_config_path()
  if not path or vim.fn.filereadable(path) == 0 then
    return nil
  end

  local f = io.open(path, 'r')
  if not f then
    return nil
  end

  local data = {}
  for line in f:lines() do
    local k, v = line:match '^%s*(%w+):%s*(.+)$'
    if k and v then
      data[k] = v
    end
  end
  f:close()

  return data
end

local function save_simulation_config(mcu, freq, fqbn, simulator)
  local path = get_config_path()
  if not path then
    return
  end

  -- Ensure build dir exists
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  local current = read_simulation_config() or {}

  local data = {
    mcu = mcu or current.mcu,
    freq = freq or current.freq,
    fqbn = fqbn or current.fqbn,
    simulator = simulator or current.simulator,
  }

  local f = io.open(path, 'w')
  if f then
    if data.mcu then
      f:write('mcu: ' .. data.mcu .. '\n')
    end
    if data.freq then
      f:write('freq: ' .. data.freq .. '\n')
    end
    if data.fqbn then
      f:write('fqbn: ' .. data.fqbn .. '\n')
    end
    if data.simulator then
      f:write('simulator: ' .. data.simulator .. '\n')
    end
    f:close()
  end
end

local function launch_simavr(mcu, freq, elf_path)
  local cmd = string.format('simavr --mcu %s --freq %s "%s"', mcu, freq, elf_path)

  -- Reuse terminal window logic (similar to init.lua serial)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.ceil(vim.o.columns * 0.8)
  local height = math.ceil(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.ceil((vim.o.columns - width) / 2)

  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' SimAVR ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value('winhl', 'Normal:ArduinoWindowNormal,FloatBorder:ArduinoWindowBorder,FloatTitle:ArduinoWindowTitle', { win = win })

  local killing_sim = false

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, code)
      if code ~= 0 and not killing_sim then
        util.notify('Simulation exited with code ' .. code, vim.log.levels.WARN)
      end
    end,
  })

  vim.cmd 'startinsert'

  -- Ensure process is killed when buffer/window is closed
  vim.api.nvim_create_autocmd({ 'BufUnload', 'WinClosed' }, {
    buffer = buf,
    callback = function()
      if job_id then
        killing_sim = true
        pcall(vim.fn.jobstop, job_id)
      end
    end,
  })

  -- Keymaps for closing
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('t', '<Esc>', '<C-\\><C-n><cmd>close<cr>', opts)
  vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)
end

local function ensure_elf_and_run(mcu, freq)
  local build_path = cli.get_build_path()
  if not build_path then
    util.notify('Build path not configured.', vim.log.levels.ERROR)
    return
  end

  local elf_files = vim.fn.glob(build_path .. '/*.elf', true, true)
  local elf_file = nil
  if #elf_files > 0 then
    elf_file = elf_files[1]
  end

  local function run()
    if not elf_file or vim.fn.filereadable(elf_file) == 0 then
      elf_files = vim.fn.glob(build_path .. '/*.elf', true, true)
      if #elf_files > 0 then
        elf_file = elf_files[1]
      end
    end

    if elf_file and vim.fn.filereadable(elf_file) == 1 then
      launch_simavr(mcu, freq, elf_file)
    else
      util.notify('Could not locate compiled .elf file.', vim.log.levels.ERROR)
    end
  end

  if not elf_file then
    util.notify('Build artifact not found. Compiling first...', vim.log.levels.INFO)
    local cmd = cli.get_compile_command()
    term.run_silent(cmd, 'Compilation', run)
  else
    run()
  end
end

local function select_mcu_and_freq(callback)
  local handle = io.popen 'simavr --list-cores'
  if not handle then
    util.notify('Failed to run simavr --list-cores', vim.log.levels.ERROR)
    return
  end
  local result = handle:read '*a'
  handle:close()

  local mcus = {}
  local is_first_line = true
  for line in result:gmatch '[^\r\n]+' do
    if is_first_line then
      is_first_line = false
    else
      for mcu in line:gmatch '%S+' do
        table.insert(mcus, { label = mcu, value = mcu })
      end
    end
  end

  if #mcus == 0 then
    util.notify('No MCUs found from simavr.', vim.log.levels.ERROR)
    return
  end

  require('arduino.util').select_item(mcus, 'Select MCU', function(mcu_val)
    vim.ui.input({ prompt = 'Enter Frequency (Hz) [default: 16000000]: ' }, function(input)
      local freq = input
      if not freq or freq == '' then
        freq = '16000000'
      end
      if not tonumber(freq) then
        util.notify('Invalid frequency.', vim.log.levels.ERROR)
        return
      end
      callback(mcu_val, freq)
    end)
  end)
end

local function setup_simavr(simulator_name)
  local fqbn = config.options.board
  local base_fqbn = fqbn:match '^([^:]+:[^:]+:[^:]+)' or fqbn

  local existing_config = read_simulation_config()

  local valid_config = false
  if existing_config then
    if existing_config.fqbn then
      local config_base = existing_config.fqbn:match '^([^:]+:[^:]+:[^:]+)' or existing_config.fqbn
      if config_base == base_fqbn then
        valid_config = true
      end
    else
      valid_config = true
    end
  end

  if valid_config and existing_config.mcu and existing_config.freq then
    -- If we have a simulator name passed in, update it in the config if it differs
    if simulator_name and existing_config.simulator ~= simulator_name then
      save_simulation_config(existing_config.mcu, existing_config.freq, existing_config.fqbn, simulator_name)
    end
    ensure_elf_and_run(existing_config.mcu, existing_config.freq)
    return
  end

  -- Guessing Logic
  local guess = FQBN_MAP[base_fqbn]

  if guess then
    save_simulation_config(guess.mcu, guess.freq, base_fqbn, simulator_name)
    ensure_elf_and_run(guess.mcu, guess.freq)
  else
    select_mcu_and_freq(function(mcu, freq)
      save_simulation_config(mcu, freq, base_fqbn, simulator_name)
      ensure_elf_and_run(mcu, freq)
    end)
  end
end

local function run_with_simulator(sim_val)
  if sim_val == 'simavr' then
    if vim.fn.executable 'simavr' == 0 then
      util.notify('Selected simulator not available.', vim.log.levels.ERROR)
      return
    end
    setup_simavr(sim_val)
  else
    util.notify('Simulator not implemented yet.', vim.log.levels.WARN)
  end
end

function M.run()
  local conf = read_simulation_config()
  local sim = conf and conf.simulator

  if not sim then
    util.select_item(SIMULATORS, 'Select Simulator', function(sim_val)
      run_with_simulator(sim_val)
    end)
  else
    run_with_simulator(sim)
  end
end

function M.select_simulator()
  util.select_item(SIMULATORS, 'Select Simulator', function(sim_val)
    save_simulation_config(nil, nil, nil, sim_val)
    util.notify('Simulator set to ' .. sim_val)
  end)
end

function M.reset_simulation()
  local path = get_config_path()
  if path and vim.fn.filereadable(path) == 1 then
    os.remove(path)
    util.notify 'Simulation configuration reset.'
  else
    util.notify 'No simulation configuration found to reset.'
  end
end

return M

