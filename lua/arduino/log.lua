local M = {}

M.data = {}

function M.clear()
  M.data = {}
end

function M.add(lines)
  if type(lines) == 'string' then
    table.insert(M.data, lines)
  elseif type(lines) == 'table' then
    for i, line in ipairs(lines) do
      -- The last element of lines from jobstart is often an empty string
      -- representing the end of the current chunk, not necessarily a blank line.
      -- However, if it's the only element and it's empty, we might skip it.
      if not (i == #lines and line == '') then
        table.insert(M.data, line)
      end
    end
  end
end

function M.get()
  return M.data
end

return M
