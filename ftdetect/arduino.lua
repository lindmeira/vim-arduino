vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.ino',
  callback = function()
    vim.bo.filetype = 'arduino'
  end,
})

-- Heuristic for other files in Arduino directories
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = { '*/Arduino/**/*.h', '*/Arduino/**/*.c', '*/Arduino/**/*.cpp' },
  callback = function()
    vim.bo.filetype = 'arduino'
  end,
})
