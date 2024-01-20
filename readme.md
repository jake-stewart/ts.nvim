ts.nvim
=======

configure neovim using typescript, thanks to [tstl](https://typescripttolua.github.io/).

#### features
* automatically compiles when config updates
* works alongside existing lua config
* works with all lua plugins
* strong lua interop
    - `lua.require`
    - `lua.string`
    - `lua.table`
    - `lua.io`
    - `lua.os`
    - `lua.math`
    - `lua.pcall`
* many type definitions & lsp documentation
    - `vim.fn`
    - `vim.cmd`
    - `vim.api`
    - `vim.keymap`
    - `vim.o`, `vim.bo`, `vim.wo`, `vim.go`
    - `vim.opt`
    - `vim.ui`
    - `vim.version`
    - `vim.json`
    - `vim.loop`
    - `vim.spell`
    - `vim.mpack`
    - `vim.fs`
    - `vim.highlight`

#### dependencies
- npm

### setup
set this as your `init.lua` and then start neovim.
it will automatically generate a template typescript project,
and install required packages with npm.

```lua
local tsnvim_path = vim.fn.stdpath("data") .. "/ts.nvim"
if not vim.loop.fs_stat(tsnvim_path) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/jake-stewart/ts.nvim.git",
        "--branch=stable",
        tsnvim_path,
    })
end
vim.opt.rtp:prepend(tsnvim_path)
require("tsnvim").setup()
```

### example config
use [my config](https://github.com/jake-stewart/dotfiles/tree/main/.config/nvim/typescript) as reference

### notes
1. boolean coercion works like lua, so `0` is `true`.
2. tstl uses type annotations for lua code generation:
```typescript
// without the any[], tstl wouldn't know if `forEach` was a table field or method call:
lua.require("foo").setup((table: any[]) => {
    table.forEach(...);
})
```

### why?
lua indexes from 1. typescript does not
