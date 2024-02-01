# rust-quick-tests

A simple Neovim plugin that mimics the `Hover action` from [rustaceanvim](https://github.com/mrcjkb/rustaceanvim). It let you run Rust tests and main functions by hovering over them using your preferred keybinding.

This plugin uses `Treesitter` for parsing the tests instead of `rust-analyzer`. While less accurate, this approach provides instantaneous responses compared to using `rust-analyzer`, which can be a time saver in large Rust project.

![Screenshot 2024-02-01 at 15 04 51](https://github.com/pgherveou/rust-quick-tests.nvim/assets/521091/fd7f28b3-03f3-40f5-bb08-fdd08dfe76c0)

# Installation

Example using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
return {
  'pgherveou/rust-quick-tests.nvim',
  ft = { 'rust' },
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = true,
  keys = {
    {
      'K',
      function()
        require('rust-quick-tests').hover_actions()
      end,
      desc = 'Rust tests Hover actions',
    },
    {
      '<leader>l',
      function()
        require('rust-quick-tests').replay_last()
      end,
      desc = 'Replay last test',
    },
  },
}
```

# Commands

## RustQuick

Set quick test options.

Usage:

- RustQuick args <args> - Set extra args to pass to cargo run
- RustQuick release - Run tests in release mode
- RustQuick dev - Run tests in dev mode
