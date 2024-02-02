local Path = require('plenary.path')
local data_path = vim.fn.stdpath('data')
local cache = Path:new(string.format('%s/quick-tests.json', data_path))

local M = {}

---@class LocalConfig
local default_config = {
  ---@type string
  rust_log = '',
  ---@type string
  extra_args = '',
  ---@type string
  last_cmd = nil,
  ---@type boolean
  release = false,
}

---@class table<string, LocalConfig> | nil
local global_cfg = nil

-- Get the global config
---@return table<string, LocalConfig>
function M.global_config()
  if global_cfg == nil then
    if cache:exists() then
      global_cfg = vim.json.decode(cache:read())
    else
      global_cfg = {}
    end
  end
  return global_cfg
end

-- Get the local config
---@return LocalConfig
function M.cwd_config()
  return M.global_config()[vim.fn.getcwd()] or default_config
end

-- Update the global config
---@param update LocalConfig
function M.update(update)
  global_cfg = vim.tbl_deep_extend('force', M.global_config(), { [vim.fn.getcwd()] = update })
  cache:write(vim.fn.json_encode(global_cfg), 'w')
end

return M
