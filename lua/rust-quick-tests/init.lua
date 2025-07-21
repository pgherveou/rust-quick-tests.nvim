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

-- Split args, respecting quotes
local function split_args(input)
  local args = {}
  local i = 1
  local length = #input
  local quote_char = nil
  local arg = ''

  while i <= length do
    local char = input:sub(i, i)
    if char == '"' or char == '\'' then
      if quote_char == nil then
        quote_char = char
      elseif quote_char == char then
        quote_char = nil
      else
        arg = arg .. char
      end
    elseif char == ' ' and quote_char == nil then
      if #arg > 0 then
        table.insert(args, arg)
        arg = ''
      end
    else
      arg = arg .. char
    end
    i = i + 1
  end

  if #arg > 0 then
    table.insert(args, arg)
  end

  return args
end

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
      local args = split_args(table.concat(opts.fargs, ' '))
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
    elseif cmd == 'vsplit' then
      config.update({ vertical_split = true })
    elseif cmd == 'hsplit' then
      config.update({ vertical_split = false })
    elseif cmd == 'exact' then
      config.update({ exact = true })
    elseif cmd == 'no-exact' then
      config.update({ exact = false })
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
  RustQuick exact - Enable exact test name matching
  RustQuick no-exact - Disable exact test name matching
  RustQuick clear - Clear the current config
  RustQuick show - Show the current config
  ]],
    complete = function(_, cmdline)
      if #vim.split(cmdline, ' ') > 2 then
        return {}
      end
      return { 'args', 'release', 'dev', 'clear', 'env', 'log', 'features', 'vsplit', 'hsplit', 'exact', 'no-exact', 'show' }
    end,
  })
end

return M
