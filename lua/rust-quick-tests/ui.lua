-- Pulled from https://github.com/mrcjkb/rustaceanvim
local M = {}

---@param bufnr integer | nil
function M.delete_buf(bufnr)
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param winnr integer | nil
function M.close_win(winnr)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@param bufnr integer
---@param vertical boolean
function M.split(bufnr, vertical)
  local cmd = vertical and 'verti bel vsplit' or 'split'

  vim.cmd(cmd)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)
end

---@param vertical boolean
---@param amount string
function M.resize(vertical, amount)
  local cmd = vertical and 'vertical resize ' or 'resize'
  cmd = cmd .. amount

  vim.cmd(cmd)
end

return M
