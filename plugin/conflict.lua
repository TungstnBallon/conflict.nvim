require("conflict")._enable_highlights()

vim.keymap.set("n", "<Plug>ConflictJumpToNext", function()
	require("conflict").jump_to_next_conflict()
end)
vim.keymap.set("n", "<Plug>ConflictJumpToPrevious", function()
	require("conflict").jump_to_next_conflict(nil, true)
end)

vim.keymap.set("n", "<Plug>ConflictResolveAroundCursor", function()
	vim.ui.select({ "current", "base", "incoming", "none", "both" }, {
		prompt = "Select a variant to keep",
		format_item = function(item)
			return "Keep " .. item
		end,
	}, function(item)
		if item then
			require("conflict").resolve_conflict_at(nil, nil, item)
		end
	end)
end)
