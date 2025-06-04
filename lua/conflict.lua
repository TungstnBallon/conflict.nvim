local M = {}

------- CONFIG -------

---@class conflict.Config
local default_config = {
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

---@type conflict.Config
vim.g.conflict_config = vim.tbl_deep_extend("force", default_config, vim.g.conflict_config or {})

function M.validate_config()
	local config = vim.g.conflict_config
	vim.validate("vim.g.conflict_config", config, "table")
	vim.validate("vim.g.conflict_config.markers", config.markers, "table")
	if config.markers then
		vim.validate("vim.g.conflict_config.markers.current", config.markers.current, "string")
		vim.validate("vim.g.conflict_config.markers.base", config.markers.base, "string")
		vim.validate("vim.g.conflict_config.markers.delimiter", config.markers.delimiter, "string")
		vim.validate("vim.g.conflict_config.markers.incoming", config.markers.incoming, "string")
	end
	vim.validate("vim.g.conflict_config.highlights", config.highlights, "table")
	if config.markers then
		vim.validate("vim.g.conflict_config.highlights.enabled", config.highlights.enabled, { "boolean", "function" })
		vim.validate("vim.g.conflict_config.highlights.current", config.highlights.current, "string")
		vim.validate("vim.g.conflict_config.highlights.base", config.highlights.base, "string")
		vim.validate("vim.g.conflict_config.highlights.delimiter", config.highlights.delimiter, "string")
		vim.validate("vim.g.conflict_config.highlights.incoming", config.highlights.incoming, "string")
	end
end

------- PARSING -------

---@alias conflict.Marker "current" | "base" | "delimiter" | "incoming"

---@class (exact) conflict.Conflict 1-based indexing
---@field current integer
---@field base? integer
---@field delimiter integer
---@field incoming integer

---@param line string
---@return conflict.Marker? marker
local function check_line_for_marker(line)
	local markers = vim.g.conflict_config.markers
	return (line:find(markers.current) and "current")
		or (line:find(markers.base) and "base")
		or (line:find(markers.delimiter) and "delimiter")
		or (line:find(markers.incoming) and "incoming")
end

---@param lines string[]
---@param start_line integer 1-based
---@param backwards? boolean
---@return integer? linenr 1-based
---@return conflict.Marker? marker
local function find_marker(lines, start_line, backwards)
	local limit = backwards and 1 or #lines
	local step = backwards and -1 or 1
	for linenr = start_line, limit, step do
		local marker = check_line_for_marker(assert(lines[linenr]))
		if marker then
			return linenr, marker
		end
	end
end

---@param lines string[]
---@param start_linenr integer 1-based
---@return string? error
---@return conflict.Conflict? conflict
local function find_conflict_if_on_marker(lines, start_linenr)
	local line = lines[start_linenr]
		or error(("Tried to get line %d, but only has lines 1..=%d"):format(start_linenr, #lines))
	local mark = check_line_for_marker(line)
	if mark == "current" then
		local current = start_linenr
		local linenr, marker = find_marker(lines, current + 1)
		if not linenr then
			return ("%d current: no marker"):format(current), nil
		end
		local base, delimiter
		if marker == "delimiter" then
			delimiter = linenr
		elseif marker == "base" then
			base = linenr
			linenr, marker = find_marker(lines, base + 1)
			if not linenr or marker ~= "delimiter" then
				return ("%d current: %d base: no delimiter | %d %s"):format(
					current,
					base,
					linenr or -1,
					marker or "no marker"
				),
					nil
			end
			delimiter = linenr
		else
			return ("%d current: no delimiter or base | %d %s"):format(current, linenr or -1, marker or "no marker"),
				nil
		end
		linenr, marker = find_marker(lines, linenr + 1)
		if not linenr or marker ~= "incoming" then
			return ("%d current: no incoming | %d %s"):format(current, linenr or -1, marker or "no marker"), nil
		end
		local incoming = linenr
		---@type conflict.Conflict
		local conflict = {
			current = current,
			base = base,
			delimiter = delimiter,
			incoming = incoming,
		}
		return nil, conflict
	elseif mark == "base" then
		local base = start_linenr
		local linenr, marker = find_marker(lines, base - 1, true)
		if not linenr or marker ~= "current" then
			return ("%d base: no current | %d %s"):format(base, linenr or -1, marker or "no marker"), nil
		end
		local current = linenr
		linenr, marker = find_marker(lines, base + 1)
		if not linenr or marker ~= "delimiter" then
			return ("%d base: no delimiter | %d %s"):format(base, linenr or -1, marker or "no marker"), nil
		end
		local delimiter = linenr
		linenr, marker = find_marker(lines, delimiter + 1)
		if not linenr or marker ~= "incoming" then
			return ("%d base: no incoming | %d %s"):format(base, linenr or -1, marker or "no marker"), nil
		end
		local incoming = linenr
		---@type conflict.Conflict
		local conflict = {
			current = current,
			base = base,
			delimiter = delimiter,
			incoming = incoming,
		}
		return nil, conflict
	elseif mark == "delimiter" then
		local delimiter = start_linenr
		local linenr, marker = find_marker(lines, delimiter - 1, true)
		if not linenr then
			return ("%d delimiter: no marker"):format(delimiter), nil
		end
		local current, base
		if marker == "current" then
			current = linenr
		elseif marker == "base" then
			base = linenr
			linenr, marker = find_marker(lines, base - 1, true)
			if not linenr or marker ~= "current" then
				return ("%d delimiter: %d base: no current | %d %s"):format(
					delimiter,
					base,
					linenr or -1,
					marker or "no marker"
				),
					nil
			end
			current = linenr
		else
			return ("%d delimiter: no current or base | %d %s"):format(delimiter, linenr or -1, marker or "no marker"),
				nil
		end
		linenr, marker = find_marker(lines, delimiter + 1)
		if not linenr or marker ~= "incoming" then
			return ("%d delimiter: no incoming | %d %s"):format(delimiter, linenr or -1, marker or "no marker"), nil
		end
		local incoming = linenr
		---@type conflict.Conflict
		local conflict = {
			current = current,
			base = base,
			delimiter = delimiter,
			incoming = incoming,
		}
		return nil, conflict
	elseif mark == "incoming" then
		local incoming = start_linenr
		local linenr, marker = find_marker(lines, incoming - 1, true)
		if not linenr or marker ~= "delimiter" then
			return ("%d incoming: no delimiter | %d %s"):format(incoming, linenr or -1, marker or "no marker"), nil
		end
		local delimiter = linenr
		linenr, marker = find_marker(lines, delimiter - 1, true)
		if not linenr then
			return ("%d incoming: no marker"):format(incoming), nil
		end
		local current, base
		if marker == "current" then
			current = linenr
		elseif marker == "base" then
			base = linenr
			linenr, marker = find_marker(lines, base - 1, true)
			if not linenr or marker ~= "current" then
				return ("%d incoming: %d delimiter: %d base: no current | %d %s"):format(
					incoming,
					delimiter,
					base,
					linenr,
					marker
				),
					nil
			end
			current = linenr
		else
			return ("%d incoming: %d delimiter: no base or current | %d %s"):format(
				incoming,
				delimiter,
				linenr or -1,
				marker or "no marker"
			),
				nil
		end
		---@type conflict.Conflict
		local conflict = {
			current = current,
			base = base,
			delimiter = delimiter,
			incoming = incoming,
		}
		return nil, conflict
	else
		return nil, nil
	end
end

---@param lines string[]
---@param from_line integer 1-based, inclusive
---@param to_line integer 1-based, inclusive
---@param step integer
---@return boolean error
---@return conflict.Conflict? conflict
local function find_next_conflict(lines, from_line, to_line, step)
	for linenr = from_line, to_line, step do
		local err, conflict = find_conflict_if_on_marker(lines, linenr)
		if not err and conflict then
			return false, conflict
		elseif err then
			return true
		end
	end
	return false
end

------- ITERATING -------

---Calls `on_conflict` with each conflict within a specified range.
---
---If `from_line > to_line` the range will be traversed in reverse.
---@param on_conflict fun(conflict: conflict.Conflict): boolean Return false to stop iterating
---@param bufnr? integer The buffer to check conflicts, current buffer by default
---@param from_line? integer 1-based, inclusive, 1 by default, supports negative indexing (-1 is the last line)
---@param to_line? integer 1-based, inclusive, -1 by default, supports negative indexing (-1 is the last line)
function M.iterate_conflicts(on_conflict, bufnr, from_line, to_line)
	vim.validate("on_conflict", on_conflict, "function")
	vim.validate("bufnr", bufnr, "number", true)
	vim.validate("from_line", from_line, "number", true)
	vim.validate("from_line", to_line, "number", true)

	local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, true)
	from_line = from_line and from_line < 0 and #lines + 1 + from_line or from_line or 1
	to_line = to_line and to_line < 0 and #lines + 1 + to_line or to_line or #lines

	local forwards = from_line < to_line
	local step = forwards and 1 or -1
	while (not forwards or (from_line <= to_line)) and (forwards or (from_line >= to_line)) do
		local error, conflict = find_next_conflict(lines, from_line, to_line, step)
		if error then
			return
		end
		if conflict then
			if not on_conflict(conflict) then
				return
			end
			from_line = forwards and conflict.incoming or conflict.current
		end
		from_line = from_line + step
	end
end

------- JUMPING -------

---Jump to the next conflict
---If the |wrapscan| option is set, the search will wrap around the end of the
---buffer.
---
---@param winid? integer Current window by default
---@param backwards? boolean False by default
function M.jump_to_next_conflict(winid, backwards)
	vim.validate("winid", winid, "number", true)
	vim.validate("backwards", backwards, "boolean", true)
	local cursor_line = vim.api.nvim_win_get_cursor(winid or 0)[1]
	local bufnr = vim.api.nvim_win_get_buf(winid or 0)

	local jump_line
	M.iterate_conflicts(function(conflict)
		jump_line = conflict.delimiter
		return false
	end, bufnr, cursor_line, backwards and 1 or -1)
	if not jump_line and vim.o.wrapscan then
		M.iterate_conflicts(function(conflict)
			jump_line = conflict.delimiter
			return false
		end, bufnr, backwards and -1 or 1, cursor_line)
	end

	if not jump_line then
		vim.notify("No conflict found")
	else
		vim.api.nvim_win_set_cursor(winid or 0, { jump_line, 0 })
	end
end

------- RESOLVING -------

---@alias conflict.Side "current" | "base" | "incoming" | "none" | "both"

---@param bufnr integer
---@param conflict conflict.Conflict
---@param side conflict.Side
---@return string[]
local function get_side_lines(bufnr, conflict, side)
	if side == "current" then
		return vim.api.nvim_buf_get_lines(bufnr, conflict.current, (conflict.base or conflict.delimiter) - 1, true)
	elseif side == "base" then
		if conflict.base then
			return vim.api.nvim_buf_get_lines(bufnr, conflict.base, conflict.delimiter - 1, true)
		else
			vim.notify("not a 3-way conflict")
			return vim.api.nvim_buf_get_lines(bufnr, conflict.current, conflict.incoming - 1, true)
		end
	elseif side == "incoming" then
		return vim.api.nvim_buf_get_lines(bufnr, conflict.delimiter, conflict.incoming - 1, true)
	elseif side == "none" then
		return {}
	elseif side == "both" then
		local lines =
			vim.api.nvim_buf_get_lines(bufnr, conflict.current, (conflict.base or conflict.delimiter) - 1, true)
		return vim.list_extend(
			lines,
			vim.api.nvim_buf_get_lines(bufnr, conflict.delimiter, conflict.incoming - 1, true)
		)
	else
		error("unreachable")
	end
end

---@param bufnr integer
---@param conflict conflict.Conflict
---@param side conflict.Side
local function resolve_conflict_with(bufnr, conflict, side)
	vim.api.nvim_buf_set_lines(
		bufnr,
		conflict.current - 1,
		conflict.incoming,
		true,
		get_side_lines(bufnr, conflict, side)
	)
end

---@param winid? integer Current window by default
---@param linenr? integer Cursor position by default
---@param keep conflict.Side The side of the conflict to keep
function M.resolve_conflict_at(winid, linenr, keep)
	vim.validate(
		"side",
		keep,
		---@param v conflict.Side
		function(v)
			return v == "current" or v == "base" or v == "incoming" or v == "none" or v == "both"
		end,
		"Must be a side of the conflict"
	)
	vim.validate("winid", winid, "number", true)
	vim.validate("linenr", linenr, "number", true)

	winid = winid or 0
	linenr = linenr or vim.api.nvim_win_get_cursor(winid)[1]
	local bufnr = vim.api.nvim_win_get_buf(winid)

	M.iterate_conflicts(function(conflict)
		if conflict.current <= linenr and linenr <= conflict.incoming then
			resolve_conflict_with(bufnr, conflict, keep)
		end
		return false
	end, bufnr, linenr)
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
		priority = vim.hl.priorities.diagnostics - 1,
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

function M._enable_highlights()
	local highlights = vim.g.conflict_config.highlights

	vim.api.nvim_set_hl(0, CURRENT_HEADER_HL, { link = highlights.current, default = true })
	vim.api.nvim_set_hl(0, CURRENT_HL, { link = highlights.current, default = true })
	vim.api.nvim_set_hl(0, BASE_HEADER_HL, { link = highlights.base, default = true })
	vim.api.nvim_set_hl(0, BASE_HL, { link = highlights.base, default = true })
	vim.api.nvim_set_hl(0, DELIMITER_HL, { link = highlights.delimiter, default = true })
	vim.api.nvim_set_hl(0, INCOMING_HL, { link = highlights.incoming, default = true })
	vim.api.nvim_set_hl(0, INCOMING_TAIL_HL, { link = highlights.incoming, default = true })

	vim.api.nvim_set_decoration_provider(NAMESPACE, {
		on_win = function(_, _, buf, toprow, botrow)
			if
				type(vim.g.conflict_config.highlights.enabled) == "boolean"
					and not vim.g.conflict_config.highlights.enabled
				or not vim.g.conflict_config.highlights.enabled(buf)
			then
				return false
			end

			M.iterate_conflicts(function(conflict)
				hl_conflict(buf, conflict, true)
				return true
			end, buf, toprow + 1, botrow + 1)
		end,
	})
end

return M
