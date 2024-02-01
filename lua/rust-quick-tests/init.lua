local M = {
  hover_actions = function()
    require('rust-quick-tests.hover_actions').hover_actions()
  end,
  replay_last = function()
    require('rust-quick-tests.hover_actions').replay_last()
  end,
}

vim.api.nvim_create_user_command('RustQuick', function(opts)
  local ts = require('rust-quick-tests.treesitter')
  local cmd = table.remove(opts.fargs, 1)

  if cmd == 'args' then
    local args = table.concat(opts.fargs, ' ')
    ts.extra_args = args
  elseif cmd == 'release' then
    ts.release = true
  elseif cmd == 'dev' then
    ts.release = false
  else
    vim.notify('Unknown command: ' .. cmd, vim.log.levels.ERROR)
  end
end, {
  nargs = '*',
  complete = function(_, cmdline)
    if #vim.split(cmdline, ' ') > 2 then
      return {}
    end
    return { 'args', 'release' }
  end,
})

-- noop for now
function M.setup() end

return M
