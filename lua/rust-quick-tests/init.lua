local M = {
  hover_actions = function()
    require('rust-quick-tests.hover_actions').hover_actions()
  end,
  replay_last = function()
    require('rust-quick-tests.hover_actions').replay_last()
  end,
  snap_last = function()
    require('rust-quick-tests.hover_actions').snap_last()
  end,
}

local function array_to_dic(arr)
  local dic = {}
  for _, pair in ipairs(arr) do
    local key, value = unpack(vim.split(pair, '=', { plain = true }))
    dic[key] = value
  end
  return dic
end

M.setup = function()
  vim.api.nvim_create_user_command('RustQuick', function(opts)
    local config = require('rust-quick-tests.config')
    local cmd = table.remove(opts.fargs, 1)

    if cmd == 'args' then
      local args = table.concat(opts.fargs, ' ')
      config.update({ extra_args = args })
    elseif cmd == 'release' then
      config.update({ release = true })
    elseif cmd == 'dev' then
      config.update({ release = false })
    elseif cmd == 'env' then
      config.update({ env = array_to_dic(opts.fargs) })
    elseif cmd == 'log' then
      local args = { RUST_LOG = opts.fargs[1] }
      config.update({ env = args })
    elseif cmd == 'features' then
      config.update({ features = vim.trim(opts.fargs[1] or '') })
    elseif cmd == 'clear' then
      config.clear()
    elseif cmd == 'show' then
      print(vim.inspect(config.cwd_config()))
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
  RustQuick env <key=value> - Set environment variable
  RustQuick log <level> - Set RUST_LOG environment variable
  RustQuick features <features> - Set the features flag
  RUstQuick clear - Clear the current config
  RustQuick show - Show the current config
  ]],
    complete = function(_, cmdline)
      if #vim.split(cmdline, ' ') > 2 then
        return {}
      end
      return { 'args', 'release', 'dev', 'clear', 'env', 'log', 'features', 'show' }
    end,
  })
end

return M
