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

local FQBN_PATTERNS = {
  -- lgt8fx
  { pattern = 'lgt8fx:avr:328:clock_source=internal,clock_div=1', mcu = 'atmega328p', freq = '32000000' },
  { pattern = 'lgt8fx:avr:328:clock_source=internal,clock_div=2', mcu = 'atmega328p', freq = '16000000' },
  { pattern = 'lgt8fx:avr:328:clock_source=internal,clock_div=4', mcu = 'atmega328p', freq = '8000000' },
  { pattern = 'lgt8fx:avr:328:clock_source=internal,clock_div=8', mcu = 'atmega328p', freq = '4000000' },
  { pattern = 'lgt8fx:avr:328:clock_source=external,clock_div=16', mcu = 'atmega328p', freq = '2000000' },
  { pattern = 'lgt8fx:avr:328:clock_source=external,clock_div=32', mcu = 'atmega328p', freq = '1000000' },
  -- tiny13
  { pattern = 'MicroCore:avr:13:.*,clock=9M6', mcu = 'attiny13', freq = '9600000' },
  { pattern = 'MicroCore:avr:13:.*,clock=4M8', mcu = 'attiny13', freq = '4800000' },
  { pattern = 'MicroCore:avr:13:.*,clock=2M4', mcu = 'attiny13', freq = '2400000' },
  { pattern = 'MicroCore:avr:13:.*,clock=1M2', mcu = 'attiny13', freq = '1200000' },
  -- tinyX5
  { pattern = 'ATTinyCore:avr:attinyx5:chip=85,clock=8internal', mcu = 'attiny85', freq = '8000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=85,clock=4internal', mcu = 'attiny85', freq = '4000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=85,clock=1internal', mcu = 'attiny85', freq = '1000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=45,clock=8internal', mcu = 'attiny45', freq = '8000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=45,clock=4internal', mcu = 'attiny45', freq = '4000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=45,clock=1internal', mcu = 'attiny45', freq = '1000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=25,clock=8internal', mcu = 'attiny25', freq = '8000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=25,clock=4internal', mcu = 'attiny25', freq = '4000000' },
  { pattern = 'ATTinyCore:avr:attinyx5:chip=25,clock=1internal', mcu = 'attiny25', freq = '1000000' },
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

local function ensure_elf_and_run(mcu, freq, force_compile)
  local build_path = cli.get_build_path()
  if not build_path then
    util.notify('Build path not configured.', vim.log.levels.ERROR)
    return
  end

  local function find_elf()
    local elf_files = vim.fn.glob(build_path .. '/*.elf', true, true)
    if #elf_files > 0 then
      return elf_files[1]
    end
    return nil
  end

  local elf_file = find_elf()
  local needs_compile = force_compile

  if not needs_compile then
    if not elf_file or vim.fn.filereadable(elf_file) == 0 then
      needs_compile = true
    else
      -- Check timestamp against current sketch file
      local sketch_path = vim.fn.expand '%:p'
      local sketch_time = vim.fn.getftime(sketch_path)
      local elf_time = vim.fn.getftime(elf_file)
      if sketch_time > elf_time then
        needs_compile = true
      end
    end
  end

  local function run()
    elf_file = find_elf()
    if elf_file and vim.fn.filereadable(elf_file) == 1 then
      launch_simavr(mcu, freq, elf_file)
    else
      util.notify('Could not locate compiled .elf file.', vim.log.levels.ERROR)
    end
  end

  if needs_compile then
    util.notify('Compiling sketch...', vim.log.levels.INFO)
    local cmd = cli.get_compile_command()
    term.run_silent(cmd, 'Compilation', function()
      -- We need to save the receipt here to keep it in sync with uploads
      -- Accessing internal function from another module is tricky without export
      -- We'll just call the same logic or if possible require init (careful of circular deps)
      -- Simplest: Re-implement saving receipt logic here or export it in init.lua
      -- Let's try to do it properly by duplicating minimal logic to avoid circular dependency
      local receipt_path = cli.get_build_path() .. '/build_receipt.json'
      local fqbn = config.options.board
      -- Prefer FQBN from sketch.yaml if available, just like init.lua
      local sketch_cpu = util.get_sketch_config()
      if sketch_cpu and sketch_cpu.fqbn then
        fqbn = sketch_cpu.fqbn
      end
      
      local f = io.open(receipt_path, 'w')
      if f then
        f:write(vim.json.encode({ fqbn = fqbn }))
        f:close()
      end
      
      run()
    end)
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
  local mcu, freq
  local force_compile = false

  -- Check if existing config matches current FQBN exactly
  if existing_config and existing_config.fqbn == fqbn and existing_config.mcu and existing_config.freq then
    mcu = existing_config.mcu
    freq = existing_config.freq
    -- If simulator preference changed, update it
    if simulator_name and existing_config.simulator ~= simulator_name then
      save_simulation_config(mcu, freq, fqbn, simulator_name)
    end
  else
    -- Config mismatch or missing: re-evaluate and force compile
    force_compile = true
    local guess = FQBN_MAP[base_fqbn]

    if not guess then
      for _, item in ipairs(FQBN_PATTERNS) do
        if fqbn:match(item.pattern) then
          guess = item
          break
        end
      end
    end

    if guess then
      mcu = guess.mcu
      freq = guess.freq
      save_simulation_config(mcu, freq, fqbn, simulator_name)
    else
      select_mcu_and_freq(function(selected_mcu, selected_freq)
        save_simulation_config(selected_mcu, selected_freq, fqbn, simulator_name)
        ensure_elf_and_run(selected_mcu, selected_freq, true)
      end)
      return
    end
  end

  ensure_elf_and_run(mcu, freq, force_compile)
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

local function check_save()
  if vim.bo.modified then
    local choice = vim.fn.confirm('Buffer has unsaved changes. Save?', '&Yes\n&No\n&Cancel')
    if choice == 1 then
      vim.cmd 'write'
    elseif choice == 3 then
      return false -- Cancel
    end
  end
  return true
end

function M.run()
  if not check_save() then return end
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

