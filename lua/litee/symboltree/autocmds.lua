local lib_tree      = require('litee.lib.tree')
local lib_state     = require('litee.lib.state')
local lib_autohi    = require('litee.lib.highlights.auto')
local lib_util      = require('litee.lib.util')
local lib_util_win  = require('litee.lib.util.window')

local M = {}

-- ui_req_ctx creates a context table summarizing the
-- environment when a symboltree request is being
-- made.
--
-- see return type for details.
local function ui_req_ctx()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = lib_state.get_type_from_buf(tab, buf)
    local tree_handle = lib_state.get_tree_from_buf(tab, buf)
    local state       = lib_state.get_state(tab)

    local cursor = nil
    local node = nil
    if state ~= nil  and state["symboltree"] ~= nil then
        if state["symboltree"] ~= nil and state["symboltree"].win ~= nil and
            vim.api.nvim_win_is_valid(state["symboltree"].win) then
            cursor = vim.api.nvim_win_get_cursor(state["symboltree"].win)
            node = lib_tree.marshal_line(cursor, state["symboltree"].tree)
        end
    end

    return {
        -- the current buffer when the request is made
        buf = buf,
        -- the current win when the request is made
        win = win,
        -- the current tab when the request is made
        tab = tab,
        -- the current cursor pos when the request is made
        linenr = linenr,
        -- the type of tree if request is made in a lib_panel
        -- window.
        tree_type = tree_type,
        -- a hande to the tree if the request is made in a lib_panel
        -- window.
        tree_handle = tree_handle,
        -- the pos of the symboltree cursor if a valid caltree exists.
        cursor = cursor,
        -- the current state provided by lib_state
        state = state,
        -- the current marshalled node if there's a valid symboltree
        -- window present.
        node = node
    }
end

-- refresh_symbol_tree is used as an autocommand and
-- keeps the symboltree outline live while moving around
-- buffers in a given tab.
--
-- autocommand is set in the calltree.lua module.
M.refresh_symbol_tree = function()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if
        ctx.state["symboltree"] == nil or
        ctx.state["symboltree"].win == nil or
        not vim.api.nvim_win_is_valid(ctx.state["symboltree"].win)
        or lib_util_win.inside_component_win()
        or #vim.lsp.get_active_clients() == 0
    then
        return
    end
    vim.lsp.buf.document_symbol()
end

-- auto_highlight will automatically highlight
-- symbols in the source code files when the symbol
-- is selected in the symboltree.
--
-- if set is false it will remove any highlights
-- in the source code's buffer.
--
-- this method is intended for use as an autocommand.
--
-- set : bool - whether to remove or set highlights
-- for the symbol under the cursor in a symboltree.
M.auto_highlight = function(set)
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end
    lib_autohi.highlight(ctx.node, set, ctx.state["symboltree"].invoking_win)
end

-- source_tracking is a method for keeping the cursor position
-- and relevant highlighting within a source code file in sync
-- with the cursor position and relevant highlighting within the
-- symboltree, or vice versa.
--
-- this method is intended for use as an autocommand.
M.source_tracking = function ()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end

    if
        ctx.state["symboltree"] == nil or
        ctx.state["symboltree"].win == nil or
        not vim.api.nvim_win_is_valid(ctx.state["symboltree"].win)
        or lib_util_win.inside_component_win()
    then
        return
    end

    -- if there's a direct match for this line, use this
    local cur_file = vim.fn.expand('%:p')
    local t = lib_tree.get_tree(ctx.state["symboltree"].tree)

    local source_map = t.source_line_map
    if source_map == nil then
        return
    end
    local source = source_map[ctx.linenr[1]]
    if source ~= nil and source.uri == cur_file then
            vim.api.nvim_win_set_cursor(ctx.state["symboltree"].win, {source.line, 0})
            vim.cmd("redraw!")
            return
    end

    -- no direct match for the line, so search for symbols with a range
    -- interval overlapping our line number.
    --
    -- we search in reverse since code is written top down, allows
    -- for source_tracking to handle nested elements correctly.
    local buf_lines = t.buf_line_map
    if buf_lines == nil then
        return
    end
---@diagnostic disable-next-line: redefined-local
    for i=#buf_lines,1,-1 do
        local node = buf_lines[i]
        if (ctx.linenr[1] - 1) >= node.document_symbol.range["start"].line
            and (ctx.linenr[1] - 1) <= node.document_symbol.range["end"].line
                and cur_file == lib_util.resolve_absolute_file_path(node)
        then
            vim.api.nvim_win_set_cursor(ctx.state["symboltree"].win, {i, 0})
            vim.cmd("redraw!")
            return
        end
    end
end


return M
