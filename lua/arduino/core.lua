local config = require 'arduino.config'
local util = require 'arduino.util'
local term = require 'arduino.term'

local M = {}

local cache_file = vim.fn.stdpath 'cache' .. '/arduino_cores.json'
local cache_expiration = 24 * 60 * 60 -- 1 day

-- Asynchronously run a command and collect JSON output
local function exec_json(cmd, callback)
  local stdout = {}
  local stderr = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr, line)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback(nil)
        return
      end
      local result = table.concat(stdout, '')
      local ok, decoded = pcall(vim.json.decode, result)
      if ok then
        callback(decoded)
      else
        util.notify('Failed to parse JSON output', vim.log.levels.ERROR)
        callback(nil)
      end
    end,
  })
end

function M.update_index(callback)
  util.notify('Updating core index...', vim.log.levels.INFO)
  term.run_silent('arduino-cli core update-index', 'Core Index Update', callback)
end

function M.search(callback)
  -- Check cache
  local stat = vim.uv.fs_stat(cache_file)
  if stat and (os.time() - stat.mtime.sec) < cache_expiration then
    local f = io.open(cache_file, 'r')
    if f then
      local content = f:read '*a'
      f:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok then
        callback(data)
        return
      end
    end
  end

  util.notify('Fetching core list (this may take a moment)...', vim.log.levels.INFO)
  exec_json('arduino-cli core search --format json', function(data)
    if data then
      -- Cache result
      local f = io.open(cache_file, 'w')
      if f then
        f:write(vim.json.encode(data))
        f:close()
      end
      util.notify('Core list updated.', vim.log.levels.INFO)
    end
    callback(data)
  end)
end

function M.list_installed(callback)
  exec_json('arduino-cli core list --format json', callback)
end

function M.list_outdated(callback)
  exec_json('arduino-cli outdated --format json', callback)
end

function M.install(id, callback)
  local cmd = 'arduino-cli core install "' .. id .. '"'
  term.run_silent(cmd, {
    success = 'Core ' .. id .. ' installed successfully.',
    fail = 'Failed to install core ' .. id .. '. Check logs with :ArduinoCheckLogs.'
  }, callback)
end

function M.uninstall(id, callback)
  local cmd = 'arduino-cli core uninstall "' .. id .. '"'
  term.run_silent(cmd, {
    success = 'Core ' .. id .. ' removed successfully.',
    fail = 'Failed to remove core ' .. id .. '. Check logs with :ArduinoCheckLogs.'
  }, callback)
end

function M.upgrade(id, callback)
  local cmd = 'arduino-cli core upgrade "' .. id .. '"'
  term.run_silent(cmd, {
    success = 'Core ' .. id .. ' upgraded successfully.',
    fail = 'Failed to upgrade core ' .. id .. '. Check logs with :ArduinoCheckLogs.'
  }, callback)
end

function M.add_third_party_urls(url_input)
  local urls = {}
  -- Parse space-separated input
  for url in url_input:gmatch('%S+') do
    -- Basic URL validation
    if not url:match '^https?://.+' then
      util.notify('Invalid URL syntax: ' .. url, vim.log.levels.ERROR)
      return
    end
    table.insert(urls, url)
  end

  if #urls == 0 then
    util.notify('No URLs provided.', vim.log.levels.WARN)
    return
  end

  -- Construct chained command to add all URLs
  local config_cmd = ''
  for i, url in ipairs(urls) do
    -- Escape URL just in case
    local cmd = string.format('arduino-cli config add board_manager.additional_urls "%s"', url)
    if i == 1 then
      config_cmd = cmd
    else
      config_cmd = config_cmd .. ' && ' .. cmd
    end
  end

  util.notify('Adding ' .. #urls .. ' URL(s) to configuration...', vim.log.levels.INFO)

  vim.fn.jobstart(config_cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        util.notify('Failed to add URLs to configuration.', vim.log.levels.ERROR)
        return
      end

      -- Run update-index
      util.notify('Updating core index...', vim.log.levels.INFO)
      local output = {}
      
      vim.fn.jobstart('arduino-cli core update-index', {
        on_stdout = function(_, data)
          if data then
            for _, line in ipairs(data) do
              table.insert(output, line)
            end
          end
        end,
        on_stderr = function(_, data)
          if data then
            for _, line in ipairs(data) do
              table.insert(output, line)
            end
          end
        end,
        on_exit = function(_, update_code)
          if update_code == 0 then
            util.notify('Core manager updated successfully.', vim.log.levels.INFO)
            -- Invalidate cache so the new cores show up in the manager
            os.remove(cache_file)
          else
            -- Check if any of the added URLs appear in the error output
            local output_str = table.concat(output, '\n')
            local found_bad = false
            for _, url in ipairs(urls) do
              -- Plain text search for the URL in the error log
              if output_str:find(url, 1, true) then
                util.notify('Invalid or unreachable URL: ' .. url, vim.log.levels.ERROR)
                found_bad = true
              end
            end
            if not found_bad then
              util.notify('Core update failed. Check logs.', vim.log.levels.ERROR)
            end
            -- Log output for debugging
            require('arduino.log').add(output)
          end
        end,
      })
    end,
  })
end

return M
