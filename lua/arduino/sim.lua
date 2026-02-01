local cli = require 'arduino.cli'
local util = require 'arduino.util'
local term = require 'arduino.term'
local config = require 'arduino.config'
local storage = require 'arduino.storage'
local build_receipt = require 'arduino.build_receipt'

local M = {}

-- Supported simulators
local SIMULATORS = {
  { label = 'SimAVR', value = 'simavr' },
}

-- SimAVR Mappings (FQBN -> MCU)
-- Frequency is usually standard for these boards but we'll verify
local FQBN_MAP = {
  ['arduino:avr:uno'] = { mcu = 'atmega328p', freq = 16000000 },
  ['arduino:avr:yun'] = { mcu = 'atmega32u4', freq = 16000000 },
  ['arduino:avr:nano'] = { mcu = 'atmega328p', freq = 16000000 },
  ['arduino:avr:mega'] = { mcu = 'atmega2560', freq = 16000000 },
  ['arduino:avr:micro'] = { mcu = 'atmega32u4', freq = 16000000 },
  ['arduino:avr:leonardo'] = { mcu = 'atmega32u4', freq = 16000000 },
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

local function read_simulation_config()
  return storage.get 'simulation'
end

local function save_simulation_config(mcu, freq, fqbn, simulator)
  local current = read_simulation_config() or {}

  local data = {
    mcu = mcu or current.mcu,
    freq = freq or current.freq,
    fqbn = fqbn or current.fqbn,
    simulator = simulator or current.simulator,
  }

  storage.update('simulation', data)
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

  ---@diagnostic disable-next-line: deprecated
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
  vim.keymap.set('t', '<Esc>', [[<C-\><C-n><cmd>close<cr>]], opts)
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', opts)
  vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)
end

-- Start simavr in background with gdb stub enabled on port 1234.
local function launch_simavr_debug(mcu, freq, elf_path, output_chan, on_ready, on_output)
  -- simavr typically listens on port 1234 when -g is passed
  local port = 1234
  local ready_triggered = false

  local cmd = string.format('simavr --gdb --mcu %s --freq %s "%s"', mcu, freq, elf_path)

  local function check_ready(data)
    if not ready_triggered and on_ready and data then
      for _, line in ipairs(data) do
        if line:match 'listening on port' then
          ready_triggered = true
          on_ready()
          break
        end
      end
    end
  end

  -- Run in background job (not terminal) so we can open a separate gdb terminal
  local job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(_, data)
      check_ready(data)
      if output_chan and data then
        local filtered = {}
        for _, line in ipairs(data) do
          if not line:match '^avr_gdb_init' and not line:match '^gdb_network_handler' then
            table.insert(filtered, line)
          end
        end
        if #filtered > 0 then
          pcall(vim.api.nvim_chan_send, output_chan, table.concat(filtered, '\r\n'))
          if on_output then
            on_output()
          end
        end
      end
    end,
    on_stderr = function(_, data)
      check_ready(data)
      if output_chan and data then
        local filtered = {}
        for _, line in ipairs(data) do
          if not line:match '^avr_gdb_init' and not line:match '^gdb_network_handler' then
            table.insert(filtered, line)
          end
        end
        if #filtered > 0 then
          pcall(vim.api.nvim_chan_send, output_chan, table.concat(filtered, '\r\n'))
          if on_output then
            on_output()
          end
        end
      end
    end,
    on_exit = function(_, code)
      -- Ignore 129 (SIGHUP) and 143 (SIGTERM) which happen when we kill the process
      if code ~= 0 and code ~= 129 and code ~= 143 then
        util.notify('Simulation exited with code ' .. code, vim.log.levels.WARN)
      end
      if output_chan then
        pcall(vim.api.nvim_chan_send, output_chan, '\r\n[Process exited with code ' .. code .. ']\r\n')
      end
    end,
  })

  return { job_id = job_id, port = port }
end

local function resolve_avr_gdb()
  -- Check for user override first
  if config.options.sim_debug_gdb then
    return config.options.sim_debug_gdb
  end

  -- Check arduino-cli managed tools
  local cli_path = cli.get_tool_path 'avr-gdb'
  if cli_path then
    return cli_path
  end

  -- Fallback to system path
  return 'avr-gdb'
end

local function open_avr_gdb(elf_path, port, layout_opts)
  local gdb = resolve_avr_gdb()
  if vim.fn.executable(gdb) == 0 then
    util.notify(gdb .. ' not found.', vim.log.levels.ERROR)
    return nil
  end

  local cmd = string.format('%s -q "%s" -ex "target remote localhost:%d"', gdb, elf_path, port)

  local buf = vim.api.nvim_create_buf(false, true)
  local width, height, row, col

  if layout_opts then
    width = layout_opts.width
    height = layout_opts.height
    row = layout_opts.row
    col = layout_opts.col
  elseif config.options.fullscreen_debug then
    width = vim.o.columns
    height = vim.o.lines
    row = 0
    col = 0
  else
    width = math.ceil(vim.o.columns * 0.8)
    height = math.ceil(vim.o.lines * 0.8)
    row = math.floor((vim.o.lines - height) / 2) - 1
    col = math.ceil((vim.o.columns - width) / 2)
  end

  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' AVR-GDB ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value('winhl', 'Normal:ArduinoWindowNormal,FloatBorder:ArduinoWindowBorder,FloatTitle:ArduinoWindowTitle', { win = win })

  ---@diagnostic disable-next-line: deprecated
  local job_id = vim.fn.termopen(cmd)

  -- Ensure process is killed when buffer/window is closed
  vim.api.nvim_create_autocmd({ 'BufUnload', 'WinClosed' }, {
    buffer = buf,
    callback = function()
      if job_id then
        pcall(vim.fn.jobstop, job_id)
      end
    end,
  })

  -- Keymaps for closing
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n><cmd>close<cr>]], opts)
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', opts)
  vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)

  vim.cmd 'startinsert'
  return { buf = buf, win = win, job_id = job_id }
end

local function ensure_elf_and_run(mcu, freq)
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
  local needs_compile = false

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
      elseif not build_receipt.matches(nil) then
        -- Ensure we have a valid receipt for the current FQBN (mode agnostic)
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
    -- Use standard compile command (release mode / no debug flags forced)
    -- This matches the agnostic behavior requested
    local cmd = cli.get_compile_command(nil)
    term.run_silent(cmd, 'Compilation', function()
      -- Save receipt (defaults to release if not specified, which matches standard compile)
      build_receipt.write(nil, 'release')

      run()
    end)
  else
    run()
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
    util.notify('No MCUs found from SimAVR.', vim.log.levels.ERROR)
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

local function configure_simavr(simulator_name, callback)
  local fqbn = config.options.board
  local base_fqbn = fqbn:match '^([^:]+:[^:]+:[^:]+)' or fqbn

  local existing_config = read_simulation_config()
  local mcu, freq

  -- Check if existing config matches current FQBN exactly
  if existing_config and existing_config.fqbn == fqbn and existing_config.mcu and existing_config.freq then
    mcu = existing_config.mcu
    freq = existing_config.freq
    -- If simulator preference changed, update it
    if simulator_name and existing_config.simulator ~= simulator_name then
      save_simulation_config(mcu, freq, fqbn, simulator_name)
    end
    callback(mcu, freq)
  else
    -- Config mismatch or missing: re-evaluate
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
      callback(mcu, freq)
    else
      select_mcu_and_freq(function(selected_mcu, selected_freq)
        save_simulation_config(selected_mcu, selected_freq, fqbn, simulator_name)
        callback(selected_mcu, selected_freq)
      end)
    end
  end
end

local function perform_debug_workflow(mcu, freq)
  -- Ensure ELF is compiled with debug flags
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
  local needs_compile = false
  if not elf_file or vim.fn.filereadable(elf_file) == 0 then
    needs_compile = true
  else
    local sketch_path = vim.fn.expand '%:p'
    local sketch_time = vim.fn.getftime(sketch_path)
    local elf_time = vim.fn.getftime(elf_file)
    if sketch_time > elf_time then
      needs_compile = true
    elseif not build_receipt.matches 'debug' then
      needs_compile = true
    end
  end

  local function start_debug_session()
    local final_elf = find_elf()
    if not final_elf then
      util.notify('ELF not found.', vim.log.levels.ERROR)
      return
    end

    local sim_chan = nil
    local sim_buf = nil
    local sim_win = nil

    if config.options.debug_serial_split then
      -- Prepare SimAVR Output Buffer
      -- cleanup existing buffer if present to avoid E95
      local existing_buf = vim.fn.bufnr '^SimAVR Output$'
      if existing_buf ~= -1 then
        vim.api.nvim_buf_delete(existing_buf, { force = true })
      end

      sim_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(sim_buf, 'SimAVR Output')
      vim.bo[sim_buf].bufhidden = 'wipe'
      sim_chan = vim.api.nvim_open_term(sim_buf, {})
    end

    local function on_output()
      if sim_win and vim.api.nvim_win_is_valid(sim_win) and sim_buf then
        local count = vim.api.nvim_buf_line_count(sim_buf)
        vim.api.nvim_win_set_cursor(sim_win, { count, 0 })
      end
    end

    -- Launch SimAVR with output piping
    local sim_ready = false
    local siminfo = launch_simavr_debug(mcu, freq, final_elf, sim_chan, function()
      sim_ready = true
    end, on_output)

    if not siminfo or not siminfo.job_id then
      util.notify('Failed to start simavr for debugging.', vim.log.levels.ERROR)
      return
    end

    -- Wait for SimAVR to be ready (listening on port)
    local ok = vim.wait(2000, function()
      return sim_ready
    end, 50)

    if not ok then
      util.notify('Timed out waiting for SimAVR to be ready. Proceeding anyway...', vim.log.levels.WARN)
    end

    -- Calculate Split Layout
    local total_width, total_height, row, start_col
    if config.options.fullscreen_debug then
      total_width = vim.o.columns
      total_height = vim.o.lines
      row = 0
      start_col = 0
    else
      -- Centered 80% Height, 80% Width
      total_width = math.ceil(vim.o.columns * 0.8)
      total_height = math.ceil(vim.o.lines * 0.8)
      row = math.floor((vim.o.lines - total_height) / 2) - 1
      start_col = math.ceil((vim.o.columns - total_width) / 2)
    end

    local gdb_width = total_width
    local gdb_height = total_height
    local sim_width = 0
    local sim_height = 0
    local sim_row = row
    local sim_col = start_col

    if config.options.debug_serial_split then
      local ratio = config.options.debug_split_ratio or 0.66

      if config.options.debug_horizontal_split then
        -- Horizontal Split (Top/Bottom)
        -- GDB takes top portion, Sim takes bottom
        gdb_height = math.floor(total_height * ratio)
        sim_height = total_height - gdb_height - 2 -- Account for border spacing
        sim_width = total_width
        sim_row = row + gdb_height + 2
        sim_col = start_col
      else
        -- Vertical Split (Left/Right)
        -- GDB takes left portion, Sim takes right
        gdb_width = math.floor(total_width * ratio)
        sim_width = total_width - gdb_width - 2 -- Account for border spacing
        sim_height = total_height
        sim_row = row
        sim_col = start_col + gdb_width + 2
      end
    end

    local gdb_opts = {
      width = gdb_width,
      height = gdb_height,
      row = row,
      col = start_col,
    }

    if config.options.debug_serial_split and sim_buf then
      local sim_win_opts = {
        relative = 'editor',
        width = sim_width,
        height = sim_height,
        row = sim_row,
        col = sim_col,
        style = 'minimal',
        border = 'rounded',
        title = ' SimAVR Output ',
        title_pos = 'center',
      }

      -- Open Sim Window
      sim_win = vim.api.nvim_open_win(sim_buf, false, sim_win_opts)
      vim.api.nvim_set_option_value('winhl', 'Normal:ArduinoWindowNormal,FloatBorder:ArduinoWindowBorder,FloatTitle:ArduinoWindowTitle', { win = sim_win })
      vim.api.nvim_set_option_value('wrap', true, { win = sim_win })
    end

    -- Open GDB Session
    local session = open_avr_gdb(final_elf, siminfo.port, gdb_opts)

    if not session then
      -- GDB failed, cleanup sim
      if sim_win and vim.api.nvim_win_is_valid(sim_win) then
        vim.api.nvim_win_close(sim_win, true)
      end
      if config.options.sim_debug_kill_sim_on_gdb_exit and siminfo and siminfo.job_id then
        pcall(vim.fn.jobstop, siminfo.job_id)
      end
      return
    end

    -- Setup Cleanup Hooks
    if config.options.sim_debug_kill_sim_on_gdb_exit then
      vim.api.nvim_create_autocmd({ 'BufUnload', 'WinClosed' }, {
        buffer = session.buf,
        once = true,
        callback = function()
          -- Close Sim Window if still open
          if sim_win and vim.api.nvim_win_is_valid(sim_win) then
            vim.api.nvim_win_close(sim_win, true)
          end
          -- Kill SimAVR Job
          if siminfo and siminfo.job_id then
            pcall(vim.fn.jobstop, siminfo.job_id)
          end
        end,
      })
    end
  end

  if needs_compile then
    util.notify('Compiling for debug...', vim.log.levels.INFO)
    local debug_args = config.options.simulation_build_args
    local cmd = cli.get_compile_command(debug_args)
    term.run_silent(cmd, 'Compilation', function()
      local br = require 'arduino.build_receipt'
      br.write(nil, 'debug')
      start_debug_session()
    end)
  else
    start_debug_session()
  end
end

local function run_debug_with_simulator(sim_val)
  if sim_val == 'simavr' then
    if vim.fn.executable 'simavr' == 0 then
      util.notify('Selected simulator not available.', vim.log.levels.ERROR)
      return
    end
    configure_simavr(sim_val, function(mcu, freq)
      perform_debug_workflow(mcu, freq)
    end)
  else
    util.notify('Simulator not implemented yet.', vim.log.levels.WARN)
  end
end

function M.simulate_and_debug()
  if not check_save() then
    return
  end

  local conf = read_simulation_config()
  local sim = conf and conf.simulator
  if not sim then
    util.select_item(SIMULATORS, 'Select Simulator', function(sim_val)
      run_debug_with_simulator(sim_val)
    end)
  else
    run_debug_with_simulator(sim)
  end
end

local function setup_simavr(simulator_name)
  configure_simavr(simulator_name, function(mcu, freq)
    ensure_elf_and_run(mcu, freq)
  end)
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
  if not check_save() then
    return
  end
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
  local current = storage.get 'simulation' or {}
  -- Keep the simulator choice, wipe specific board params
  local new_data = { simulator = current.simulator }
  storage.update('simulation', new_data)
  util.notify 'Simulation config (MCU/Freq) reset.'
end

return M
