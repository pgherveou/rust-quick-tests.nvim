local Path = require('plenary.path')
local data_path = vim.fn.stdpath('data')
local cache = Path:new(string.format('%s/quick-tests.json', data_path))

local M = {}

local default_config = {
  rust_log = '',
  extra_args = '',
  last_cmd = nil,
  release = false,
}

---@class Config
---@field rust_log string
---@field extra_args string
---@field last_cmd string | nil
---@field release boolean
local Config = {}

--- Get the rust log command part
---@return string
function Config:rustLog()
  if self.rust_log ~= '' then
    return string.format('RUST_LOG=%s ', self.rust_log)
  end
  return ''
end

--- Get the release flag
---@return string
function Config:releaseFlag()
  if self.release then
    return '--release '
  end
  return ''
end

--- Get the extra args
---@return string
function Config:extraArgs()
  if self.extra_args ~= '' then
    return string.format('%s ', self.extra_args)
  end
  return ''
end

---@class table<string, Config> | nil
local global_cfg = nil

-- Get the global config
---@return table<string, Config>
local function global_config()
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
---@return Config
M.cwd_config = function()
  local cfg = global_config()[vim.fn.getcwd()] or {}
  cfg = vim.tbl_deep_extend('force', default_config, cfg)
  return Config:new(cfg)
end

-- Create a new config
function Config:new(cfg)
  setmetatable(cfg, Config)
  self.__index = self
  return cfg
end

-- Update the global config
---@param update table
function M.update(update)
  global_cfg = vim.tbl_deep_extend('force', global_config(), { [vim.fn.getcwd()] = update })
  cache:write(vim.fn.json_encode(global_cfg), 'w')
end

return M
