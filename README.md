# rust-quick-tests

A simple Neovim plugin that mimics the `Hover action` from [rustaceanvim](https://github.com/mrcjkb/rustaceanvim). It let you run Rust tests and main functions by hovering over them using your preferred keybinding.

This plugin uses `Treesitter` for parsing the tests instead of `rust-analyzer`. While less accurate, this approach provides instantaneous responses compared to using `rust-analyzer`, which can be a time saver in large Rust project.

# Installation

Example using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
return {
  'pgherveou/rust-quick-tests.nvim',
  ft = { 'rust' },
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
