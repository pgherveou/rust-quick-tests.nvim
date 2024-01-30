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
    (#any-of? @macro_name "tokio::test" "test")
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
local get_cargo_toml_dir = function(file)
  local path = vim.fn.fnamemodify(file, ':h')
  while path ~= '/' do
    if vim.fn.filereadable(path .. '/Cargo.toml') == 1 then
      return path
    end
    path = vim.fn.fnamemodify(path, ':h')
  end

  return nil
end

-- return the module name from a file path
---@param rust_file string
---@return string
local module_from_path = function(rust_file)
  local dir = get_cargo_toml_dir(rust_file)

  if dir == nil then
    return ''
  end

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

-- create test args
---@param test_name string
---@param namespace_stack NamespaceInfo[]
---@return table
local function make_test_arg(bufnr, test_name, namespace_stack)
  local names = vim.tbl_map(function(ns)
    return ns.name .. '::'
  end, namespace_stack)
  local file = vim.api.nvim_buf_get_name(bufnr)
  local module_prefix = module_from_path(file)

  local full_test_name = table.concat(names) .. test_name
  if module_prefix ~= '' then
    full_test_name = module_prefix .. '::' .. full_test_name
  end

  local command = string.format('cargo test --all-features %s -- --exact --nocapture', full_test_name)

  local runCommand = {
    id = 'run_test',
    command = command,
    title = '▶︎ Run Test',
    tooltip = 'test ' .. full_test_name,
  }

  local debugCommand = {
    id = 'debug_test',
    command = command,
    title = '▶︎ Debug Test',
    tooltip = 'debug ' .. full_test_name,
  }

  return {
    actions = {
      {
        commands = {
          runCommand,
          debugCommand,
        },
      },
    },
    contents = {
      kind = 'markdown',
      value = '\n```rust\n' .. full_test_name .. '\n```\n\n```rust\nfn ' .. test_name .. '()\n```',
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

-- Get Rust test for the current cursor position
-- example usage:
---@param bufnr number
---@param cursor table
---@return table | nil
return function(bufnr, cursor)
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
    elseif capture_name == 'test.name' and is_cursor_in_row(node, cursor) then
      local test_name = vim.treesitter.get_node_text(node, bufnr)
      return make_test_arg(bufnr, test_name, namespace_stack)
    end
  end

  return nil
end
