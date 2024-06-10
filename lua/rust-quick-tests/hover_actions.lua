-- Adapted from https://github.com/mrcjkb/rustaceanvim
---@source types.lua
local lsp_util = vim.lsp.util
local ts = require('rust-quick-tests.treesitter')
local config = require('rust-quick-tests.config')
local M = {}

---@class HoverActionsState
local _state = {
  ---@type integer | nil
  winnr = nil,
  ---@type CommandInfo[]
  commands = nil,
}

local function close_hover()
  local ui = require('rust-quick-tests.ui')
  ui.close_win(_state.winnr)
end

--@param cmd string
local function execute_command(cmd)
  require('rust-quick-tests.termopen').execute_command(cmd)
end

-- run the command under the cursor, if the thing under the cursor is not the
-- command then do nothing
local function run_command()
  local winnr = vim.api.nvim_get_current_win()
  local line = vim.api.nvim_win_get_cursor(winnr)[1]

  if line > #_state.commands then
    return
  end

  local info = _state.commands[line]
  close_hover()

  if info.type == 'run' then
    local cmd = info.command
    local last_cmd = cmd:to_string()

    config.update({ last_cmd = last_cmd, last_cmd_file = cmd.file, last_cmd_cursor = cmd.cursor })
    execute_command(last_cmd)
  else
    require('rust-quick-tests.dap').start(info.command)
  end
end

---@return string[]
local function parse_commands()
  local prompt = {}

  for i, value in ipairs(_state.commands) do
    table.insert(prompt, string.format('%d. %s', i, value.title))
  end

  return prompt
end

function M.handler(_, result)
  if not (result and result.contents) then
    -- return { 'No information available' }
    return
  end

  local markdown_lines = lsp_util.convert_input_to_markdown_lines(result.contents, {})
  if result.actions then
    _state.commands = result.actions[1].commands
    local prompt = parse_commands()
    local l = {}

    for _, value in ipairs(prompt) do
      table.insert(l, value)
    end
    table.insert(l, '---')

    markdown_lines = vim.list_extend(l, markdown_lines)
  end

  if vim.tbl_isempty(markdown_lines) then
    -- return { 'No information available' }
    return
  end

  local win_opt = {
    replace_builtin_hover = true,
    auto_focus = true,
    border = {
      { '╭', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╮', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '╯', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╰', 'FloatBorder' },
      { '│', 'FloatBorder' },
    },

    focusable = true,
    focus_id = 'tests-hover-actions',
    close_events = { 'CursorMoved', 'BufHidden', 'InsertCharPre' },
  }

  local bufnr, winnr = lsp_util.open_floating_preview(markdown_lines, 'markdown', win_opt)

  vim.api.nvim_set_current_win(winnr)

  if _state.winnr ~= nil then
    return
  end

  -- update the window number here so that we can map escape to close even
  -- when there are no actions, update the rest of the state later
  _state.winnr = winnr
  vim.keymap.set('n', 'q', close_hover, { buffer = bufnr, noremap = true, silent = true })
  vim.keymap.set('n', '<Esc>', close_hover, { buffer = bufnr, noremap = true, silent = true })

  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function()
      _state.winnr = nil
    end,
  })

  --- stop here if there are no possible actions
  if result.actions == nil then
    return
  end

  -- makes more sense in a dropdown-ish ui
  vim.wo[winnr].cursorline = true

  -- run the command under the cursor
  vim.keymap.set('n', '<CR>', function()
    run_command()
  end, { buffer = bufnr, noremap = true, silent = true })
end

function M.get_hover_actions()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return ts.find_runnable(bufnr, cursor)
end

function M.show_actions(actions)
  M.handler(nil, actions)
end

function M.hover_actions()
  M.handler(nil, M.get_hover_actions())
end

function M.replay_last()
  local last_cmd = config.cwd_config().last_cmd
  if last_cmd ~= nil then
    execute_command(last_cmd)
  end
end

function M.snap_last()
  local last_cmd = config.cwd_config()
  local last_cmd_file = last_cmd.last_cmd_file
  local last_cmd_cursor = last_cmd.last_cmd_cursor or { 1, 0 }

  if last_cmd_file ~= nil then
    vim.cmd('e ' .. last_cmd_file)
    vim.api.nvim_win_set_cursor(0, last_cmd_cursor)
  end
end

return M
