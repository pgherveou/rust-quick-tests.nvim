local Path = require('plenary.path')
local data_path = vim.fn.stdpath('data')
local cache = Path:new(string.format('%s/quick-tests.json', data_path))

local M = {}

---@class ConfigState
---@field features? string
---@field extra_args? table<string>
---@field last_cmd? string
---@field vertical_split? boolean
---@field last_cmd_file? string
---@field last_cmd_cursor? number[]
---@field release? boolean
---@field env? table<string, string>
---@field exact? boolean

---@class Config: ConfigState
local Config = {}

--- Get the release flag
---@return string[]
function Config:releaseFlag()
  if self.release then
    return { '--release' }
  end
  return {}
end

--- Get the features flag
-- @param toml table
---@return string[]
function Config:featuresFlag(toml)
  if self.features == 'all' then
    return { '--all-features' }
  elseif self.features ~= '' then
    local all_features = toml.features
    local features = vim.split(self.features, ',')

    -- filter features that are not in cargo.toml
    features = vim.tbl_filter(function(feature)
      return all_features[feature] ~= nil
    end, features)

    -- add "--features" at the beginning
    if #features > 0 then
      return { '--features', table.concat(features, ',') }
    end

    return features
  end

  return {}
end

--- Get the env flag
function Config:getEnv()
  return self.env or {}
end

---
function Config:verticalSplit()
  return self.vertical_split
end

--- Get the extra args
---@return string[]
function Config:extraArgs()
  return self.extra_args or {}
end

--- Get the exact flag
---@return string[]
function Config:exactFlag()
  if self.exact then
    return { '--exact' }
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
    extra_args = {},
    last_cmd = nil,
    release = false,
    features = '',
    env = {},
    exact = true,
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

-- Clear the global config
function M.clear()
  local config = global_config()
  config[vim.fn.getcwd()] = {}
  cache:write(vim.fn.json_encode(config), 'w')
end

return M
