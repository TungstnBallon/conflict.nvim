------- COLORS -------

local rshift, band = require("bit").rshift, require("bit").band

--- Returns a table containing the RGB values encoded inside 24 least
--- significant bits of the number @rgb_24bit
---@param rgb_24bit number 24-bit RGB value
---@return {r: integer, g: integer, b: integer}
local function decode_24bit_rgb(rgb_24bit)
	vim.validate("rgb_24bit", rgb_24bit, "number", true)
	local r = band(rshift(rgb_24bit, 16), 255)
	local g = band(rshift(rgb_24bit, 8), 255)
	local b = band(rgb_24bit, 255)
	return { r = r, g = g, b = b }
end

local function alter(attr, percent)
	return math.floor(attr * (100 + percent) / 100)
end

---Darken a specified hex color
---@param color integer
---@param percent number
---@return string
local function shade_color(color, percent)
	local rgb = decode_24bit_rgb(color)
	local r, g, b = alter(rgb.r, percent), alter(rgb.g, percent), alter(rgb.b, percent)
	r, g, b = math.min(r, 255), math.min(g, 255), math.min(b, 255)
	return string.format("#%02x%02x%02x", r, g, b)
end

------- CONFIG -------

local success, err = pcall(require("conflict").validate_config)
if not success then
	vim.notify(err --[[@as string]], vim.log.levels.ERROR)
	return
end

------- HIGHLIGHTS -------

local CURRENT_HL = "ConflictCurrent"
local BASE_HL = "ConflictBase"
local INCOMING_HL = "ConflictIncoming"
local CURRENT_HEADER_HL = "ConflictCurrentHeader"
local BASE_HEADER_HL = "ConflictBaseHeader"
local DELIMITER_HL = "ConflictDelimiter"
local INCOMING_TAIL_HL = "ConflictIncomingTail"
local NAMESPACE = vim.api.nvim_create_namespace("conflict")

local highlights = vim.g.conflict_config.highlights

local function reset_hl()
	local current_bg = assert(vim.api.nvim_get_hl(0, { name = highlights.current }).bg)
	local base_bg = assert(vim.api.nvim_get_hl(0, { name = highlights.base }).bg)
	local delimiter_bg = assert(vim.api.nvim_get_hl(0, { name = highlights.delimiter }).bg)
	local incoming_bg = assert(vim.api.nvim_get_hl(0, { name = highlights.incoming }).bg)

	local current_header_bg = shade_color(current_bg, 60)
	local base_header_bg = shade_color(base_bg, 60)
	local delimiter_bg_darker = shade_color(delimiter_bg, 60)
	local incoming_tail_bg = shade_color(incoming_bg, 60)

	vim.api.nvim_set_hl(0, CURRENT_HEADER_HL, { bg = current_header_bg, default = true })
	vim.api.nvim_set_hl(0, BASE_HEADER_HL, { bg = base_header_bg, default = true })
	vim.api.nvim_set_hl(0, DELIMITER_HL, { bg = delimiter_bg_darker, default = true })
	vim.api.nvim_set_hl(0, INCOMING_TAIL_HL, { bg = incoming_tail_bg, default = true })
end

vim.api.nvim_set_hl(0, CURRENT_HL, { link = highlights.current, default = true })
vim.api.nvim_set_hl(0, BASE_HL, { link = highlights.base, default = true })
vim.api.nvim_set_hl(0, INCOMING_HL, { link = highlights.incoming, default = true })
reset_hl()

vim.api.nvim_create_autocmd("ColorScheme", {
	desc = "Reset hl groups after colorscheme change",
	group = vim.api.nvim_create_augroup("conflict-set-colors", { clear = true }),
	callback = reset_hl,
})

---@param bufnr? integer
---@param hl_group string
---@param start_line integer 1-indexed, inclusive
---@param end_line integer 1-indexed, inclusive
---@param ephemeral? boolean
---@return integer markid
local function hl_range(bufnr, hl_group, start_line, end_line, ephemeral)
	return vim.api.nvim_buf_set_extmark(bufnr or 0, NAMESPACE, start_line - 1, 0, {
		ephemeral = ephemeral,
		hl_group = hl_group,
		hl_eol = true,
		hl_mode = "combine",
		end_row = end_line,
		end_col = 0,
		priority = vim.hl.priorities.user,
	})
end

---@param bufnr? integer
---@param conflict conflict.Conflict
---@param ephemeral? boolean
local function hl_conflict(bufnr, conflict, ephemeral)
	hl_range(bufnr, CURRENT_HEADER_HL, conflict.current, conflict.current, ephemeral)
	hl_range(bufnr, CURRENT_HL, conflict.current + 1, conflict.base or conflict.delimiter, ephemeral)

	if conflict.base then
		hl_range(bufnr, BASE_HEADER_HL, conflict.base, conflict.base, ephemeral)
		hl_range(bufnr, BASE_HL, conflict.base + 1, conflict.delimiter, ephemeral)
	end

	hl_range(bufnr, DELIMITER_HL, conflict.delimiter, conflict.delimiter, ephemeral)

	hl_range(bufnr, INCOMING_HL, conflict.delimiter + 1, conflict.incoming, ephemeral)
	hl_range(bufnr, INCOMING_TAIL_HL, conflict.incoming, conflict.incoming, ephemeral)
end

vim.api.nvim_set_decoration_provider(NAMESPACE, {
	on_win = function(_, _, bufnr, toprow, botrow)
		if
			type(vim.g.conflict_config.highlights.enabled) == "boolean"
				and not vim.g.conflict_config.highlights.enabled
			or not vim.g.conflict_config.highlights.enabled(bufnr)
		then
			return false
		end

		require("conflict").iterate_conflicts(function(conflict)
			hl_conflict(bufnr, conflict, true)
			return true
		end, bufnr, toprow + 1, botrow + 1)
	end,
})
