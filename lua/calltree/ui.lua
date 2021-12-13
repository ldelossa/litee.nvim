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
local nav = require('calltree.ui.navigation')
local filetree = require('calltree.filetree')
local lib = require('calltree.lib')

-- ui.lua is the primary interface between Neovim's TUI
-- and Calltree.nvim features.
--
-- all functions invoked from Neovim land here and route
-- to the appropriate internal counterparts.

local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

-- ui_state_registry is a registry of vim tabs mapped to calltree's
-- ui state.
--
-- every tab can have its own ui_state.
--
-- {
    -- tab# : {
    --     calltree_buf = nil
    --     calltree_handle = nil
    --     calltree_win = nil
    --     calltree_win_dimensions = nil
    --     calltree_tab = nil
    --     calltree_dir = "empty"
    --     invoking_calltree_win = nil
    --     symboltree_buf = nil
    --     symboltree_handle = nil
    --     symboltree_win = nil
    --     symboltree_win_dimensions = nil
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
    if buf == ui_state.filetree_buf then
        return "filetree"
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
    if type == "filetree" then
        return ui_state.filetree_handle
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

    local calltree_cursor, symboltree_cursor = nil, nil
    if ui_state ~= nil then
        if ui_state.calltree_win ~= nil and
            vim.api.nvim_win_is_valid(ui_state.calltree_win) then
            calltree_cursor = vim.api.nvim_win_get_cursor(ui_state.calltree_win)
        end
        if ui_state.symboltree_win ~= nil and
            vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
            symboltree_cursor = vim.api.nvim_win_get_cursor(ui_state.symboltree_win)
        end
        if ui_state.filetree_win ~= nil and
            vim.api.nvim_win_is_valid(ui_state.filetree_win) then
            filetree_cursor = vim.api.nvim_win_get_cursor(ui_state.filetree_win)
        end
    end

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
        -- if a calltree window exists, the current cursor position
        calltree_cursor = calltree_cursor,
        -- if a symboltree window exists, the current cursor position
        symboltree_cursor = symboltree_cursor,
        -- if a filetree window exists, the current cursor position
        filetree_cursor = filetree_cursor,
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
        elseif ctx.state.filetree_win == ctx.win then
            vim.api.nvim_win_set_buf(ctx.win, ctx.state.filetree_buf)
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
        if ctx.state == nil then
            notify.notify_popup_with_timeout("Cannot toggle panel until LSP method is called.", 1750, "error")
            return false
        end
        local ui_state = ctx.state
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
        M.toggle_panel(ui_state, true)
        ui_state = M.ui_state_registry[ctx.tab]
        vim.api.nvim_set_current_win(ui_state.calltree_win)
    elseif ui == "symboltree" then
        if ctx.state == nil then
            notify.notify_popup_with_timeout("Cannot toggle panel until LSP method is called.", 1750, "error")
            return false
        end
        local ui_state = ctx.state
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
        M.toggle_panel(ui_state, true)
        ui_state = M.ui_state_registry[ctx.tab]
        vim.api.nvim_set_current_win(ui_state.symboltree_win)
    elseif ui == "filetree" then
        if ctx.state == nil then
            notify.notify_popup_with_timeout("Cannot toggle panel until CTFiletreeOpen is called.", 1750, "error")
            return false
        end
        local ui_state = ctx.state
        if ui_state ~= nil then
            if ctx.win == ui_state.filetree_win then
                vim.api.nvim_set_current_win(ui_state.invoking_filetree_win)
                return
            end
            if
                ui_state.filetree_win ~= nil
                and vim.api.nvim_win_is_valid(ui_state.filetree_win)
            then
                vim.api.nvim_set_current_win(ui_state.filetree_win)
                return
            end
        end
        M.toggle_panel(ui_state, true)
        ui_state = M.ui_state_registry[ctx.tab]
        vim.api.nvim_set_current_win(ui_state.filetree_win)
    end
end

-- open_calltree will open a calltree ui in the current tab.
--
-- if a valid tree handle and buffer exists in the tab's calltree
-- state then the tree will be written to the buffer before opening
-- the window.
M._open_calltree = function()
    local ctx = ui_req_ctx()
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

M._open_filetree = function()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        ctx.state = {}
        M.ui_state_registry[ctx.tab] = ctx.state
    end
    local target_uri = vim.fn.expand('%:p')

    local buf_name = "explorer"
    ctx.state.filetree_buf =
        ui_buf._setup_buffer(buf_name, ctx.state.filetree_buf, ctx.tab, "filetree")
    if ctx.state.filetree_handle ~= nil then
        tree.write_tree(ctx.state.filetree_handle, ctx.state.filetree_buf)
    end
    ctx.state.filetree_tab = ctx.tab

    ui_win._open_window("filetree", ctx.state)
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

-- close_filetree will close the filetree ui in the current tab.
-- and remove the corresponding tree from memory.
--
-- use _smart_close if you simply want to hide a calltree
-- element temporarily (not removing the tree from memory)
M.close_filetree = function()
    local ctx = ui_req_ctx()
    if ctx.state.filetree_win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state.filetree_win) then
            vim.api.nvim_win_close(ctx.state.filetree_win, true)
        end
    end
    ctx.state.filetree_win = nil
    if ctx.state.filetree_handle ~= nil then
        tree.remove_tree(ctx.state.filetree_handle)
        ctx.state.filetree_handle = nil
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
        if vim.api.nvim_win_is_valid(ctx.state.invoking_symboltree_win) then
            vim.api.nvim_set_current_win(ctx.state.invoking_symboltree_win)
        end
        return
    end
    if ctx.tree_type == "filetree" then
        if ctx.state.filetree_win ~= nil then
            if vim.api.nvim_win_is_valid(ctx.state.filetree_win) then
                vim.api.nvim_win_close(ctx.state.filetree_win, true)
            end
        end
        if vim.api.nvim_win_is_valid(ctx.state.invoking_filetree_win) then
            vim.api.nvim_set_current_win(ctx.state.invoking_filetree_win)
        end
        return
    end
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

function M.toggle_panel(ui_state, keep_open, cycle)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        notify.notify_popup_with_timeout("Cannot toggle panel until LSP method is called.", 1750, "error")
        return nil, "Cannot toggle panel until LSP method is called."
    end

    if ui_state == nil then
        ui_state = ctx.state
    end

    local calltree_open = (ui_state.calltree_win ~= nil and vim.api.nvim_win_is_valid(ui_state.calltree_win))
    local symboltree_open = (ui_state.symboltree_win ~= nil and vim.api.nvim_win_is_valid(ui_state.symboltree_win))
    local filetree_open = (ui_state.filetree_win ~= nil and vim.api.nvim_win_is_valid(ui_state.filetree_win))
    if
        keep_open == true and
        (calltree_open or symboltree_open or filetree_open)
    then
        -- a calltree or symboltree window is open, and caller requested we keep it open.
        return
    end

    -- one of the windows are open, close them and return
    if calltree_open or symboltree_open or filetree_open then
        if calltree_open then
            ui_state.calltree_win_dimensions = {
                height = vim.api.nvim_win_get_height(ui_state.calltree_win),
                width = vim.api.nvim_win_get_width(ui_state.calltree_win)
            }
            vim.api.nvim_win_close(ui_state.calltree_win, true)
        end
        if symboltree_open then
            ui_state.symboltree_win_dimensions = {
                height = vim.api.nvim_win_get_height(ui_state.symboltree_win),
                width = vim.api.nvim_win_get_width(ui_state.symboltree_win)
            }
            vim.api.nvim_win_close(ui_state.symboltree_win, true)
        end
        if filetree_open then
            ui_state.filetree_win_dimensions = {
                height = vim.api.nvim_win_get_height(ui_state.filetree_win),
                width = vim.api.nvim_win_get_width(ui_state.filetree_win)
            }
            vim.api.nvim_win_close(ui_state.filetree_win, true)
        end
        if cycle then
            M.toggle_panel(ui_state, nil, false)
        end
        return
    end

    -- none of the windows are open, open any current or previous windows
    if keep_open == false then
        return
    end
    if ui_state.calltree_win ~= nil then
        M._open_calltree()
    end
    if ui_state.symboltree_win ~= nil then
        M._open_symboltree()
    end
    if ui_state.filetree_win ~= nil then
        M._open_filetree()
    end
    vim.api.nvim_set_current_win(ctx.win)
end

-- collapse will collapse a symbol at the current cursor
-- position inside a calltree window.
M.collapse = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window", 1750, "error")
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
        return
    end

    if ctx.tree_type == "filetree" then
        tree.remove_subtree(ctx.tree_handle, ctx.node, true)
        tree.write_tree(ctx.tree_handle, ctx.buf)
        vim.api.nvim_win_set_cursor(ctx.win, ctx.linenr)
        return
    end
end

M.collapse_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.symboltree_cursor == nil or
        ctx.state.symboltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.symboltree_cursor, ctx.state.symboltree_handle)
    node.expanded = false
    tree.write_tree(ctx.state.symboltree_handle, ctx.state.symboltree_buf)
    vim.api.nvim_win_set_cursor(ctx.state.symboltree_win, ctx.symboltree_cursor)
end

M.collapse_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.calltree_cursor == nil or
        ctx.state.calltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)
    node.expanded = false
    tree.remove_subtree(ctx.state.calltree_handle, node, true)
    tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
    vim.api.nvim_win_set_cursor(ctx.state.calltree_win, ctx.calltree_cursor)
end

M.collapse_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.filetree_cursor == nil or
        ctx.state.filetree_handle == nil
    then
        notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)
    node.expanded = false
    tree.remove_subtree(ctx.state.filetree_handle, node, true)
    tree.write_tree(ctx.state.filetree_handle, ctx.state.filetree_buf)
    vim.api.nvim_win_set_cursor(ctx.state.filetree_win, ctx.filetree_cursor)
end

-- collapse all will collapse the entire tree if
-- any nodes are expanded.
M.collapse_all = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window", 1750, "error")
        return
    end
    local t = tree.get_tree(ctx.tree_handle)
    tree.collapse_subtree(t.root)
    tree.write_tree(ctx.tree_handle, ctx.buf)
end

M.collapse_all_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.calltree_cursor == nil or
        ctx.state.calltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local t = tree.get_tree(ctx.state.calltree_handle)
    tree.collapse_subtree(t.root)
    tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
end

M.collapse_all_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.symboltree_cursor == nil or
        ctx.state.symboltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local t = tree.get_tree(ctx.state.symboltree_handle)
    tree.collapse_subtree(t.root)
    tree.write_tree(ctx.state.symboltree_handle, ctx.state.symboltree_buf)
end

M.collapse_all_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.filetree_cursor == nil or
        ctx.state.filetree_handle == nil
    then
        notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    local t = tree.get_tree(ctx.state.filetree_handle)
    tree.collapse_subtree(t.root)
    tree.write_tree(ctx.state.filetree_handle, ctx.state.filetree_buf)
end

-- expand will expand a symbol at the current cursor position
M.expand = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window", 1750, "error")
        return
    end

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

    -- filetree nodes are lazily expanded and require an internal request.
    if ctx.tree_type == "filetree" then
        filetree.expand(ctx.node, ctx.state)
        M._open_filetree()
        vim.api.nvim_win_set_cursor(ctx.state.filetree_win, ctx.filetree_cursor)
    end

end

M.expand_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.symboltree_cursor == nil or
        ctx.state.symboltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.symboltree_cursor, ctx.state.symboltree_handle)
    if not node.expanded then
        node.expanded = true
    end
    tree.write_tree(ctx.state.symboltree_handle, ctx.state.symboltree_buf)
    return
    vim.api.nvim_win_set_cursor(ctx.state.symboltree_win, ctx.symboltree_cursor)
end

M.expand_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.calltree_cursor == nil or
        ctx.state.calltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)
    if not node.expanded then
        node.expanded = true
    end
    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        direction_map[ctx.state.calltree_dir].method,
        {item = node.call_hierarchy_item},
        handlers.calltree_expand_handler(node, ctx.calltree_cursor, ctx.state.calltree_dir, ctx.state),
        ctx.state.calltree_buf
    )
    vim.api.nvim_win_set_cursor(ctx.state.calltree_win, ctx.calltree_cursor)
end

M.expand_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.filetree_cursor == nil or
        ctx.state.filetree_handle == nil
    then
        notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)
    if not node.expanded then
        node.expanded = true
    end
    filetree.expand(node, ctx.state)
    M._open_filetree()
    vim.api.nvim_win_set_cursor(ctx.state.filetree_win, ctx.filetree_cursor)
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
--
-- the tree must be of type "calltree"
M.focus = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window.", 1750, "error")
        return
    end

    ctx.state = M.ui_state_registry[ctx.tab]

    -- only valid for calltrees
    if ctx.tree_type ~= "calltree" then
        notify.notify_popup_with_timeout("Only supported for call hierarchy trees.", 1750, "error")
        return
    end

    tree.reparent_node(ctx.state.calltree_handle, 0, ctx.node)
    tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
end

M.focus_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.calltree_handle == nil or
        ctx.calltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    tree.reparent_node(ctx.state.calltree_handle, 0, ctx.node)
    tree.write_tree(ctx.state.calltree_handle, ctx.state.calltree_buf)
end

-- switch will focus the symbol under the
-- cursor and then invert the call hierarchy direction.
M.switch = function()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window.", 1750, "error")
        return
    end

    ctx.state = M.ui_state_registry[ctx.tab]

    if ctx.tree_type ~= "calltree" then
        notify.notify_popup_with_timeout("Only supported for call hierarchy trees.", 1750, "error")
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

M.switch_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.calltree_handle == nil or
        ctx.calltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)

    if ctx.state.calltree_dir == "from" then
        ctx.state.calltree_dir = "to"
    else
        ctx.state.calltree_dir = "from"
    end

    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        direction_map[ctx.state.calltree_dir].method,
        {item = node.call_hierarchy_item},
        handlers.calltree_switch_handler(ctx.state.calltree_dir, ctx.state),
        ctx.state.calltree_buf
    )
end

-- jump will jump to the source code location of the
-- symbol under the cursor.
M.jump = function(split)
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window.", 1750, "error")
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
        elseif ctx.tree_type == "filetree" then
            invoking_win = ctx.state.invoking_filetree_win
            ctx.state.invoking_filetree_win = jumps.jump_invoking(location, invoking_win, ctx.node)
        end
        return
    end
end

M.jump_calltree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.calltree_handle == nil or
        ctx.calltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)

    local location = lsp_util.resolve_location(node)
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        jumps.jump_tab(location, node)
        return
    end

    if split == "split" or split == "vsplit" then
        jumps.jump_split(split, location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "invoking" then
            local invoking_win = ctx.state.invoking_calltree_win
            ctx.state.invoking_calltree_win = jumps.jump_invoking(location, invoking_win, node)
        return
    end
end

M.jump_symboltree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.symboltree_cursor == nil or
        ctx.state.symboltree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.symboltree_cursor, ctx.state.symboltree_handle)

    local location = lsp_util.resolve_location(node)
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        jumps.jump_tab(location, node)
        return
    end

    if split == "split" or split == "vsplit" then
        jumps.jump_split(split, location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "invoking" then
            local invoking_win = ctx.state.invoking_symboltree_win
            ctx.state.invoking_calltree_win = jumps.jump_invoking(location, invoking_win, node)
        return
    end
end

M.jump_filetree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.filetree_cursor == nil or
        ctx.state.filetree_handle == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)

    if node.filetree_item.is_dir then
        return
    end

    local location = lsp_util.resolve_location(node)
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        jumps.jump_tab(location, node)
        return
    end

    if split == "split" or split == "vsplit" then
        jumps.jump_split(split, location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end

    if ct.config.jump_mode == "invoking" then
            local invoking_win = ctx.state.invoking_filetree_win
            ctx.state.invoking_calltree_win = jumps.jump_invoking(location, invoking_win, node)
        return
    end
end

-- hover will show LSP hover information for the symbol
-- under the cursor.
M.hover = function()
    ui_buf.close_all_popups()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window.", 1750, "error")
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

M.hover_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.calltree_handle == nil or
        ctx.calltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)
    local params = lsp_util.resolve_hover_params(node)
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

M.hover_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.symboltree_handle == nil or
        ctx.symboltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.symboltree_cursor, ctx.state.symboltree_handle)
    local params = lsp_util.resolve_hover_params(node)
    if params == nil then
        return
    end
    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        "textDocument/hover",
        params,
        hover.hover_handler,
        ctx.state.symboltree_buf
    )
end

M.hover_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.filetree_handle == nil or
        ctx.filetree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)
    local params = lsp_util.resolve_hover_params(node)
    if params == nil then
        return
    end
    lsp_util.multi_client_request(
        ctx.state.active_lsp_clients,
        "textDocument/hover",
        params,
        hover.hover_handler,
        ctx.state.filetree_buf
    )
end

-- details opens a popup window for the given symbol
-- showing more information.
M.details = function()
    ui_buf.close_all_popups()
    local ctx = ui_req_ctx()
    if ctx.node == nil then
        notify.notify_popup_with_timeout("Must be in a Calltree.nvim window.", 1750, "error")
        return
    end

    ctx.state  = M.ui_state_registry[ctx.tab]

    local direction = ""
    if ctx.tree_type == "calltree" then
        direction = ctx.state.calltree_dir
    end
    deets.details_popup(ctx.node, ctx.tree_type, direction)
end

M.details_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.calltree_handle == nil or
        ctx.calltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.calltree_cursor, ctx.state.calltree_handle)
    local direction = ctx.state.calltree_dir
    deets.details_popup(node, 'calltree', direction)
end

M.details_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.symboltree_handle == nil or
        ctx.symboltree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.symboltree_cursor, ctx.state.symboltree_handle)
    local direction = ctx.state.symboltree_dir
    deets.details_popup(node, 'symboltree', direction)
end

M.details_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.state.filetree_handle == nil or
        ctx.filetree_cursor == nil
    then
        notify.notify_popup_with_timeout("Must perform a document symbol LSP request first", 1750, "error")
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)
    local direction = ctx.state.filetree_dir
    deets.details_popup(node, 'filetree', direction)
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
    --
    -- we search in reverse since code is written top down, allows
    -- for source_tracking to handle nested elements correctly.
    local buf_lines = marshal.buf_line_map[ctx.tree_handle]
    if buf_lines == nil then
        return
    end
---@diagnostic disable-next-line: redefined-local
    for i=#buf_lines,1,-1 do
        local node = buf_lines[i]
        if (ctx.linenr[1] - 1) >= node.document_symbol.range["start"].line
            and (ctx.linenr[1] - 1) <= node.document_symbol.range["end"].line
                and cur_file == lsp_util.resolve_absolute_file_path(node)
        then
            vim.api.nvim_win_set_cursor(ctx.state.symboltree_win, {i, 0})
            vim.cmd("redraw!")
            return
        end
    end
end

-- file_tracking is used to keep the filetree up to date
-- with the focused source file buffer.
M.file_tracking = function()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end

    ctx.tree_type = M.get_type_from_buf(ctx.tab, ctx.state.filetree_buf)
    if
        ctx.tree_type ~= "filetree" or
        ctx.state.filetree_win == nil or
        not vim.api.nvim_win_is_valid(ctx.state.symboltree_win)
        or ctx.win == ctx.state.calltree_win
        or ctx.win == ctx.state.symboltree_win
        or ctx.win == ctx.state.filetree_win
    then
        return
    end

    local t = tree.get_tree(ctx.state.filetree_handle)
    if t == nil then
        return
    end
    local dpt = t.depth_table
    local target_uri = vim.fn.expand('%:p')
    filetree.build_filetree_recursive(t.root, ctx.state, dpt, target_uri)
    tree.write_tree(ctx.state.filetree_handle, ctx.state.filetree_buf)

    if ctx.state.filetree_win == nil or not vim.api.nvim_win_is_valid(ctx.state.filetree_win) then
        return
    end

    for buf_line, node in pairs(marshal.buf_line_map[ctx.state.filetree_handle]) do
        if node.key == target_uri then
            vim.api.nvim_win_set_cursor(ctx.state.filetree_win, {buf_line, 0})
        end
    end
end

M.navigation = function(tree_type, dir)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if tree_type == 'calltree' and dir == "n" then
        nav.calltree_n(ctx.state)
    elseif tree_type == 'calltree' and dir == "p" then
        nav.calltree_p(ctx.state)
    elseif tree_type == 'filetree' and dir == "n" then
        nav.filetree_n(ctx.state)
    elseif tree_type == 'filetree' and dir == "p" then
        nav.filetree_p(ctx.state)
    elseif tree_type == 'symboltree' and dir == "n" then
        if ctx.state.symboltree_win == nil or
            not vim.api.nvim_win_is_valid(ctx.state.symboltree_win) then
            return
        end
        vim.api.nvim_set_current_win(ctx.state.symboltree_win)
        nav.symboltree_n(ctx.state)
        M.auto_highlight(true)
        vim.api.nvim_set_current_win(ctx.win)
    elseif tree_type == 'symboltree' and dir == "p" then
        if ctx.state.symboltree_win == nil or
            not vim.api.nvim_win_is_valid(ctx.state.symboltree_win) then
            return
        end
        vim.api.nvim_set_current_win(ctx.state.symboltree_win)
        nav.symboltree_p(ctx.state)
        M.auto_highlight(true)
        vim.api.nvim_set_current_win(ctx.win)
    end
    vim.cmd("redraw!")
end

-- filetree_ops switches the provided op to the correct
-- handling function.
--
-- input for any filetree operation is handled by vim.ui.input
-- if required.
M.filetree_ops = function(opt)
    local ctx = ui_req_ctx()
    if ctx.state == nil or ctx.filetree_cursor == nil then
        return
    end
    local node = marshal.marshal_line(ctx.filetree_cursor, ctx.state.filetree_handle)
    if node == nil then
        return
    end

    if opt == "select" then
        filetree.select(node, ctx.state)
        lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
    end
    if opt == "deselect" then
        filetree.deselect(ctx.state)
        lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
    end
    if opt == "touch" then
        filetree.touch(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
    end
    if opt == "mkdir" then
        filetree.mkdir(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
    end
    if opt == "rm" then
        filetree.rm(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
    end
    if opt == "rename" then
        filetree.rename(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
    end
    if opt == "mv" then
        filetree.mv_selected(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
    end
    if opt == "cp" then
        filetree.cp_selected(node, ctx.state, function()
            M._open_filetree()
            lib.safe_cursor_reset(ctx.state.filetree_win, ctx.filetree_cursor)
        end)
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

