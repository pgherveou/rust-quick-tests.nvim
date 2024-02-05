local M = {}

---@source types.lua
local Path = require('plenary.path')
local config = require('rust-quick-tests.config')

-- query to parse test names from a file
local query_str = [[
  (mod_item name: (identifier) @namespace.name)
  (
    (attribute_item
      [
        (attribute (scoped_identifier) @macro_name)
        (attribute (identifier) @macro_name)
      ]
    )
    .
    (function_item name: (identifier) @test.name) @test.definition
    (#match? @macro_name ".*test$")
  )
  (
    (function_item name: (identifier) @main_name)
    (#eq? @main_name "main")
  )
]]

---@class NamespaceInfo
---@field name string
---@field node TSNode

-- Get the path to the nearest Cargo.toml file
---@param file Path
---@return Path | nil
local get_cargo_toml = function(file)
  local cargo_toml = file:find_upwards('Cargo.toml')
  if cargo_toml == '' then
    return nil
  end
  return cargo_toml
end

-- parse toml file
---@param cargo_toml Path
---@return table
local function parse_toml(cargo_toml)
  local text = cargo_toml:read()
  return require('rust-quick-tests.toml').parse(text)
end

-- return the module name given a rust src file and a cargo toml file
---@param rust_file Path
---@param cargo_toml Path
---@param toml table
---@return string
local module_from_path = function(rust_file, cargo_toml, toml)
  local dir = cargo_toml:parent():absolute()
  local relative_path = rust_file:make_relative(dir)

  if toml.lib ~= nil then
    relative_path = vim.fn.substitute(relative_path, toml.lib.path, '', 'g')
  else
    relative_path = vim.fn.substitute(relative_path, 'src/', '', 'g')
    relative_path = vim.fn.substitute(relative_path, 'main.rs', '', 'g')
    relative_path = vim.fn.substitute(relative_path, 'lib.rs', '', 'g')
  end

  relative_path = relative_path:gsub('mod.rs', '')
  relative_path = relative_path:gsub('^/', '')
  relative_path = relative_path:gsub('/$', '')
  relative_path = relative_path:gsub('.rs', '')
  local module_name = relative_path:gsub('/', '::')

  return module_name
end

-- create test runnable
---@param test_name string
---@param namespace_stack NamespaceInfo[]
---@return table
local function make_test_runnable(bufnr, test_name, namespace_stack)
  local names = vim.tbl_map(function(ns)
    return ns.name .. '::'
  end, namespace_stack)
  local file = Path:new(vim.api.nvim_buf_get_name(bufnr))
  local cargo_toml = get_cargo_toml(file)
  if cargo_toml == nil then
    return {}
  end

  local toml = parse_toml(cargo_toml)
  local module_prefix = module_from_path(file, cargo_toml, toml)
  local full_test_name = table.concat(names) .. test_name
  if module_prefix ~= '' then
    full_test_name = module_prefix .. '::' .. full_test_name
  end

  local cfg = config.cwd_config()

  local command = string.format(
    '%scargo test %s--manifest-path %s --all-features %s -- --exact --nocapture',
    cfg:rustLog(),
    cfg:releaseFlag(),
    cargo_toml:make_relative(),
    full_test_name
  )

  local runCommand = {
    id = 'run_test',
    command = command,
    title = '▶︎ Run Test',
    tooltip = 'test ' .. full_test_name,
  }

  -- TODO handle debug command
  -- local debugCommand = {
  --   id = 'debug_test',
  --   command = command,
  --   title = '▶︎ Debug Test',
  --   tooltip = 'debug ' .. full_test_name,
  -- }

  return {
    actions = {
      {
        commands = {
          runCommand,
        },
      },
    },
    contents = {
      kind = 'markdown',
      value = string.format(
        '# %s\n```rust\nfn %s()\n```\n\n> Use `:RustQuick` to customize command',
        toml.package.name,
        full_test_name
      ),
    },
  }
end

-- get bin arg from Cargo.toml
--@param toml table
--@param file string
local function get_bin_arg(toml, file)
  local bins = toml.bin
  if bins == nil then
    return nil
  end

  for _, bin in pairs(bins) do
    if file:sub(-#bin.path) == bin.path then
      return bin.name
    end
  end

  return nil
end

-- create bin runnable
---@return table
local function make_bin_runnable(bufnr)
  local file = Path:new(vim.api.nvim_buf_get_name(bufnr))
  local cargo_toml = get_cargo_toml(file)
  if cargo_toml == nil then
    return {}
  end

  local toml = parse_toml(cargo_toml)
  local bin_arg = get_bin_arg(toml, file)

  local cfg = config.cwd_config()
  local command = string.format(
    '%scargo run %s --manifest-path %s %s',
    cfg:rustLog(),
    cfg:releaseFlag(),
    cargo_toml:make_relative(),
    cfg:extraArgs()
  )

  local runCommand = {
    id = 'run_main',
    command = command,
    title = '▶︎ Run ' .. (bin_arg or 'main'),
  }

  return {
    actions = {
      {
        commands = {
          runCommand,
        },
      },
    },
    contents = {
      kind = 'markdown',
      value = string.format(
        '# %s\n```rust\nfn main()\n```\n\n> Use `:RustQuick` to customize command',
        toml.package.name
      ),
    },
  }
end

-- check if `node` is after `other_node`
---@param node TSNode
---@param other_node TSNode
---@return boolean
local is_node_after = function(node, other_node)
  local start_row, _, _, _ = node:range()
  local _, _, other_end_row, _ = other_node:range()
  return start_row > other_end_row
end

-- check if cursor is in the same row as `node`
---@param node TSNode
---@param cursor integer[]
---@return boolean
local is_cursor_in_row = function(node, cursor)
  local start_row, _, _, _ = node:range()
  local cursor_row = cursor[1] - 1
  return cursor_row == start_row
end

-- Get Rust runnable for the buffer and cursor position
---@param bufnr number
---@param cursor table
---@return table | nil
M.find_runnable = function(bufnr, cursor)
  local parser = vim.treesitter.get_parser(bufnr, 'rust')
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse('rust', query_str)

  local namespace_stack = {}

  for id, node, _ in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local capture_name = query.captures[id]

    if #namespace_stack > 0 and is_node_after(node, namespace_stack[#namespace_stack].node) then
      table.remove(namespace_stack)
    end

    if capture_name == 'namespace.name' then
      local namespace_name = vim.treesitter.get_node_text(node, bufnr)
      table.insert(namespace_stack, { name = namespace_name, node = node:parent() })
    elseif is_cursor_in_row(node, cursor) then
      if capture_name == 'test.name' then
        local test_name = vim.treesitter.get_node_text(node, bufnr)
        return make_test_runnable(bufnr, test_name, namespace_stack)
      elseif capture_name == 'main_name' then
        return make_bin_runnable(bufnr)
      end
    end
  end

  return nil
end

return M
