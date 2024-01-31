local M = {
  hover_actions = function()
    require('rust-quick-tests.hover_actions').hover_actions()
  end,
  replay_last = function()
    require('rust-quick-tests.hover_actions').replay_last()
  end,
}

vim.api.nvim_create_user_command('RustMainArgs', function(opts)
  local args = table.concat(opts.fargs, ' ')
  require('rust-quick-tests.treesitter').extra_args = args
end, {
  nargs = '*',
})

-- noop for now
function M.setup() end

return M
