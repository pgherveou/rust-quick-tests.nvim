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

---@class TSNode
local _TSNode = {}

---@class NamespaceInfo
local _state = {
  ---@type string
  name = nil,
  ---@type TSNode
  node = nil,
}

-- Get the path to the nearest Cargo.toml file
---@param file string
---@return string | nil
local get_cargo_toml = function(file)
  local path = vim.fn.fnamemodify(file, ':h')
  while path ~= '/' do
    local cargo_toml = path .. '/Cargo.toml'
    if vim.fn.filereadable(cargo_toml) == 1 then
      return cargo_toml
    end
    path = vim.fn.fnamemodify(path, ':h')
  end

  return nil
end

-- return the module name given a rust src file and a cargo toml file
---@param rust_file string
---@param cargo_toml string
---@return string
local module_from_path = function(rust_file, cargo_toml)
  local dir = vim.fn.fnamemodify(cargo_toml, ':h')

  local relative_path = vim.fn.substitute(rust_file, dir, '', 'g')
  relative_path = vim.fn.substitute(relative_path, '/src/', '', 'g')
  if relative_path == 'main.rs' or relative_path == 'lib.rs' then
    return ''
  end

  relative_path = relative_path:gsub('/mod.rs', '')
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
  local file = vim.api.nvim_buf_get_name(bufnr)
  local cargo_toml = get_cargo_toml(file)
  if cargo_toml == nil then
    return {}
  end

  local module_prefix = module_from_path(file, cargo_toml)

  local full_test_name = table.concat(names) .. test_name
  if module_prefix ~= '' then
    full_test_name = module_prefix .. '::' .. full_test_name
  end

  local command =
    string.format('cargo test --manifest-path %s --all-features %s -- --exact --nocapture', cargo_toml, full_test_name)

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
      value = '\n```rust\n' .. full_test_name .. '\n```\n\n```rust\nfn ' .. test_name .. '()\n```',
    },
  }
end

local function get_bin_arg(cargo_toml, file)
  local text = io.open(cargo_toml):read('*a')
  local toml = require('rust-quick-tests.toml').parse(text)

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
  local file = vim.api.nvim_buf_get_name(bufnr)
  local cargo_toml = get_cargo_toml(file)
  if cargo_toml == nil then
    return {}
  end

  local bin_arg = get_bin_arg(cargo_toml, file)
  local command = string.format('cargo run --manifest-path %s', cargo_toml)
  if bin_arg ~= nil then
    command = command .. ' --bin ' .. bin_arg
  end

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
      value = '```rust\nfn main()\n```',
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

return {
  -- Get Rust runnable for the buffer and cursor position
  ---@param bufnr number
  ---@param cursor table
  ---@return table | nil
  find_runnable = function(bufnr, cursor)
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
  end,
}
