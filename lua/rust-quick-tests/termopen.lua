-- Adapted from https://github.com/mrcjkb/rustaceanvim
---@type integer | nil
local latest_buf_id = nil

local M = {
  execute_command = function(full_command)
    local ui = require('rust-quick-tests.ui')
    local config = require('rust-quick-tests.config')
    local cfg = config.cwd_config()

    -- check if a buffer with the latest id is already open, if it is then
    -- delete it and continue
    ui.delete_buf(latest_buf_id)

    -- create the new buffer
    latest_buf_id = vim.api.nvim_create_buf(false, true)

    -- vim.api.nvim_set_option_value(latest_buf_id, 'wrap', false)
    vim.api.nvim_buf_set_option(latest_buf_id, 'wrap', false)

    -- split the window to create a new buffer and set it to our window
    ui.split(latest_buf_id, cfg:verticalSplit())

    -- run the command
    local job_id = vim.fn.termopen(full_command)

    -- close the buffer when escape is pressed :)
    vim.keymap.set('n', '<ESC>', function()
      vim.api.nvim_buf_delete(latest_buf_id, { force = true })
    end, { buffer = latest_buf_id, noremap = true, silent = true })

    vim.api.nvim_buf_attach(latest_buf_id, false, {
      on_detach = function()
        vim.fn.jobstop(job_id)
        latest_buf_id = nil
      end,
    })
  end,
}

return M
