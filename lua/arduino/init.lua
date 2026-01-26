local boards = require 'arduino.boards'
local config = require 'arduino.config'
local term = require 'arduino.term'
local core = require 'arduino.core'
local util = require 'arduino.util'
local cli = require 'arduino.cli'
local lib = require 'arduino.lib'

local M = {}

local function define_highlights()
  local style = config.options.floating_window and config.options.floating_window.style or 'telescope'

  if style == 'lualine' then
    local lua_hl = vim.api.nvim_get_hl(0, { name = 'lualine_c_normal', link = false })
    if vim.tbl_isempty(lua_hl) then
      lua_hl = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
    end
    local bg = lua_hl.bg

    -- Helper to clone a highlight group but override background
    local function clone_hl(target, source_name, new_bg)
      local source = vim.api.nvim_get_hl(0, { name = source_name, link = false })
      if vim.tbl_isempty(source) then
        -- Fallback to standard float groups if telescope ones aren't defined
        local fallback_name = source_name:gsub('TelescopePrompt', 'Float'):gsub('Telescope', 'Float')
        source = vim.api.nvim_get_hl(0, { name = fallback_name, link = false })
      end

      local def = vim.deepcopy(source)
      def.bg = new_bg
      -- Clear any link just in case, though link=false should handle it
      def.link = nil
      vim.api.nvim_set_hl(0, target, def)
    end

    clone_hl('ArduinoWindowNormal', 'TelescopePromptNormal', bg)
    clone_hl('ArduinoWindowBorder', 'TelescopePromptBorder', bg)
    clone_hl('ArduinoWindowTitle', 'TelescopePromptTitle', bg)
  else
    -- Telescope (Default)
    vim.api.nvim_set_hl(0, 'ArduinoWindowNormal', { link = 'TelescopePromptNormal' })
    vim.api.nvim_set_hl(0, 'ArduinoWindowBorder', { link = 'TelescopePromptBorder' })
    vim.api.nvim_set_hl(0, 'ArduinoWindowTitle', { link = 'TelescopePromptTitle' })
  end

  vim.api.nvim_set_hl(0, 'ArduinoLibraryInstalled', { fg = '#00ff00', bold = true })
  vim.api.nvim_set_hl(0, 'ArduinoLibraryOutdated', { fg = '#ffaa00', bold = true })
end

function M.setup(opts)
  config.setup(opts)

  define_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = define_highlights,
  })

  local function check_deps()
    if vim.fn.executable 'arduino-cli' ~= 1 then
      vim.notify_once('Application arduino-cli not found.', vim.log.levels.WARN, { title = 'Arduino' })
    end
  end

  -- Simple deferred check to allow UI plugins to initialize
  if vim.v.vim_did_enter == 1 then
    vim.defer_fn(check_deps, 200)
  else
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        vim.defer_fn(check_deps, 200)
      end,
      once = true,
    })
  end

  -- Auto-detect board from sketch config
  local cpu = util.get_sketch_config()
  if cpu and cpu.fqbn then
    config.options.board = cpu.fqbn
  end
  if cpu and cpu.programmer then
    config.options.programmer = cpu.programmer
  end

  -- Automatic Lualine integration
  local has_lualine, lualine = pcall(require, 'lualine')
  if has_lualine then
    local lualine_config = lualine.get_config()
    local extensions = lualine_config.extensions or {}

    -- Check if arduino extension already exists
    local has_arduino_ext = false
    for _, ext in ipairs(extensions) do
      if type(ext) == 'table' and ext.filetypes and vim.tbl_contains(ext.filetypes, 'arduino') then
        has_arduino_ext = true
        break
      end
    end

    if not has_arduino_ext then
      -- Create an extension that inherits from global sections but adds ours
      local sections = vim.deepcopy(lualine_config.sections or {})

      -- Inject into lualine_x (or lualine_c if preferred, but x is usually auxiliary)
      -- If lualine_x doesn't exist, create it
      sections.lualine_x = sections.lualine_x or {}

      -- Prepend our component
      table.insert(sections.lualine_x, 1, require('arduino.status').string)

      local arduino_extension = {
        sections = sections,
        filetypes = { 'arduino' },
      }

      table.insert(extensions, arduino_extension)
      lualine_config.extensions = extensions
      lualine.setup(lualine_config)
    end
  end
end

-- UI Helper
local function select_item(items, prompt, callback)
  -- items: list of {label=..., value=...}
  local telescope_avail = false
  if config.options.use_telescope then
    local ok, _ = pcall(require, 'telescope')
    telescope_avail = ok
  end

  if telescope_avail then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt,
        finder = finders.new_table {
          results = items,
          entry_maker = function(entry)
            return {
              value = entry.value,
              display = entry.label,
              ordinal = entry.label,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              callback(selection.value)
            end
          end)
          return true
        end,
      })
      :find()
    return
  end

  -- Fallback to vim.ui.select
  local on_choice = function(item)
    if item then
      callback(item.value)
    end
  end

  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    on_choice(choice)
  end)
end

-- TO BE REMOVED
-- function M.attach(port)
--   local function perform_attach(p)
--     local cmd = { 'arduino-cli', 'board', 'attach', '-p', p }
--     -- This command needs to run in the background, not terminal
--     vim.fn.jobstart(cmd, {
--       on_exit = function(id, code, _)
--         if code == 0 then
--           vim.g.arduino_serial_port = p
--           -- Update sketch config
--           util.get_sketch_config(vim.fn.expand '%:p:h') -- Refresh cache/lookup
--
--           -- Try to detect the board from the port we just attached to
--           local handle = io.popen 'arduino-cli board list --format json'
--           if handle then
--             local result = handle:read '*a'
--             handle:close()
--             local ok, data = pcall(vim.json.decode, result)
--             if ok and data then
--               for _, item in ipairs(data) do
--                 if item.port and item.port.address == p and item.matching_boards and #item.matching_boards > 0 then
--                   config.options.board = item.matching_boards[1].fqbn
--                   break
--                 end
--               end
--             end
--           end
--
--           util.notify('Sketch attached to ' .. (config.options.board or 'unknown'))
--         else
--           util.notify('Failed to attach sketch.', vim.log.levels.ERROR)
--         end
--       end,
--     })
--   end
--
--   if port then
--     perform_attach(port)
--   else
--     local ports = cli.get_ports(true)
--     if #ports == 0 then
--       util.notify('No serial ports found.', vim.log.levels.WARN)
--     elseif #ports == 1 then
--       perform_attach(ports[1])
--     else
--       local items = {}
--       for _, p in ipairs(ports) do
--         table.insert(items, { label = p, value = p })
--       end
--       select_item(items, 'Select Port to Attach', perform_attach)
--     end
--   end
-- end

local function configure_options(base_fqbn, options, idx, acc, callback)
  if idx > #options then
    -- Done. Construct FQBN.
    local final_fqbn = base_fqbn
    if #acc > 0 then
      final_fqbn = final_fqbn .. ':' .. table.concat(acc, ',')
    end
    callback(final_fqbn)
    return
  end

  local opt = options[idx]
  local items = {}
  for _, v in ipairs(opt.values) do
    table.insert(items, {
      label = v.value_label or v.value,
      value = v.value,
    })
  end

  select_item(items, 'Select ' .. (opt.option_label or opt.option), function(choice)
    table.insert(acc, opt.option .. '=' .. choice)
    configure_options(base_fqbn, options, idx + 1, acc, callback)
  end)
end

function M.choose_board()
  local b_list = boards.get_boards()
  select_item(b_list, 'Select Board', function(value)
    local details = cli.get_board_details(value)
    if details and details.config_options and #details.config_options > 0 then
      configure_options(value, details.config_options, 1, {}, function(final_fqbn)
        config.options.board = final_fqbn
        util.notify('Selected board: ' .. final_fqbn)
        util.update_sketch_config('fqbn', final_fqbn)
      end)
    else
      config.options.board = value
      util.notify('Selected board: ' .. value)
      util.update_sketch_config('fqbn', value)
    end
  end)
end

function M.choose_programmer()
  local p_list = boards.get_programmers()
  select_item(p_list, 'Select Programmer', function(value)
    config.options.programmer = value
    local display_val = (value == nil or value == '') and 'None' or value
    util.notify('Selected programmer: ' .. display_val)
    util.update_sketch_config('programmer', value)
  end)
end

function M.choose_port()
  local ports = cli.get_ports(true)
  local items = {
    { label = 'Auto (detect from system)', value = '__AUTO_PORT__' }
  }

  if #ports == 0 then
    -- Show only 'auto'; warn user before picker
    require('arduino.util').notify('No serial ports available at the moment.', vim.log.levels.WARN)
  else
    for _, p in ipairs(ports) do
      table.insert(items, { label = p, value = p })
    end
  end

  select_item(items, 'Select Port', function(value)
    if value == '__AUTO_PORT__' then
      -- Remove locked port from config
      vim.g.arduino_serial_port = nil
      util.update_sketch_config('port', nil) -- Remove port entry
      util.notify 'Port reset to AUTO mode.'
    else
      vim.g.arduino_serial_port = value -- Set global as overrides
      util.update_sketch_config('port', value)
      util.notify('Selected port: ' .. value)
    end
  end)
end

function M.verify()
  local cmd = cli.get_compile_command()
  term.run_silent(cmd, 'Compilation')
end

function M.upload()
  local cmd = cli.get_upload_command()
  term.run_silent(cmd, 'Flashing')
end

function M.serial()
  local port = cli.get_port()
  if not port then
    util.notify('No serial port found.', vim.log.levels.WARN)
    return
  end

  local cmd = cli.get_serial_command()
  if not cmd then
    return
  end

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
    title = ' Serial Monitor ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  -- Apply custom highlights (defaults to TelescopePrompt*)
  vim.api.nvim_set_option_value('winhl', 'Normal:ArduinoWindowNormal,FloatBorder:ArduinoWindowBorder,FloatTitle:ArduinoWindowTitle', { win = win })

  -- Track if we are intentionally killing the monitor to suppress exit code warnings
  local killing_monitor = false

  -- Start terminal job (interactive) without callbacks
  local job_id = vim.fn.termopen(cmd)

  -- Handle exit status via event
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      local code = vim.v.event.status
      if code ~= 0 and not killing_monitor then
        util.notify('Serial monitor exited with code ' .. code, vim.log.levels.WARN)
      end
    end,
  })

  vim.cmd 'startinsert'

  -- Ensure process is killed when buffer/window is closed
  vim.api.nvim_create_autocmd({ 'BufUnload', 'WinClosed' }, {
    buffer = buf,
    callback = function()
      if job_id then
        killing_monitor = true
        -- If using screen, send kill sequences to prevent detaching
        if cmd:match '^screen' then
          -- Send Standard Quit: Ctrl-A, \, y
          pcall(vim.api.nvim_chan_send, job_id, '\001\\y')
          -- Send Standard Kill: Ctrl-A, k, y
          pcall(vim.api.nvim_chan_send, job_id, '\001ky')
        end
        pcall(vim.fn.jobstop, job_id)
      end
    end,
  })

  -- Keymaps for closing
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('t', '<Esc>', '<C-\\><C-n><cmd>close<cr>', opts)
  vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)
end

function M.upload_and_serial()
  local upload_cmd = cli.get_upload_command()
  term.run_silent(upload_cmd, 'Flashing', function()
    M.serial()
  end)
end

function M.check_logs()
  local log_data = require('arduino.log').get()
  if #log_data == 0 then
    util.notify 'No logs available.'
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Arduino Logs')

  local width = math.ceil(vim.o.columns * 0.8)
  local height = math.ceil(vim.o.lines * 0.8)
  -- Adjusting row calculation to be more centered (accounting for status/tab lines)
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
    title = ' Arduino Logs ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  -- Apply custom highlights (defaults to TelescopePrompt*)
  vim.api.nvim_set_option_value('winhl', 'Normal:ArduinoWindowNormal,FloatBorder:ArduinoWindowBorder,FloatTitle:ArduinoWindowTitle', { win = win })

  -- Enable ANSI colors using terminal channel
  local chan = vim.api.nvim_open_term(buf, {})
  vim.api.nvim_chan_send(chan, table.concat(log_data, '\r\n'))

  -- Buffer options
  vim.bo[buf].filetype = 'arduino_log'
  vim.bo[buf].bufhidden = 'wipe'

  -- Keymap to close the window
  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<esc>', '<cmd>close<cr>', { buffer = buf, silent = true })
end

function M.get_info()
  local info = {}
  table.insert(info, 'Board: ' .. (config.options.board or 'None'))
  table.insert(info, 'Port: ' .. (cli.get_port() or 'None'))
  table.insert(info, 'Baud: ' .. config.options.serial_baud)
  table.insert(info, 'Programmer: ' .. (config.options.programmer or 'None'))
  table.insert(info, 'Compilation: ' .. cli.get_compile_command())
  print(table.concat(info, '\n'))
end

function M.set_baud(baud, is_auto)
  if baud == nil or baud == '' then
    local items = {
      { label = 'Auto (detect from code)', value = 'auto' },
    }
    local rates = {}
    for r, _ in pairs(config.VALID_BAUD_RATES) do
      table.insert(rates, r)
    end
    table.sort(rates)
    for _, r in ipairs(rates) do
      table.insert(items, { label = tostring(r), value = r })
    end
    select_item(items, 'Select Baud Rate', M.set_baud)
    return
  end

  if baud == 'auto' then
    config.options.manual_baud = false
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local detected = util.detect_baud_rate(lines)
    M.set_baud(detected, true)
    util.notify 'Baud rate reset to AUTO mode.'
    return
  end

  local b = tonumber(baud)
  if not b or not config.VALID_BAUD_RATES[b] then
    util.notify('Invalid baud rate: ' .. (baud or 'nil'), vim.log.levels.ERROR)
    return
  end

  if not is_auto then
    config.options.manual_baud = true
  end

  if config.options.serial_baud == b then
    return
  end
  config.options.serial_baud = b
  local prefix = is_auto and 'Baud rate set to ' or 'Baud rate manually set to '
  util.notify(prefix .. b)
end

function M.library_manager()
  if not config.options.use_telescope then
    util.notify('Library Manager requires Telescope support enabled.', vim.log.levels.WARN)
    return
  end

  local ok, _ = pcall(require, 'telescope')
  if not ok then
    return
  end

  util.notify('Loading library data...', vim.log.levels.INFO)

  local function fetch_data(callback)
    lib.search(function(search_data)
      if not search_data or not search_data.libraries then
        util.notify('Failed to load libraries.', vim.log.levels.ERROR)
        callback(nil)
        return
      end

      lib.list_installed(function(installed_data)
        local installed_map = {}
        if installed_data and installed_data.installed_libraries then
          for _, l in ipairs(installed_data.installed_libraries) do
            if l.library and l.library.name then
              installed_map[l.library.name] = l.library.version
            end
          end
        end

        lib.list_outdated(function(outdated_data)
          local outdated_map = {}
          if outdated_data and outdated_data.libraries then
            for _, l in ipairs(outdated_data.libraries) do
              if l.library and l.library.name then
                outdated_map[l.library.name] = l.release and l.release.version or 'unknown'
              end
            end
          end

          local results = {}
          for _, item in ipairs(search_data.libraries) do
            local name = item.name
            local status_icon = ''
            local version_info = ''
            local ordinal_prefix = 'z'

            if installed_map[name] then
              status_icon = '✓'
              version_info = ' [' .. installed_map[name] .. ']'
              ordinal_prefix = 'm' -- Installed
            end

            if outdated_map[name] then
              status_icon = '↑'
              version_info = ' [Update: ' .. outdated_map[name] .. ']'
              ordinal_prefix = 'a' -- Outdated (top priority)
            end

            if name then
              table.insert(results, {
                name = name,
                status_icon = status_icon,
                version_info = version_info,
                installed = installed_map[name] ~= nil,
                outdated = outdated_map[name] ~= nil,
                ordinal = ordinal_prefix .. ' ' .. name,
                details = item, -- Store full library details for preview
              })
            end
          end
          callback(results)
        end)
      end)
    end)
  end

  fetch_data(function(initial_results)
    if not initial_results then
      return
    end

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local previewers = require 'telescope.previewers'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local entry_display = require 'telescope.pickers.entry_display'

    local displayer = entry_display.create {
      separator = ' ',
      items = {
        { width = 1 }, -- Icon
        { remaining = true }, -- Name + Version
      },
    }

    local function make_display(entry)
      local icon_hl = entry.outdated and 'ArduinoLibraryOutdated' or (entry.installed and 'ArduinoLibraryInstalled' or 'Normal')
      return displayer {
        { entry.status_icon, icon_hl },
        entry.name .. entry.version_info,
      }
    end

    local function create_finder(results)
      return finders.new_table {
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.ordinal,
            name = entry.name,
            status_icon = entry.status_icon,
            version_info = entry.version_info,
            installed = entry.installed,
            outdated = entry.outdated,
            details = entry.details,
          }
        end,
      }
    end
    local lib_previewer = previewers.new_buffer_previewer {
      title = 'Library Details',
      define_preview = function(self, entry, _)
        local lib = entry.value.details
        local latest = lib.latest or {}

        local lines = {}
        table.insert(lines, '# ' .. (lib.name or 'Unknown'))
        table.insert(lines, '')
        table.insert(lines, '**Author:** ' .. (latest.author or 'Unknown'))
        table.insert(lines, '**Maintainer:** ' .. (latest.maintainer or 'Unknown'))
        table.insert(lines, '**Website:** ' .. (latest.website or '-'))
        table.insert(lines, '**Category:** ' .. (latest.category or '-'))
        table.insert(lines, '**Architecture:** ' .. (latest.types and table.concat(latest.types, ', ') or '-'))
        table.insert(lines, '')
        table.insert(lines, '## Description')
        table.insert(lines, latest.sentence or '')
        if latest.paragraph and latest.paragraph ~= '' then
          table.insert(lines, '')
          table.insert(lines, latest.paragraph)
        end

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
        if self.state.winid then
          vim.wo[self.state.winid].conceallevel = 2
          vim.wo[self.state.winid].linebreak = true
          vim.wo[self.state.winid].wrap = true
        end
      end,
    }

    pickers
      .new({}, {
        prompt_title = 'Arduino Libraries',
        finder = create_finder(initial_results),
        previewer = lib_previewer,
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          local function perform_action(action_type, close_permanently)
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end
            local entry = selection.value

            if close_permanently then
              actions.close(prompt_bufnr)
            end

            local cb = nil
            if not close_permanently then
              cb = function()
                fetch_data(function(new_results)
                  if new_results then
                    local current_picker = action_state.get_current_picker(prompt_bufnr)
                    current_picker:refresh(create_finder(new_results), { reset_prompt = false })
                  end
                end)
              end
            end

            if action_type == 'context' then
              if entry.outdated then
                lib.upgrade(entry.name, cb)
              elseif entry.installed then
                lib.uninstall(entry.name, cb)
              else
                lib.install(entry.name, cb)
              end
            elseif action_type == 'install_update' then
              if entry.outdated then
                lib.upgrade(entry.name, cb)
              elseif not entry.installed then
                lib.install(entry.name, cb)
              else
                util.notify('Library ' .. entry.name .. ' is already installed/updated.', vim.log.levels.INFO)
                -- Even if no action taken, refresh/callback might be expected or just do nothing?
                -- If we don't call cb(), the spinner/state won't update if we showed one.
                -- But here we essentially just return.
              end
            elseif action_type == 'update' then
              if entry.outdated then
                lib.upgrade(entry.name, cb)
              else
                util.notify('Library ' .. entry.name .. ' is not outdated.', vim.log.levels.WARN)
              end
            elseif action_type == 'uninstall' then
              if entry.installed then
                lib.uninstall(entry.name, cb)
              else
                util.notify('Library ' .. entry.name .. ' is not installed.', vim.log.levels.WARN)
              end
            end
          end

          actions.select_default:replace(function()
            perform_action('context', true)
          end)

          map('i', '<C-i>', function()
            perform_action('install_update', false)
          end)
          map('i', '<C-u>', function()
            perform_action('update', false)
          end)
          map('i', '<C-r>', function()
            perform_action('update', false)
          end)
          map('i', '<C-x>', function()
            perform_action('uninstall', false)
          end)
          map('i', '<C-d>', function()
            perform_action('uninstall', false)
          end)

          return true
        end,
      })
      :find()
  end)
end

local function fetch_core_data(callback)
  core.search(function(search_data)
    if not search_data then
      util.notify('Failed to load cores.', vim.log.levels.ERROR)
      callback(nil)
      return
    end

    -- Normalize search_data (usually a list of objects)
    local search_list = search_data
    if search_data.platforms then
      search_list = search_data.platforms
    end

    core.list_installed(function(installed_data)
      local installed_map = {}
      if installed_data then
        local list = installed_data
        if installed_data.platforms then
          list = installed_data.platforms
        end
        for _, c in ipairs(list) do
          if c.id then
            installed_map[c.id] = c.installed_version or 'installed'
          end
        end
      end

      core.list_outdated(function(outdated_data)
        local outdated_map = {}
        if outdated_data and outdated_data.platforms then
          for _, p in ipairs(outdated_data.platforms) do
            if p.id then
              outdated_map[p.id] = p.latest or 'unknown'
            end
          end
        end

        local results = {}
        for _, item in ipairs(search_list) do
          local id = item.id
          local latest_ver = item.latest_version or ''
          local name = id
          if item.releases and latest_ver ~= '' and item.releases[latest_ver] then
            name = item.releases[latest_ver].name or id
          end

          local status_icon = ''
          local version_info = ''
          if installed_map[id] then
            status_icon = '✓'
            version_info = ' [' .. installed_map[id] .. ']'
          end
          if outdated_map[id] then
            status_icon = '↑'
            version_info = ' [Update: ' .. outdated_map[id] .. ']'
          end

          if id then
            table.insert(results, {
              id = id,
              name = name,
              status_icon = status_icon,
              version_info = version_info,
              installed = installed_map[id] ~= nil,
              outdated = outdated_map[id] ~= nil,
              details = item,
            })
          end
        end
        callback(results)
      end)
    end)
  end)
end

function M.core_manager_fallback()
  util.notify('Loading core data...', vim.log.levels.INFO)
  fetch_core_data(function(cores)
    if not cores then
      return
    end

    local filtered = {}
    for _, c in ipairs(cores) do
      local label = c.id .. c.version_info
      local use_emoji = config.options.manager_emoji ~= false
      if use_emoji then
        if c.outdated then
          label = label .. ' 🟠'
        elseif c.installed then
          label = label .. ' 🟢'
        end
      else
        if c.outdated then
          label = label .. ' ↑'
        elseif c.installed then
          label = label .. ' ✓'
        end
      end
      table.insert(filtered, { label = label, value = c })
    end

    vim.ui.select(filtered, {
      prompt = 'Select Arduino Core:',
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice or not choice.value then
        util.notify('Core selection cancelled.', vim.log.levels.INFO)
        return
      end
      local selected = choice.value
      local action
      if selected.outdated then
        action = 'update'
      elseif selected.installed then
        action = 'uninstall'
      else
        action = 'install'
      end

      if action == 'install' then
        core.install(selected.id)
      elseif action == 'update' then
        core.upgrade(selected.id)
      elseif action == 'uninstall' then
        core.uninstall(selected.id)
      end
    end)
  end)
end

function M.core_manager()
  if not config.options.use_telescope then
    return M.core_manager_fallback()
  end

  local ok, _ = pcall(require, 'telescope')
  if not ok then
    return M.core_manager_fallback()
  end

  util.notify('Loading core data...', vim.log.levels.INFO)

  local function fetch_data(callback)
    core.search(function(search_data)
      if not search_data then
        util.notify('Failed to load cores.', vim.log.levels.ERROR)
        callback(nil)
        return
      end

      -- Normalize search_data (usually a list of objects)
      local search_list = search_data
      if search_data.platforms then
        search_list = search_data.platforms
      end

      core.list_installed(function(installed_data)
        local installed_map = {}
        if installed_data then
          local list = installed_data
          if installed_data.platforms then
            list = installed_data.platforms
          end
          for _, c in ipairs(list) do
            if c.id then
              installed_map[c.id] = c.installed_version or 'installed'
            end
          end
        end

        core.list_outdated(function(outdated_data)
          local outdated_map = {}
          if outdated_data and outdated_data.platforms then
            for _, p in ipairs(outdated_data.platforms) do
              if p.id then
                outdated_map[p.id] = p.latest or 'unknown'
              end
            end
          end

          local results = {}
          for _, item in ipairs(search_list) do
            local id = item.id
            local latest_ver = item.latest_version or ''
            local name = id
            if item.releases and latest_ver ~= '' and item.releases[latest_ver] then
              name = item.releases[latest_ver].name or id
            end

            local status_icon = ''
            local version_info = ''
            local ordinal_prefix = 'z'

            if installed_map[id] then
              status_icon = '✓'
              version_info = ' [' .. installed_map[id] .. ']'
              ordinal_prefix = 'm'
            end

            if outdated_map[id] then
              status_icon = '↑'
              version_info = ' [Update: ' .. outdated_map[id] .. ']'
              ordinal_prefix = 'a'
            end

            if id then
              table.insert(results, {
                name = id, -- Use ID as key
                display_name = name,
                latest = latest_ver,
                status_icon = status_icon,
                version_info = version_info,
                installed = installed_map[id] ~= nil,
                outdated = outdated_map[id] ~= nil,
                ordinal = ordinal_prefix .. ' ' .. name,
                details = item,
              })
            end
          end
          callback(results)
        end)
      end)
    end)
  end

  fetch_data(function(initial_results)
    if not initial_results then
      return
    end

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local previewers = require 'telescope.previewers'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local entry_display = require 'telescope.pickers.entry_display'

    local displayer = entry_display.create {
      separator = ' ',
      items = {
        { width = 1 }, -- Icon
        { remaining = true }, -- Name + Version
      },
    }

    local function make_display(entry)
      local icon_hl = entry.outdated and 'ArduinoLibraryOutdated' or (entry.installed and 'ArduinoLibraryInstalled' or 'Normal')
      return displayer {
        { entry.status_icon, icon_hl },
        entry.name .. entry.version_info,
      }
    end
    local function create_finder(results)
      return finders.new_table {
        results = results,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.ordinal,
            name = entry.name,
            display_name = entry.display_name,
            latest = entry.latest,
            status_icon = entry.status_icon,
            version_info = entry.version_info,
            installed = entry.installed,
            outdated = entry.outdated,
            details = entry.details,
          }
        end,
      }
    end

    local core_previewer = previewers.new_buffer_previewer {
      title = 'Core Details',
      define_preview = function(self, entry, _)
        local e = entry.value
        local c = e.details
        local lines = {}
        table.insert(lines, '# ' .. (e.name or 'Unknown'))
        table.insert(lines, '')
        table.insert(lines, '**Name:** ' .. (e.display_name or 'Unknown'))
        table.insert(lines, '**Maintainer:** ' .. (c.maintainer or 'Unknown'))
        table.insert(lines, '**Website:** ' .. (c.website or '-'))
        table.insert(lines, '**Latest version:** ' .. (e.latest or '-'))
        table.insert(lines, '**Email:** ' .. (c.email or '-'))

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
        if self.state.winid then
          vim.wo[self.state.winid].conceallevel = 2
          vim.wo[self.state.winid].wrap = true
          vim.wo[self.state.winid].linebreak = true
        end
      end,
    }
    pickers
      .new({}, {
        prompt_title = 'Arduino Cores',
        finder = create_finder(initial_results),
        previewer = core_previewer,
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          local function perform_action(action_type, close_permanently)
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end
            local entry = selection.value

            if close_permanently then
              actions.close(prompt_bufnr)
            end

            local cb = nil
            if not close_permanently then
              cb = function()
                fetch_data(function(new_results)
                  if new_results then
                    local current_picker = action_state.get_current_picker(prompt_bufnr)
                    current_picker:refresh(create_finder(new_results), { reset_prompt = false })
                  end
                end)
              end
            end

            if action_type == 'context' then
              if entry.outdated then
                core.upgrade(entry.name, cb)
              elseif entry.installed then
                core.uninstall(entry.name, cb)
              else
                core.install(entry.name, cb)
              end
            elseif action_type == 'install_update' then
              if entry.outdated then
                core.upgrade(entry.name, cb)
              elseif not entry.installed then
                core.install(entry.name, cb)
              else
                util.notify('Core ' .. entry.name .. ' is already installed/updated.', vim.log.levels.INFO)
                if cb then
                  cb()
                end
              end
            elseif action_type == 'update' then
              if entry.outdated then
                core.upgrade(entry.name, cb)
              else
                util.notify('Core ' .. entry.name .. ' is not outdated.', vim.log.levels.WARN)
                if cb then
                  cb()
                end
              end
            elseif action_type == 'uninstall' then
              if entry.installed then
                core.uninstall(entry.name, cb)
              else
                util.notify('Core ' .. entry.name .. ' is not installed.', vim.log.levels.WARN)
                if cb then
                  cb()
                end
              end
            end
          end

          actions.select_default:replace(function()
            perform_action('context', true)
          end)

          map('i', '<C-i>', function()
            perform_action('install_update', false)
          end)
          map('i', '<C-u>', function()
            perform_action('update', false)
          end)
          map('i', '<C-r>', function()
            perform_action('update', false)
          end)
          map('i', '<C-x>', function()
            perform_action('uninstall', false)
          end)
          map('i', '<C-d>', function()
            perform_action('uninstall', false)
          end)

          return true
        end,
      })
      :find()
  end)
end

-- Shared fetch function for both Telescope and fallback manager
local function fetch_library_data(callback)
  lib.search(function(search_data)
    if not search_data or not search_data.libraries then
      util.notify('Failed to load libraries.', vim.log.levels.ERROR)
      callback(nil)
      return
    end
    lib.list_installed(function(installed_data)
      local installed_map = {}
      if installed_data and installed_data.installed_libraries then
        for _, l in ipairs(installed_data.installed_libraries) do
          if l.library and l.library.name then
            installed_map[l.library.name] = l.library.version
          end
        end
      end
      lib.list_outdated(function(outdated_data)
        local outdated_map = {}
        if outdated_data and outdated_data.libraries then
          for _, l in ipairs(outdated_data.libraries) do
            if l.library and l.library.name then
              outdated_map[l.library.name] = l.release and l.release.version or 'unknown'
            end
          end
        end
        local results = {}
        for _, item in ipairs(search_data.libraries) do
          local name = item.name
          local status_icon = ''
          local version_info = ''
          if installed_map[name] then
            status_icon = '✓'
            version_info = ' [' .. installed_map[name] .. ']'
          end
          if outdated_map[name] then
            status_icon = '↑'
            version_info = ' [Update: ' .. outdated_map[name] .. ']'
          end
          if name then
            table.insert(results, {
              name = name,
              status_icon = status_icon,
              version_info = version_info,
              installed = installed_map[name] ~= nil,
              outdated = outdated_map[name] ~= nil,
              details = item,
            })
          end
        end
        callback(results)
      end)
    end)
  end)
end

function M.library_manager_fallback()
  util.notify('Loading library data...', vim.log.levels.INFO)
  fetch_library_data(function(libraries)
    if not libraries then
      return
    end

    -- Prepare the full, unfiltered results list
    local filtered = {}
    for _, lib in ipairs(libraries) do
      local label = lib.name .. lib.version_info
      local use_emoji = config.options.manager_emoji ~= false
      if use_emoji then
        if lib.outdated then
          label = label .. ' 🟠'
        elseif lib.installed then
          label = label .. ' 🟢'
        end
      else
        if lib.outdated then
          label = label .. ' ↑'
        elseif lib.installed then
          label = label .. ' ✓'
        end
      end
      table.insert(filtered, { label = label, value = lib })
    end

    local function open_results_window(filtered_items)
      vim.ui.select(filtered_items, {
        prompt = 'Select Arduino Library:',
        format_item = function(item)
          return item.label
        end,
      }, function(choice)
        -- On CANCEL, do nothing, just close
        if not choice or not choice.value then
          util.notify('Library selection cancelled.', vim.log.levels.INFO)
          return
        end
        local selected = choice.value
        local action
        if selected.outdated then
          action = 'update'
        elseif selected.installed then
          action = 'uninstall'
        else
          action = 'install'
        end

        if action == 'install' then
          lib.install(selected.name)
        elseif action == 'update' then
          lib.upgrade(selected.name)
        elseif action == 'uninstall' then
          lib.uninstall(selected.name)
        end
        -- Picker window closes regardless, notification will arrive asynchronously
      end)
    end
    open_results_window(filtered)
  end)
end

local orig_library_manager = M.library_manager
function M.library_manager()
  if not config.options.use_telescope then
    return M.library_manager_fallback()
  end
  local ok, _ = pcall(require, 'telescope')
  if ok then
    return orig_library_manager()
  else
    return M.library_manager_fallback()
  end
end

return M
