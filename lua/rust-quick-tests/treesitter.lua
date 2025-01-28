local M = {}

---@source types.lua
local Path = require('plenary.path')
local config = require('rust-quick-tests.config')
local Command = require('rust-quick-tests.command')

-- query to parse test names from a file
local query_str = [[
  ; Match namespace
  (mod_item name: (identifier) @namespace.name)

  ; Match test function
  (
    (attribute_item
      [
        (attribute (scoped_identifier) @macro_name)
        (attribute (identifier) @macro_name)
      ]
    )
    .
    (function_item name: (identifier) @test.name) @test.definition
    (#match? @macro_name ".*test$|benchmark")
  )

  ; Match main function
  (
    (function_item name: (identifier) @main_name)
    (#eq? @main_name "main")
  )

  ; Match any item with a doc comment
  (
    (line_comment) @doc_comment
  )
]]

--- Get the first identifier in a node
---@param node TSNode
---@param bufnr number
---@return string
local function get_identifier(node, bufnr)
  for child in node:iter_children() do
    if child:type() == 'identifier' then -- Adjust the type according to the language grammar
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return ''
end

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
  local relative_path = Path:new(rust_file:absolute()):make_relative(dir)

  if toml.lib ~= nil then
    relative_path = vim.fn.substitute(relative_path, toml.lib.path or 'src', '', 'g')
  else
    relative_path = vim.fn.substitute(relative_path, 'src/', '', 'g')
    relative_path = vim.fn.substitute(relative_path, 'main.rs', '', 'g')
    relative_path = vim.fn.substitute(relative_path, 'lib.rs', '', 'g')
  end

  relative_path = relative_path:gsub('mod.rs', '')
  relative_path = relative_path:gsub('^/', '')
  relative_path = relative_path:gsub('/$', '')
  relative_path = relative_path:gsub('%.rs$', '')
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
  local runCommand = {
    command = Command:new({
      file = file:absolute(),
      cursor = vim.api.nvim_win_get_cursor(0),
      command = 'cargo',
      manifest_path = cargo_toml:absolute(),
      env = cfg:getEnv(),
      args = {
        'test',
        cfg:releaseFlag(),
        '--manifest-path',
        cargo_toml:make_relative(),
        cfg:featuresFlag(toml),
        full_test_name,
        '--',
        '--exact',
        '--nocapture',
        '--include-ignored',
      },
    }),
    type = 'run',
    title = '▶︎ Run Test',
    tooltip = 'test ' .. full_test_name,
  }

  local debugCommand = {
    command = Command:new({
      command = 'cargo',
      manifest_path = cargo_toml:absolute(),
      env = cfg:getEnv(),
      args = {
        'test',
        '--no-run',
        '--message-format=json',
        '--manifest-path',
        cargo_toml:make_relative(),
        cfg:featuresFlag(toml),
        full_test_name,
      },
      debug_args = {
        full_test_name,
        '--exact',
        '--nocapture',
      },
    }),
    type = 'debug',
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
      value = string.format(
        '# %s\n```rust\nfn %s()\n```\n\n> Use `:RustQuick` to customize command',
        toml.package.name,
        full_test_name
      ),
    },
  }
end

-- create doc test runnable
---@param test_name string
---@param line integer
---@param namespace_stack NamespaceInfo[]
---@return table
local function make_doc_test_runnable(bufnr, test_name, line, namespace_stack)
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
  local runCommand = {
    command = Command:new({
      file = file:absolute(),
      cursor = vim.api.nvim_win_get_cursor(0),
      command = 'cargo',
      manifest_path = cargo_toml:absolute(),
      env = cfg:getEnv(),
      args = {
        'test',
        '--doc',
        cfg:releaseFlag(),
        '--manifest-path',
        cargo_toml:make_relative(),
        cfg:featuresFlag(toml),
        string.format('"%s\\ (line\\ %d)"', full_test_name, line),
        '--',
        '--nocapture',
      },
    }),
    type = 'run',
    title = '▶︎ Run Doc Test',
    tooltip = 'test ' .. full_test_name,
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
        '# %s\n```rust\n%s\n```\n\n> Use `:RustQuick` to customize command',
        toml.package.name,
        full_test_name
      ),
    },
  }
end

-- Get the example args if the file is in the file being tested is an example
--@param toml table
--@return table
local function exampleArgs(toml)
  local file_path = vim.fn.expand('%:p')
  local cargo_toml = get_cargo_toml(Path:new(file_path))

  if cargo_toml == nil then
    return {}
  end
  local root = cargo_toml:parent()

  local examples = toml.example or {}

  for _, example in pairs(examples) do
    local example_path = root:joinpath(example.path)

    if file_path == example_path:absolute() then
      local args = { '--example', example.name }
      if example['required-features'] then
        local features = { '--features' }
        for _, feature in ipairs(example['required-features']) do
          table.insert(features, feature)
        end
        table.insert(args, table.concat(features, ','))
      end
      return args
    end
  end

  -- /examples/<component>/main.rs
  local component = file_path:match('/examples/([^/]+)/[^/]+%.%w+$')
  if component then
    return { '--example', component }
  end

  -- /examples/<component>.rs
  component = file_path:match('/examples/([^/]+)%.rs$')
  if component then
    return { '--example', component }
  end

  return {}
end

-- get bin arg from Cargo.toml
--@param toml table
--@param file string
local function get_bin_name(toml, file)
  local bins = toml.bin
  if bins == nil then
    return nil
  end

  for _, bin in pairs(bins) do
    if bin.path ~= nil then
      if file:sub(-string.len(bin.path)) == bin.path then
        return bin.name
      end
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
  local bin_name = get_bin_name(toml, file:absolute())

  local bin_args = {}
  if bin_name then
    bin_args = { '--bin', bin_name }
  end

  local cfg = config.cwd_config()

  local runCommand = {
    command = Command:new({
      file = file:absolute(),
      cursor = vim.api.nvim_win_get_cursor(0),
      command = 'cargo',
      manifest_path = cargo_toml:absolute(),
      env = cfg:getEnv(),
      args = {
        'run',
        cfg:releaseFlag(),
        '--manifest-path',
        cargo_toml:make_relative(),
        cfg:featuresFlag(toml),
        bin_args,
        exampleArgs(toml),
        cfg:extraArgs(),
      },
    }),
    type = 'run',
    title = '▶︎ Run ' .. (bin_name or 'main'),
  }

  local debugCommand = {
    id = 'debug',
    command = Command:new({
      file = file:absolute(),
      cursor = vim.api.nvim_win_get_cursor(0),
      command = 'cargo',
      manifest_path = cargo_toml:absolute(),
      env = cfg:getEnv(),
      args = {
        'build',
        '--manifest-path',
        cargo_toml:make_relative(),
        cfg:featuresFlag(toml),
        exampleArgs(toml),
        '--message-format',
        'json',
      },
      debug_args = cfg:extraArgs(),
    }),
    type = 'debug',
    title = '▶︎ Debug ' .. (bin_name or 'main'),
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

-- Make the test name from the macro name and the test fn name
--@param macro_name string
--@param test_name string
--@return string
local function make_test_name(macro_name, test_fn_name)
  -- polkadot-sdk #[bench] macros tests are named bench_<test_fn_name>
  if macro_name == 'benchmark' then
    return 'bench_' .. test_fn_name
  end

  -- all other supportest tests are named <test_fn_name>
  return test_fn_name
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
  local macro_name = ''

  for id, node, _ in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local capture_name = query.captures[id]

    if #namespace_stack > 0 and is_node_after(node, namespace_stack[#namespace_stack].node) then
      table.remove(namespace_stack)
    end

    if capture_name == 'macro_name' then
      macro_name = vim.treesitter.get_node_text(node, bufnr)
    end

    if capture_name == 'namespace.name' then
      local namespace_name = vim.treesitter.get_node_text(node, bufnr)
      table.insert(namespace_stack, { name = namespace_name, node = node:parent() })
    elseif is_cursor_in_row(node, cursor) then
      if capture_name == 'test.name' then
        local test_fn_name = vim.treesitter.get_node_text(node, bufnr)
        local test_name = make_test_name(macro_name, test_fn_name)
        return make_test_runnable(bufnr, test_name, namespace_stack)
      elseif capture_name == 'main_name' then
        return make_bin_runnable(bufnr)
      end
    end

    if capture_name == 'doc_comment' then
      local doc_comment = vim.treesitter.get_node_text(node, bufnr)
      if doc_comment:find('^/// ```') then
        local next_node = node:next_sibling()
        while next_node:type() == 'line_comment' do
          next_node = next_node:next_sibling()
        end
        if is_cursor_in_row(next_node, cursor) then
          local name = get_identifier(next_node, bufnr)
          local line = node:start() + 1
          return make_doc_test_runnable(bufnr, name, line, namespace_stack)
        end
      end
    end
  end

  return nil
end

return M
