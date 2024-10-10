
---@class Path
---@field find_upwards fun(self: Path, file: string): Path
---@field read fun(self: Path): string
---@field parent fun(self: Path): Path
---@field make_relative fun(self: Path, dir?: Path): string
---@field absolute fun(self: Path): Path
---@field joinpath fun(self: Path, path: string): Path

---@class Job
---@field result fun(self: Job): table

---@class CommandInfo
---@field title string
---@field type  'run' | 'debug'
---@field tooltip string
---@field command Command
