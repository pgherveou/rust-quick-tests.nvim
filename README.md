# rust-quick-tests

A simple Neovim plugin that mimics the `Hover action` from [rustaceanvim](https://github.com/mrcjkb/rustaceanvim). It let you run Rust tests by hovering over them using  `K` in normal mode.

This plugin uses `Treesitter` for parsing the tests instead of `rust-analyzer`. While less accurate, this approach provides instantaneous responses compared to using `rust-analyzer`, which can be a time saver in large Rust project.
