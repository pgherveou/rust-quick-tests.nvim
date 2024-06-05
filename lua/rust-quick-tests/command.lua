---@class CommandState
---@field command string
---@field env table<string, string>
---@field args string[]
---@field debug_args? string[]
---@field manifest_path string
---@field cargo_root string
---@field file string
---@field cursor number[]

---@class Command: CommandState
local Command = {}

---@param ... string[] | string
local function flatten(...)
  local flattened = {}
  for _, t in ipairs({ ... }) do
    if type(t) == 'table' then
      for _, v in ipairs(t) do
        table.insert(flattened, v)
      end
    else
      table.insert(flattened, t)
    end
  end
  return flattened
end

function Command:new(state)
  state.args = flatten(unpack(state.args))
  setmetatable(state, self)
  self.__index = self
  return state
end

function Command:to_string()
  local envs = {}
  for k, v in pairs(self.env) do
    envs[#envs + 1] = string.format('%s=%s', k, v)
  end

  return table.concat(flatten(envs, self.command, self.args), ' ')
end

return Command
