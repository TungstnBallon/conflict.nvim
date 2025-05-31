local M = {}

function M.check()
	vim.health.start("conflict")

	if vim.fn.has("nvim-0.11") == 1 then
		vim.health.ok("Neovim version >= 0.11")
	else
		vim.health.error("neovim version < 0.11", "Neovim version 0.11 or later is required")
	end

	if vim.g.conflict_config then
		local success, err = pcall(require("conflict").validate_config, vim.g.conflict_config)
		if success then
			vim.health.ok("Valid configuration")
		else
			vim.health.error(err --[[@as string]])
		end
	else
		vim.health.ok("Valid configuration")
	end
end

return M
