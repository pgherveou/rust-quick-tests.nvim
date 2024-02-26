local M = {
  hover_actions = function()
    require('rust-quick-tests.hover_actions').hover_actions()
  end,
  replay_last = function()
    require('rust-quick-tests.hover_actions').replay_last()
  end,
}

M.setup = function()
  vim.api.nvim_create_user_command('RustQuick', function(opts)
    local config = require('rust-quick-tests.config')
    local cmd = table.remove(opts.fargs, 1)

    if cmd == 'args' then
      local args = table.concat(opts.fargs, ' ')
      config.update({ extra_args = args })
    elseif cmd == 'release' then
      config.update({ release = true })
    elseif cmd == 'log' then
      local args = table.concat(opts.fargs, ' ')
      config.update({ rust_log = args })
    elseif cmd == 'features' then
      -- trim the string
      config.update({ features = vim.trim(opts.fargs[1] or '') })
    elseif cmd == 'dev' then
      config.update({ release = false })
    else
      vim.notify('Unknown command: ' .. cmd, vim.log.levels.ERROR)
    end
  end, {
    nargs = '*',
    desc = [[
  Set quick test options:
  RustQuick args <args> - Set extra args to pass to cargo run
  RustQuick release - Run tests in release mode
  RustQuick dev - Run tests in dev mode
  ]],
    complete = function(_, cmdline)
      if #vim.split(cmdline, ' ') > 2 then
        return {}
      end
      return { 'args', 'release', 'dev', 'log', 'features' }
    end,
  })
end

return M
