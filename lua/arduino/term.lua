local log = require 'arduino.log'
local util = require 'arduino.util'

local M = {}

function M.run(cmd)
  vim.cmd 'split'
  vim.cmd('terminal ' .. cmd)
  vim.cmd 'startinsert'
end

function M.run_silent(cmd, title, callback)
  log.clear()
  log.add('Running: ' .. cmd)

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      log.add(data)
    end,
    on_stderr = function(_, data)
      log.add(data)
    end,
    on_exit = function(_, code)
      if code == 0 then
        util.notify(title .. ' successful.', vim.log.levels.INFO)
        util.parse_and_notify_memory_usage()
        if callback then
          vim.schedule(callback)
        end
      else
        util.notify(title .. ' failed. Check logs with :ArduinoCheckLogs.', vim.log.levels.ERROR)
      end
    end,
  })
end

function M.run_and_callback(cmd, callback)
  -- Run command and call callback on success (exit code 0)
  -- We can't easily chain commands in terminal mode unless we construct a shell command
  -- like "cmd && echo success".
  -- Or use jobstart.
  -- The original used terminal for visual feedback.

  -- Let's construct a shell command chain if possible, or use a specialized approach.
  -- "cmd && touch /tmp/success" ? No.

  -- If we want to run serial AFTER upload, we can do:
  -- "cmd ; if [ $? -eq 0 ]; then other_cmd; fi"

  -- But the callback might be complex.
  -- Let's assume the callback is just "run serial".

  -- The original used:
  -- let s:TERM = '!'
  -- let ret = arduino#Upload()
  -- if ret == 0 call arduino#Serial()

  -- Which means it ran synchronously in the shell!
  -- "terminal!" in Vim means "run in terminal window".

  -- If we use :terminal in Neovim, it's async and doesn't block.
  -- So we can't wait for it easily in a synchronous function.

  -- We can use jobstart with on_exit.

  vim.cmd 'botright split'
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function(job_id, exit_code, event)
      if exit_code == 0 then
        if callback then
          vim.schedule(callback)
        end
      else
        vim.schedule(function()
          print('Command failed with exit code ' .. exit_code)
        end)
      end
    end,
  })
  vim.cmd 'startinsert'
end

return M
