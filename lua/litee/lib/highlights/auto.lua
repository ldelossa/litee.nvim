local lib_util  = require('litee.lib.util')
local lib_hi    = require('litee.lib.highlights')

local M = {}

-- the current highlight used for auto-highlighting
M.higlight_ns = vim.api.nvim_create_namespace("calltree-hl")

-- highlight will set a highlight on the source code
-- lines the provided node represents if the invoking_win
-- holds a buffer to said file.
--
-- @param node (table) The element representing a source
-- code symbol or element. This function requires the node
-- to have a top level ".location" field.
-- @param set (bool) If false any highlights which were
-- previously set are cleared. If true, highlights will
-- be created.
-- @param win (int) A window handle to the window
-- being evaluated for highlighting.
function M.highlight(node, set, win)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(
        buf,
        M.higlight_ns,
        0,
        -1
    )
    if not set then
        return
    end

    local location = node.location
    if location == nil then
        return
    end
    local range = location.range

    if range["end"] == nil then
        return
    end

    -- make sure URIs match before setting highlight
    local invoking_buf = vim.api.nvim_win_get_buf(win)
    local cur_file = vim.api.nvim_buf_get_name(invoking_buf)
    local symbol_path = lib_util.absolute_path_from_uri(location.uri)
    if cur_file ~= symbol_path then
        return
    end

    vim.api.nvim_buf_add_highlight(
        buf,
        M.higlight_ns,
        lib_hi.hls.SymbolJumpHL,
        range["start"].line,
        range["start"].character,
        range["end"].character
    )
    vim.api.nvim_win_set_cursor(win, {range["start"].line+1, 0})
end

return M
