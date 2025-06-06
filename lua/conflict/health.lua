local M = {}

function M.check()
	vim.health.start("conflict")

	if vim.fn.has("nvim-0.11") == 1 then
		vim.health.ok("Neovim version >= 0.11")
	else
		vim.health.error("neovim version < 0.11", "Neovim version 0.11 or later is required")
	end

	local success, err = pcall(require("conflict").validate_config)
	if success then
		vim.health.ok("vim.g.conflict_config = " .. vim.inspect(vim.g.conflict_config --[[@as conflict.Config]]))
	else
		vim.health.error(err --[[@as string]], vim.g.conflict_config)
	end
end

return M
