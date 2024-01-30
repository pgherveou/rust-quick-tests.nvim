local M = {}
function M.setup()
  vim.keymap.set('n', 'K', function()
    require('rust-quick-tests.hover_actions').hover_actions()
  end, { noremap = true, silent = true })
end

return M
