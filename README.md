# conflict.nvim

Highlight conflict markers, navigate between them and resolve them.
Heavily inspired by [git-conflict.nvim](https://github.com/akinsho/git-conflict.nvim).

## Configuration

To change the confiuration, simply edit the table `vim.g.conflict_config`

## Lua Api
```lua
---Calls `on_conflict` with each conflict within a specified range.
---
---If `from_line > to_line` the range will be traversed in reverse.
---A value of `0` for `bufnr` means the current buffer.
---A value of `-1` for `from_line` or `to_line` means the last line of the buffer. Other negative numbers don't work!
---@param on_conflict fun(conflict: Conflict): boolean Return false to stop iterating
---@param bufnr integer The buffer to check conflicts
---@param from_line integer 1-based, inclusive
---@param to_line integer 1-based, inclusive
require("conflict").iterate_conflicts(on_conflict, bufnr, from_line, to_line)

---@param winid? integer Current window by default
---@param backwards? boolean False by default
---@param wrap? boolean False by default
require("conflict").jump_to_next_conflict(winid, backwards, wrap)

---@param winid? integer Current window by default
---@param linenr? integer Cursor position by default
---@param keep Conflict.Side The side of the conflict to keep
require("conflict").resolve_conflict_at(winid, linenr, keep)
```
