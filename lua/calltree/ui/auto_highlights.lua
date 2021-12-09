local lsp_util = require('calltree.lsp.util')
local ct = require('calltree')

local M = {}

-- the current highlight used for auto-highlighting
M.higlight_ns = vim.api.nvim_create_namespace("calltree-hl")

-- higlight will set a highlight in the source code window when the symbol
-- is hovered in a calltree window.
--
-- node : tree.tree.Node - the currently selected node in the symbol tree
-- set : bool - whether to remove the highlight and immediately return
-- invoking_win : the window which invoked the calltree or symboltree
function M.highlight(node, set, invoking_win)
    if not vim.api.nvim_win_is_valid(invoking_win) then
        return
    end
    local buf = vim.api.nvim_win_get_buf(invoking_win)
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

    local location = lsp_util.resolve_location(node)
    if location == nil then
        return
    end
    local range = location.range

    if range["end"] == nil then
        return
    end

    -- make sure URIs match before setting highlight
    local invoking_buf = vim.api.nvim_win_get_buf(invoking_win)
    local cur_file = vim.api.nvim_buf_get_name(invoking_buf)
    local symbol_path = lsp_util.resolve_absolute_file_path(node)
    if cur_file ~= symbol_path then
        return
    end

    vim.api.nvim_buf_add_highlight(
        buf,
        M.higlight_ns,
        ct.hls.SymbolJumpHL,
        range["start"].line,
        range["start"].character,
        range["end"].character
    )
    vim.api.nvim_win_set_cursor(invoking_win, {range["start"].line+1, 0})
end

return M
