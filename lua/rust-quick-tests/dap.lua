local Path = require('plenary.path')
local Job = require('plenary.job')

---@source types.lua
---@class DapServerConfig
---@field type dap_adapter_type_server The type of debug adapter.
---@field host? string The host to connect to.
---@field port string The port to connect to.
---@field executable DapExecutable The executable to run
---@field name? string

---@class DapExecutable
---@field command string The executable.
---@field args string[] Its arguments.

---@alias dap_adapter_type_server "server"

local ok, dap = pcall(require, 'dap')
if not ok then
  return {
    start = function()
      vim.notify('nvim-dap not found.', vim.log.levels.ERROR)
    end,
  }
end

local M = {}

--- Get rustc commit hash
---@param callback fun(val: string | nil)
local function get_rustc_commit_hash(callback)
  local noop = function() end

  Job:new({
    command = 'rustc',
    args = { '--version', '--verbose' },
    on_stdout = function(_, data)
      local match = data:match('commit%-hash:%s+([^\n]+)')
      if match then
        callback(match)
        callback = noop
      end
    end,
    on_exit = function()
      callback(nil)
    end,
  }):start()
end

--- Get rustc sysroot
---@param info 'sysroot' | 'target-libdir'
---@param callback fun(value: string | nil)
local function rustc_get(info, callback)
  local noop = function() end
  Job:new({
    command = 'rustc',
    args = { '--print', info },
    maximum_results = 1,
    on_stdout = function(_, data)
      callback(data)
      callback = noop
    end,
    on_exit = function()
      callback(nil)
    end,
  }):start()
end

---@alias DapSourceMap {[string]: string}

---@type {[string]: DapSourceMap}
local source_maps = {}

--- Generate source map for codelldb
local function generate_source_map(workspace_root)
  if source_maps[workspace_root] then
    return
  end

  rustc_get('sysroot', function(rustc_sysroot)
    get_rustc_commit_hash(function(commit_hash)
      if not commit_hash or not rustc_sysroot then
        return
      end

      for _, src_dir in pairs({ 'src', 'rustc-src' }) do
        local src_path = Path:new(rustc_sysroot, 'lib', 'rustlib', src_dir, 'rust')
        if src_path:exists() then
          source_maps[workspace_root] = {
            [Path:new('/rustc', commit_hash):absolute()] = src_path:absolute(),
          }
          break
        end
      end
    end)
  end)
end

---map for codelldb, list of strings for lldb-dap
---@param key string
---@param segments string[]
---@return {[string]: string}
local function env(key, segments)
  local value = table.concat(segments, ':')
  ---@diagnostic disable-next-line: missing-parameter
  local existing = vim.loop.os_getenv(key)
  if existing then
    value = value .. ':' .. existing
  end
  return { [key] = value }
end

---@alias EnvironmentMap {[string]: string}

---@type {[string]: EnvironmentMap}
local environments = {}

-- Most succinct description: https://github.com/bevyengine/bevy/issues/2589#issuecomment-1753413600
---@param workspace_root string
local function add_dynamic_library_paths(workspace_root)
  if environments[workspace_root] then
    return
  end

  rustc_get('target-libdir', function(rustc_target_path)
    if not rustc_target_path then
      return
    end

    local target_path = Path:new(workspace_root, 'target', 'debug', 'deps'):absolute()

    if vim.loop.os_uname().sysname == 'Darwin' then
      environments[workspace_root] = env('DKLD_LIBRARY_PATH', { rustc_target_path, target_path })
    else
      environments[workspace_root] = env('LD_LIBRARY_PATH', { rustc_target_path, target_path })
    end
  end)
end

---@param workspace_root string
local function configure(workspace_root)
  generate_source_map(workspace_root)
  add_dynamic_library_paths(workspace_root)
end

---@param job Job
---@param manifest_path string
---@return table | nil
local function find_artifact(job, manifest_path)
  for _, line in ipairs(job:result()) do
    local is_json, artifact = pcall(vim.fn.json_decode, line)
    if
      is_json
      and artifact.reason == 'compiler-artifact'
      and artifact.manifest_path == manifest_path
      and (artifact.executable and artifact.executable ~= vim.NIL)
    then
      return artifact
    end
  end
end

---@param cmd Command
function M.start(cmd)
  configure(Path:new(cmd.manifest_path):parent())
  vim.notify('Compiling a debug build for debugging. This might take some time...')
  vim.notify('Building: ' .. cmd:to_string())

  Job:new({
    command = cmd.command,
    args = cmd.args,
    on_exit = function(job)
      vim.schedule(function()
        if job.code ~= 0 then
          vim.notify(
            'An error occurred while compiling. Please fix all compilation issues and try again',
            vim.log.levels.ERROR
          )
          return
        end

        local artifact = find_artifact(job, cmd.manifest_path)
        if not artifact then
          vim.notify('No artifact found for ' .. cmd.manifest_path, vim.log.levels.ERROR)
          return
        end
        local args = cmd.debug_args or {}
        args = args[1] == '--' and { unpack(args, 2) } or args
        print('Debugging Artifact: ' .. artifact.executable)
        print('Debugging Args: ' .. vim.inspect(args))

        local envs = vim.tbl_extend('keep', cmd.env, environments[cmd.manifest_path] or { NVIM_DEBUG = 'true' })
        local config = {
          args = args,
          env = envs,
          initCommands = {
            'settings set plugin.jit-loader.gdb.enable on',
          },
          name = 'Rust debug client',
          program = artifact.executable,
          request = 'launch',
          sourceMap = source_maps[cmd.manifest_path],
          stopOnEntry = false,
          type = 'codelldb',
        }

        dap.run(config)
      end)
    end,
  }):start()
end

return M
