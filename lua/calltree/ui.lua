local ct = require('calltree')
local lsp_util = require('calltree.lsp.util')
local ui_buf = require('calltree.ui.buffer')
local ui_win = require('calltree.ui.window')
local help_buf = require('calltree.ui.help_buffer')
local marshal = require('calltree.ui.marshal')
local jumps = require('calltree.ui.jumps')
local deets = require('calltree.ui.details')
local hover = require('calltree.ui.hover')
local tree  = require('calltree.tree.tree')
local handlers = require('calltree.handlers')
local au_hl = require('calltree.ui.auto_highlights')
local notify = require('calltree.ui.notify')

local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

-- ui_state_registry is a registry of vim tabs mapped to calltree's
-- ui state.
--
-- every tab can have its own UI ui_state.
--
-- {
    -- tab# : {
    --     calltree_buf = nil
    --     calltree_handle = nil
    --     calltree_win = nil
    --     calltree_tab = nil
    --     calltree_dir = "empty"
    --     invoking_calltree_win = nil
    --     symboltree_buf = nil
    --     symboltree_handle = nil
    --     symboltree_win = nil
    --     symboltree_tab = nil
    --     invoking_symboltree_win = nil
    --     the active lsp clients which invoked the calltree
    --     active_lsp_clients = nil
    -- }
-- }
M.ui_state_registry = {}

-- obtains the tree type for the given buffer and tab,
--
-- tab : tabpage_handle - the tabpage where the calltree ui
-- buffer exists.
--
-- buf : buffer_handle - the calltree ui buffer to retrieve
-- the type for.
M.get_type_from_buf = function(tab, buf)
    local ui_state = M.ui_state_registry[tab]
    if ui_state == nil then
        return nil
    end
    if buf == ui_state.calltree_buf then
        return "calltree"
    end
    if buf == ui_state.symboltree_buf then
        return "symboltree"
    end
    return nil
end

-- obtains the tree handle for a given buffer and tab.
--
-- tab : tabpage_handle - the tabpage where the calltree ui
-- buffer exists.
--
-- buf : buffer_handle - the calltree ui buffer to retrieve
-- the type for.
M.get_tree_from_buf = function(tab, buf)
    local ui_state = M.ui_state_registry[tab]
    if ui_state == nil then
        return nil
    end
    local type = M.get_type_from_buf(tab, buf)
    if type == "calltree" then
        return ui_state.calltree_handle
    end
    if type == "symboltree" then
        return ui_state.symboltree_handle
    end
end

-- ui_req_ctx creates a context table summarizing the
-- environment when a calltree.nvim request is being
-- made.
--
-- see return type for details.
local function ui_req_ctx()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    local ui_state = M.ui_state_registry[tab]
    return {
        -- the buffer where the calltree method is being invoked
        buf = buf,
        -- the window where the calltree method is being invoked
        win = win,
        -- the tab where the calltree method is being invoked
        tab = tab,
        -- the line where the calltree method is being invoked
        linenr = linenr,
        -- if inside a calltree element, the type of calltree element
        tree_type = tree_type,
        -- if inside a calltree element, the handle to the tree
        tree_handle = tree_handle,
        -- if inside a calltree element, the node at the current line
        node = node,
        -- the current ui state for the given tab
        state = ui_state
    }
end

-- a buffer with help contents that will be swapped into
-- a calltree window when requested.
M.help_buf = nil

-- help opens the help buffer in the current calltree window
-- if it exists.
--
-- open : bool - whether to open or close the help window
-- closing really means, swap the calltree window to the
-- outline buffer.
M.help = function(open)
    local ctx = ui_req_ctx()
    if not open then
        if ctx.state.calltree_win == ctx.win then
            vim.api.nvim_win_set_buf(ctx.win, ctx.state.calltree_buf)
        elseif ctx.state.symboltree_win == ctx.win then
            vim.api.nvim_win_set_buf(ctx.win, ctx.state.symboltree_buf)
        end
        return
    end
    M.help_buf =
        help_buf._setup_help_buffer(M.help_buf)
    vim.api.nvim_win_set_buf(ctx.win, M.help_buf)
end

-- open_to opens the calltree ui, either a single component
-- or the unified panel, and moves the cursor to the requested
-- calltree ui component.
--
-- if open_to is called when nvim is focused inside a calltree ui
-- element the focus will be switched back to the window the ui
-- was invoked from.
--
-- ui : string - the ui component to open and focus, "calltree"
-- or "symboltree"
M.open_to = function(ui)
    local ctx = ui_req_ctx()
    if ui == "calltree" then
        local ui_state = M.ui_state_registry[ctx.tab]
        if ui_state ~= nil then
            if ctx.win == ui_state.calltree_win then
                vim.api.nvim_set_current_win(ui_state.invoking_calltree_win)
                return
            end
            if
                ui_state.calltree_win ~= nil
                and vim.api.nvim_win_is_valid(ui_state.calltree_win)
            then
                vim.api.nvim_set_current_win(ui_state.calltree_win)
                return
            end
        end
        M.toggle_panel(true)
        ui_state = M.ui_state_registry[ctx.tab]
        vim.api.nvim_set_current_win(ui_state.calltree_win)
    elseif ui == "symboltree" then
        local ui_state = M.ui_state_registry[ctx.tab]
        if ui_state ~= nil then
            if ctx.win == ui_state.symboltree_win then
                vim.api.nvim_set_current_win(ui_state.invoking_symboltree_win)
                return
            end
            if
                ui_state.symboltree_win ~= nil
                and vim.api.nvim_win_is_valid(ui_state.symboltree_win)
            then
                vim.api.nvim_set_current_win(ui_state.symboltree_win)
                return
            end
        end
        M.toggle_panel(true)
        ui_state = M.ui_state_registry[ctx.tab]
        vim.api.nvim_set_current_win(ui_state.symboltree_win)
    end
end

-- open_calltree will open a calltree ui in the current tab.
--
-- if a valid tree handle and buffer exists in the tab's calltree
-- state then the tree will be written to the buffer before opening
-- the window.
M._open_calltree = function()
    local ctx = ui_req_ctx()
    -- this allows for empty windows to be opened
    if ctx.state == nil then
        ctx.state = {}
        M.ui_state_registry[ctx.tab] = ctx.state
    end

    local buf_name = "calltree: empty"
    if ctx.state.calltree_dir ~= nil then
        buf_name = direction_map[ctx.state.calltree_dir].buf_name
    end

    ctx.state.calltree_buf =
        ui_buf._setup_buffer(buf_name, ctx.state.calltree_buf, ctx.tab, "calltree")
    if ctx.state.calltree_handle ~= nil then
        tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
    end
    ctx.state.calltree_tab = ctx.tab

    ui_win._open_window("calltree", ctx.state)
end

-- close will close the calltree ui in the current tab
-- and remove the corresponding tree from memory.
--
-- use _smart_close if you simply want to hide a calltree
-- element temporarily (not removing the tree from memory)
M.close_calltree = function()
    local ctx = ui_req_ctx()
    if ctx.state.calltree_win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state.calltree_win) then
            vim.api.nvim_win_close(ctx.state.calltree_win, true)
        end
    end
    ctx.state.calltree_win = nil
    if ctx.state.calltree_handle ~= nil then
        tree.remove_tree(ctx.state.calltree_handle)
        ctx.state.calltree_handle = nil
    end
end

-- _smart_close is a convenience function which closes
-- the calltree ui when the cursor is inside of it.
--
-- useful when mapped to a buffer local key binding
-- to quickly close the window after jumped too.
--
-- this function will not remove any tree from memory
-- and is used to temporarily hide a UI element.
M._smart_close = function()
    local ctx = ui_req_ctx()
    if ctx.tree_type == "calltree" then
        if ctx.state.calltree_win ~= nil then
            if vim.api.nvim_win_is_valid(ctx.state.calltree_win) then
                vim.api.nvim_win_close(ctx.state.calltree_win, true)
            end
        end
        ctx.state.calltree_win = nil
        if vim.api.nvim_win_is_valid(ctx.state.invoking_calltree_win) then
            vim.api.nvim_set_current_win(ctx.state.invoking_calltree_win)
        end
        return
    end
    if ctx.tree_type == "symboltree" then
        if ctx.state.symboltree_win ~= nil then
            if vim.api.nvim_win_is_valid(ctx.state.symboltree_win) then
                vim.api.nvim_win_close(ctx.state.symboltree_win, true)
            end
        end
        ctx.state.symboltree_win = nil
        if vim.api.nvim_win_is_valid(ctx.state.invoking_symboltree_win) then
            vim.api.nvim_set_current_win(ctx.state.invoking_symboltree_win)
        end
        return
    end
end

-- open_symboltree will open a symboltree ui in the current tab.
--
-- if a valid tree handle and buffer exists in the tab's calltree
-- state then the tree will be written to the buffer before opening
-- the window.
M._open_symboltree = function()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        ctx.state = {}
        M.ui_state_registry[ctx.tab] = ctx.state
    end

    ctx.state.symboltree_buf =
        ui_buf._setup_buffer("documentSymbols", ctx.state.symboltree_buf, ctx.tab, "symboltree")
    if ctx.state.symboltree_handle ~= nil then
        tree.write_tree(ctx.state.symboltree_handle, ctx.state.symboltree_buf)
    end
    ctx.state.symboltree_tab = ctx.tab

    ui_win._open_window("symboltree", ctx.state)
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
        ctx.state.symboltree_win ~= nil and
        vim.api.nvim_win_is_valid(ctx.state.symboltree_win)
        and #vim.lsp.get_active_clients() > 0
    then
        vim.lsp.buf.document_symbol()
    end
end

-- close_symboltree will close the symboltree ui in the current tab.
-- and remove the corresponding tree from memory.
--
-- use _smart_close if you simply want to hide a calltree
-- element temporarily (not removing the tree from memory)
M.close_symboltree = function()
    local ctx = ui_req_ctx()
    if ctx.state.symboltree_win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state.symboltree_win) then
            vim.api.nvim_win_close(ctx.state.symboltree_win, true)
        end
    end
    ctx.state.symboltree_win = nil
    if ctx.state.symboltree_handle ~= nil then
        tree.remove_tree(ctx.state.symboltree_handle)
        ctx.state.symboltree_handle = nil
    end
end

-- toggle_panel will open and close the unified panel
-- the unified panel treats all calltree ui elements as
-- a single panel similar to  other IDE's.
--
-- keep_open : bool - if true, and the panel is open,
-- the panel will be left open when this function terminates.
M.toggle_panel = function(keep_open)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end

    if ctx.state.calltree_handle ~= nil then
        local buf_name = "calltree: empty"
        if ctx.state.calltree_dir ~= nil then
            buf_name = direction_map[ctx.state.calltree_dir].buf_name
        end

        ctx.state.calltree_buf =
            ui_buf._setup_buffer(buf_name, ctx.state.calltree_buf, ctx.tab, "calltree")
        if ctx.state.calltree_handle ~= nil then
            tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
        end
        ctx.state.calltree_tab = ctx.tab
    end

    if ctx.state.symboltree_handle ~= nil then
        ctx.state.symboltree_buf =
            ui_buf._setup_buffer("documentSymbols", ctx.state.symboltree_buf, ctx.tab, "symboltree")
        if ctx.state.symboltree_handle ~= nil then
            tree.write_tree(ctx.state.symboltree_handle, ctx.state.symboltree_buf)
        end
        ctx.state.symboltree_tab = ctx.tab
    end

    ui_win._toggle_panel(ctx.state, keep_open)
end

-- collapse will collapse a symbol at the current cursor
-- position
M.collapse = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.node.expanded = false

    if ctx.tree_type == "symboltree" then
        tree.write_tree(ctx.tree_handle, ctx.buf)
        vim.api.nvim_win_set_cursor(ctx.win, ctx.linenr)
        return
    end

    if ctx.tree_type == "calltree" then
        tree.remove_subtree(ctx.tree_handle, ctx.node, true)
        tree.write_tree(ctx.tree_handle, ctx.buf)
        vim.api.nvim_win_set_cursor(ctx.win, ctx.linenr)
    end
end

-- collapse all will collapse the entire tree if
-- any nodes are expanded.
M.collapse_all = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end
    local t = tree.get_tree(ctx.tree_handle)
    tree.collapse_subtree(t.root)
    tree.write_tree(ctx.tree_handle, ctx.buf)
end

-- expand will expand a symbol at the current cursor position
M.expand = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.state  = M.ui_state_registry[ctx.tab]

    if not ctx.node.expanded then
        ctx.node.expanded = true
    end

    if ctx.tree_type == "symboltree" then
        tree.write_tree(ctx.tree_handle, ctx.buf)
        vim.api.nvim_win_set_cursor(ctx.win, ctx.linenr)
        return
    end

    -- calltree nodes are lazily expanded and require an LSP request.
    if ctx.tree_type == "calltree" then
        lsp_util.multi_client_request(
            ctx.state.active_lsp_clients,
            direction_map[ctx.state.calltree_dir].method,
            {item = ctx.node.call_hierarchy_item},
            handlers.calltree_expand_handler(ctx.node, ctx.linenr, ctx.state.calltree_dir, ctx.state),
            ctx.state.calltree_buf
        )
    end
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
--
-- the tree must be of type "calltree"
M.focus = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.state = M.ui_state_registry[ctx.tab]

    -- only valid for calltrees
    if ctx.tree_type ~= "calltree" then
        return
    end

    tree.reparent_node(ctx.state.calltree_handle, 0, ctx.node)
    tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
end

-- switch_direction will focus the symbol under the
-- cursor and then invert the call hierarchy direction.
M.switch_direction = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.state = M.ui_state_registry[ctx.tab]

    if ctx.tree_type ~= "calltree" then
        return
    end

    if ctx.state.calltree_dir == "from" then
        ctx.state.calltree_dir = "to"
    else
        ctx.state.calltree_dir = "from"
    end

    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        direction_map[ctx.state.calltree_dir].method,
        {item = ctx.node.call_hierarchy_item},
        handlers.calltree_switch_handler(ctx.state.calltree_dir, ctx.state),
        ctx.state.calltree_buf
    )
end

-- jump will jump to the source code location of the
-- symbol under the cursor.
M.jump = function(split)
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    local location = lsp_util.resolve_location(ctx.node)
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        jumps.jump_tab(location, ctx.node)
        return
    end

    if split == "split" or split == "vsplit" then
        jumps.jump_split(split, location, ct.config.layout, ctx.node)
        return
    end

    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, ctx.node)
        return
    end

    if ct.config.jump_mode == "invoking" then
        local invoking_win = nil
        if ctx.tree_type == "calltree" then
            invoking_win = ctx.state.invoking_calltree_win
            ctx.state.invoking_calltree_win = jumps.jump_invoking(location, invoking_win, ctx.node)
        elseif ctx.tree_type == "symboltree" then
            invoking_win = ctx.state.invoking_symboltree_win
            ctx.state.invoking_symboltree_win = jumps.jump_invoking(location, invoking_win, ctx.node)
        end
        return
    end
end

-- hover will show LSP hover information for the symbol
-- under the cursor.
M.hover = function()
    ui_buf.close_all_popups()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.state  = M.ui_state_registry[ctx.tab]

    local params = lsp_util.resolve_hover_params(ctx.node)
    if params == nil then
        return
    end
    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        "textDocument/hover",
        params,
        hover.hover_handler,
        ctx.state.calltree_buf
    )
end

-- details opens a popup window for the given symbol
-- showing more information.
M.details = function()
    ui_buf.close_all_popups()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        return
    end

    ctx.state  = M.ui_state_registry[ctx.tab]

    local direction = ""
    if ctx.tree_type == "calltree" then
        direction = ctx.state.calltree_dir
    end
    deets.details_popup(ctx.node, ctx.tree_type, direction)
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

    if ctx.tree_type == "symboltree" then
        au_hl.highlight(ctx.node, set, ctx.state.invoking_symboltree_win)
    end
    if ctx.tree_type == "calltree" then
        au_hl.highlight(ctx.node, set, ctx.state.invoking_calltree_win)
    end
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

    ctx.tree_type = M.get_type_from_buf(ctx.tab, ctx.state.symboltree_buf)
    if
        ctx.tree_type ~= "symboltree" or
        ctx.state.symboltree_win == nil or
        not vim.api.nvim_win_is_valid(ctx.state.symboltree_win)
        or ctx.win == ctx.state.calltree_win
        or ctx.win == ctx.state.symboltree_win
    then
        return
    end

    ctx.tree_handle = ctx.state.symboltree_handle


    -- if there's a direct match for this line, use this
    local cur_file = vim.fn.expand('%:p')

    local source_map = marshal.source_line_map[ctx.tree_handle]
    if source_map == nil then
        return
    end
    local source = source_map[ctx.linenr[1]]
    if source ~= nil and source.uri == cur_file then
            vim.api.nvim_win_set_cursor(ctx.state.symboltree_win, {source.line, 0})
            vim.cmd("redraw!")
            return
    end

    -- no direct match for the line, so search for symbols with a range
    -- interval overlapping our line number.
    local buf_lines = marshal.buf_line_map[ctx.tree_handle]
    if buf_lines == nil then
        return
    end
---@diagnostic disable-next-line: redefined-local
    for line, node in pairs(buf_lines) do
        if ctx.linenr[1] >= node.document_symbol.range["start"].line
            and ctx.linenr[1] <= node.document_symbol.range["end"].line
                and cur_file == lsp_util.resolve_absolute_file_path(node)
        then
            vim.api.nvim_win_set_cursor(ctx.state.symboltree_win, {line, 0})
            vim.cmd("redraw!")
            return
        end
    end
end

M.on_tab_closed = function(tab)
    local ui_state = M.ui_state_registry[tab]
    if ui_state == nil then
        return
    end
    tree.remove_tree(ui_state.calltree_handle)
    tree.remove_tree(ui_state.symboltree_handle)
end

-- dumptree will dump the tree datastructure to a
-- buffer for debugging.
--
-- must be called when the cursor is in the window of
-- the tree being dumped.
M.dump_tree = function()
    local ctx = ui_req_ctx()
    if ctx.tree_handle == nil then
        return
    end
    tree.dump_tree(tree.get_tree(ctx.tree_handle).root)
end

M.dump_node = function()
    local ctx = ui_req_ctx()
    tree.dump_tree(ctx.node)
end

return M
