# conflict.nvim

Highlight, navigate and resolve conflict markers.
Heavily inspired by [git-conflict.nvim](https://github.com/akinsho/git-conflict.nvim).

![A screenshot of a neovim window with highlighted conflict markers](screenshot.png?raw=true "Highlighted conflicts")

## Setup

No setup needed!

## Provided mappings

You can use these as the third parameter for `vim.keymap.set()`
- `<Plug>ConflictJumpToNext`
- `<Plug>ConflictJumpToPrevious`
- `<Plug>ConflictResolveAroundCursor`

## Configuration

To change the confiuration, simply edit the table `vim.g.conflict_config`
```lua
-- Default configuration
{
	markers = {
		---@type string
		current = "^<<<<<<<%s.*$",
		---@type string
		base = "^|||||||%s.*$",
		---@type string
		delimiter = "^=======$",
		---@type string
		incoming = "^>>>>>>>%s.*$",
	},
	highlights = {
		---@type boolean | fun(bufnr: integer): boolean
		enabled = function(bufnr)
			return vim.bo[bufnr].buftype == ""
		end,
		---@type string
		current = "DiffText",
		---@type string
		base = "DiffChange",
		---@type string
		delimiter = "Normal",
		---@type string
		incoming = "DiffAdd",
	},
}
```

## Lua API
```lua
---Calls `on_conflict` with each conflict within a specified range.
---
---If `from_line > to_line` the range will be traversed in reverse.
---@param on_conflict fun(conflict: conflict.Conflict): boolean Return false to stop iterating
---@param bufnr? integer The buffer to check conflicts, current buffer by default
---@param from_line? integer 1-based, inclusive, 1 by default, supports negative indexing (-1 is the last line)
---@param to_line? integer 1-based, inclusive, -1 by default, supports negative indexing (-1 is the last line)
require("conflict").iterate_conflicts(on_conflict, bufnr, from_line, to_line)

---Jump to the next conflict
---If the |wrapscan| option is set, the search will wrap around the end of the
---buffer.
---
---@param winid? integer Current window by default
---@param backwards? boolean False by default
require("conflict").jump_to_next_conflict(winid, backwards)

---@param winid? integer Current window by default
---@param linenr? integer Cursor position by default
---@param keep Conflict.Side The side of the conflict to keep
require("conflict").resolve_conflict_at(winid, linenr, keep)
```

