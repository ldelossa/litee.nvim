local lsp_util = require('calltree.lsp.util')
local ct = require('calltree')

local M = {}

-- the current highlight used for auto-highlighting
M.higlight_ns = vim.api.nvim_create_namespace("calltree-hl")

-- highlight is used specifically with the symboltree UI.
-- sets a highlight for the provided symboltree node and sets
-- the cursor to the start of the symbol.
--
-- this function always targets the "invoking_symboltree_win" in the ui
-- state. this is because the symboltree UI always follows the last focused
-- source code window in vim.
--
-- node : tree.tree.Node - the currently selected node in the symbol tree
-- set : bool - whether to remove the highlight and immediately return
-- ui_state : table - the current calltree ui_state provided by the ui
-- module.
function M.highlight(node, set, ui_state)
    local buf = vim.api.nvim_win_get_buf(ui_state.invoking_symboltree_win)
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

    vim.api.nvim_buf_add_highlight(
        buf,
        M.higlight_ns,
        ct.hls.SymbolJumpHL,
        range["start"].line,
        range["start"].character,
        range["end"].character
    )
    vim.api.nvim_win_set_cursor(ui_state.invoking_symboltree_win, {range["start"].line+1, 0})
end

return M
