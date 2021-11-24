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

local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

-- ui_state_registry is a registry of vim tabs mapped to calltree's
-- ui ui_state.
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
    local type = M.get_type_from_buf(tab, buf)
    if type == "calltree" then
        return ui_state.calltree_handle
    end
    if type == "symboltree" then
        return ui_state.symboltree_handle
    end
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
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    if ui_state == nil then
        return
    end
    if not open then
        if ui_state.calltree_win == win then
            vim.api.nvim_win_set_buf(win, ui_state.calltree_buf)
        elseif ui_state.symboltree_win == win then
            vim.api.nvim_win_set_buf(win, ui_state.symboltree_buf)
        end
        return
    end
    M.help_buf =
        help_buf._setup_help_buffer(M.help_buf)
    vim.api.nvim_win_set_buf(win, M.help_buf)
end

-- open_calltree will open a calltree ui in the current tab.
--
-- if a valid tree handle and buffer exists in the tab's calltree
-- state then the tree will be written to the buffer before opening
-- the window.
M.open_calltree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    -- this allows for empty windows to be opened
    if ui_state == nil then
        ui_state = {}
        M.ui_state_registry[tab] = ui_state
    end

    local buf_name = "calltree: empty"
    if ui_state.calltree_dir ~= nil then
        buf_name = direction_map[ui_state.calltree_dir].buf_name
    end

    ui_state.calltree_buf =
        ui_buf._setup_buffer(buf_name, ui_state.calltree_buf, tab)
    if ui_state.calltree_handle ~= nil then
        tree.write_tree(ui_state.calltree_handle, ui_state.calltree_buf)
    end
    ui_state.calltree_tab = tab

    ui_win._open_window("calltree", ui_state)
end

-- close will close the calltree ui in the current tab.
M.close_calltree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    if ui_state.calltree_win ~= nil then
        if vim.api.nvim_win_is_valid(ui_state.calltree_win) then
            vim.api.nvim_win_close(ui_state.calltree_win, true)
        end
    end
    M.calltree_win = nil
end

-- open_symboltree will open a symboltree ui in the current tab.
--
-- if a valid tree handle and buffer exists in the tab's calltree
-- state then the tree will be written to the buffer before opening
-- the window.
M.open_symboltree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    if ui_state == nil then
        ui_state = {}
        M.ui_state_registry[tab] = ui_state
    end

    ui_state.symboltree_buf =
        ui_buf._setup_buffer("documentSymbols", ui_state.symboltree_buf, tab)
    if ui_state.symboltree_handle ~= nil then
        tree.write_tree(ui_state.symboltree_handle, ui_state.symboltree_buf)
    end
    ui_state.symboltree_tab = tab

    ui_win._open_window("symboltree", ui_state)
end

-- refresh_symbol_tree is used as an autocommand and
-- keeps the symboltree outline live while moving around
-- buffers in a given tab.
--
-- autocommand is set in the calltree.lua module.
M.refresh_symbol_tree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    if ui_state == nil then
        return
    end

    if
        ui_state.symboltree_win ~= nil and
        vim.api.nvim_win_is_valid(ui_state.symboltree_win)
        and #vim.lsp.get_active_clients() > 0
    then
        vim.lsp.buf.document_symbol()
    end
end

-- close_symboltree will close the symboltree ui in the current tab.
M.close_symboltree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]

    if ui_state.symboltree_win ~= nil then
        if vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
            vim.api.nvim_win_close(ui_state.symboltree_win, true)
        end
    end
    ui_state.symboltree_win = nil
end

-- collapse will collapse a symbol at the current cursor
-- position
M.collapse = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end

    node.expanded = false

    if tree_type == "symboltree" then
        tree.write_tree(tree_handle, buf)
        vim.api.nvim_win_set_cursor(win, linenr)
        return
    end

    if tree_type == "calltree" then
        tree.remove_subtree(tree_handle, node, true)
        tree.write_tree(tree_handle, buf)
        vim.api.nvim_win_set_cursor(win, linenr)
    end
end

-- expand will expand a symbol at the current cursor position
M.expand = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node   = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end
    local ui_state  = M.ui_state_registry[tab]

    if not node.expanded then
        node.expanded = true
    end

    if tree_type == "symboltree" then
        tree.write_tree(tree_handle, buf)
        vim.api.nvim_win_set_cursor(win, linenr)
        return
    end

    -- calltree nodes are lazily expanded and require an LSP request.
    if tree_type == "calltree" then
        lsp_util.multi_client_request(
            ui_state.active_lsp_clients,
            direction_map[ui_state.calltree_dir].method,
            {item = node.call_hierarchy_item},
            handlers.calltree_expand_handler(node, linenr, ui_state.calltree_dir, ui_state),
            ui_state.calltree_buf
        )
    end
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
--
-- the tree must be of type "calltree"
M.focus = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end
    local ui_state  = M.ui_state_registry[tab]

    -- only valid for calltrees
    if tree_type ~= "calltree" then
        return
    end

    tree.reparent_node(ui_state.calltree_handle, 0, node)
    tree.write_tree(ui_state.calltree_handle, ui_state.calltree_buf)
end

-- switch_direction will focus the symbol under the
-- cursor and then invert the call hierarchy direction.
M.switch_direction = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end

    local ui_state  = M.ui_state_registry[tab]

    if tree_type ~= "calltree" then
        return
    end

    if ui_state.calltree_dir == "from" then
        ui_state.calltree_dir = "to"
    else
        ui_state.calltree_dir = "from"
    end

    lsp_util.multi_client_request(
        ui_state.active_lsp_clients,
        direction_map[ui_state.calltree_dir].method,
        {item = node.call_hierarchy_item},
        handlers.calltree_switch_handler(ui_state.calltree_dir, ui_state),
        ui_state.calltree_buf
    )
end

-- jump will jump to the source code location of the
-- symbol under the cursor.
M.jump = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end

    local ui_state  = M.ui_state_registry[tab]

    local location = lsp_util.resolve_location(node)
    if location == nil or location.range.start.line == -1 then
        return
    end
    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end
    if ct.config.jump_mode == "invoking" then
        local invoking_win = nil
        if tree_type == "calltree" then
            invoking_win = ui_state.invoking_calltree_win
            ui_state.invoking_calltree_win = jumps.jump_invoking(location, invoking_win, node)
        elseif tree_type == "symboltree" then
            invoking_win = ui_state.invoking_symboltree_win
            ui_state.invoking_symboltree_win = jumps.jump_invoking(location, invoking_win, node)
        end
        return
    end
end

-- hover will show LSP hover information for the symbol
-- under the cursor.
M.hover = function()
    ui_buf.close_all_popups()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end

    local ui_state  = M.ui_state_registry[tab]

    local params = lsp_util.resolve_hover_params(node)
    if params == nil then
        return
    end
    lsp_util.multi_client_request(
        ui_state.active_lsp_clients,
        "textDocument/hover",
        params,
        hover.hover_handler,
        ui_state.calltree_buf
    )
end

-- details opens a popup window for the given symbol
-- showing more information.
M.details = function()
    ui_buf.close_all_popups()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = M.get_type_from_buf(tab, buf)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    local node = marshal.marshal_line(linenr, tree_handle)
    if node == nil then
        return
    end

    local ui_state  = M.ui_state_registry[tab]

    local direction = "symboltree"
    if tree_type == "calltree" then
        direction = ui_state.calltree_dir
    end
    deets.details_popup(node, direction)
end

-- dumptree will dump the tree datastructure to a
-- buffer for debugging.
--
-- must be called when the cursor is in the window of
-- the tree being dumped.
M.dump_tree = function()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local tree_handle = M.get_tree_from_buf(tab, buf)
    if tree_handle == nil then
        return
    end
    tree.dump_tree(tree_handle)
end

return M
