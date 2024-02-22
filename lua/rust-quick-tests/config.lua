local Path = require('plenary.path')
local data_path = vim.fn.stdpath('data')
local cache = Path:new(string.format('%s/quick-tests.json', data_path))

local M = {}

---@class ConfigState
---@field rust_log? string
---@field all_features? boolean
---@field extra_args? string
---@field last_cmd? string
---@field release? boolean

---@class Config: ConfigState
local Config = {}

--- Get the rust log command part
---@return table<string, string>
function Config:rustLog()
  if self.rust_log ~= '' then
    return { RUST_LOG = self.rust_log }
  end
  return {}
end

--- Get the release flag
---@return string[]
function Config:releaseFlag()
  if self.release then
    return { '--release' }
  end
  return {}
end

--- Get the --all-features flag
---@return string[]
function Config:allFeaturesFlag()
  if self.all_features then
    return { '--all-features' }
  end
  return {}
end

--- Get the extra args
---@return string[]
function Config:extraArgs()
  if self.extra_args ~= '' then
    return vim.split(self.extra_args, ' ')
  end
  return {}
end

---@class table<string, Config> | nil
local global_cfg = nil

-- Get the global config
---@return table<string, ConfigState>
local function global_config()
  if global_cfg == nil then
    if cache:exists() then
      global_cfg = vim.json.decode(cache:read()) or {}
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
  ---@type ConfigState
  local default_config = {
    rust_log = '',
    extra_args = '',
    last_cmd = nil,
    release = false,
    all_features = false,
  }
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
---@param update ConfigState
function M.update(update)
  global_cfg = vim.tbl_deep_extend('force', global_config(), { [vim.fn.getcwd()] = update })
  cache:write(vim.fn.json_encode(global_cfg), 'w')
end

return M
