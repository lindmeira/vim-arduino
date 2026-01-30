local M = {}

M.data = {}
M.listeners = {}

function M.clear()
  M.data = {}
  for _, cb in pairs(M.listeners) do
    pcall(cb, nil) -- nil indicates clear
  end
end

function M.subscribe(cb)
  local id = tostring(cb)
  M.listeners[id] = cb
  return id
end

function M.unsubscribe(id)
  M.listeners[id] = nil
end

function M.add(lines)
  local added = {}
  if type(lines) == 'string' then
    table.insert(M.data, lines)
    table.insert(added, lines)
  elseif type(lines) == 'table' then
    for i, line in ipairs(lines) do
      -- The last element of lines from jobstart is often an empty string
      -- representing the end of the current chunk, not necessarily a blank line.
      -- However, if it's the only element and it's empty, we might skip it.
      if not (i == #lines and line == '') then
        table.insert(M.data, line)
        table.insert(added, line)
      end
    end
  end

  if #added > 0 then
    for _, cb in pairs(M.listeners) do
      pcall(cb, added)
    end
  end
end

function M.get()
  return M.data
end

return M
