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
local tree_node  = require('calltree.tree.node')

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

-- the global calltree buffer
M.calltree_buf = nil
-- handle to our calltree tree
-- see calltree.tree.tree
M.calltree_handle = nil
-- the global calltree window
M.calltree_win = nil
-- the last tabpage our calltree ui was on
M.calltree_tab = nil
-- direction of calltree (incoming(from)/outgoing(to))
M.calltree_dir = "empty"
-- the window in which the calltree was invoked.
M.invoking_calltree_win = nil

-- the global symboltree buffer
M.symboltree_buf = nil
-- handle to our symboltree tree
-- see calltree.tree.tree
M.symboltree_handle = nil
-- the global symboltree window
M.symboltree_win = nil
-- the last tabpage our symboltree ui was on
M.symboltree_tab = nil
-- the window in which the calltree was invoked.
M.invoking_symboltree_win = nil

-- the active lsp clients which invoked the calltree
M.active_lsp_clients = nil
-- the buffer switched to when the user asks for help
M.help_buf = nil

-- obtains the tree type for the given buffer.
M.get_type_from_buf = function(tab, buf)
    ui_state = M.ui_state_registry[tab]
    if buf == ui_state.calltree_buf then
        return "calltree"
    end
    if buf == ui_state.symboltree_buf then
        return "symboltree"
    end
    return nil
end

-- obtains the tree handle for a given buffer.
M.get_tree_from_buf = function(tab, buf)
    ui_state = M.ui_state_registry[tab]
    local type = M.get_type_from_buf(tab, buf)
    if type == "calltree" then
        return ui_state.calltree_handle
    end
    if type == "symboltree" then
        return ui_state.symboltree_handle
    end
end

-- help opens the help buffer in the current calltree window
-- if it exists.
--
-- open : bool - whether to open or close the help window
-- closing really means, swap the calltree window to the
-- outline buffer.
M.help = function(open)
    if
        not vim.api.nvim_win_is_valid(M.calltree_win) or
        M.calltree_win == nil or
        not vim.api.nvim_buf_is_valid(M.calltree_buf) or
        M.calltree_buf == nil
    then
        return
    end
    if not open then
        vim.api.nvim_win_set_buf(M.calltree_win, M.calltree_buf)
        return
    end
    M.help_buf =
        help_buf._setup_help_buffer(M.help_buf)
    vim.api.nvim_win_set_buf(M.calltree_win, M.help_buf)
end

-- open_calltree will open the call tree ui
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

    ui_win._open_window("calltree", ui_state)
end

-- close will close the call tree ui
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

-- open_symboltree will open the symboltree ui
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

    ui_win._open_window("symboltree", ui_state)
end

M.refresh_symbol_tree = function()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local ui_state  = M.ui_state_registry[tab]
    if ui_state == nil then
        return
    end

    if ui_state.symboltree_win ~= nil and
        vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
        vim.lsp.buf.document_symbol()
    end
end

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

-- ch_expand_handler is the call_hierarchy handler
-- when expanding an existing node in the calltree.
--
-- node : tree.Node - the node being expanded
--
-- linenr : table - the line the cursor was on in the ui
-- buffer before expand writes to it.
--
-- direction : string - the call hierarchy direction
-- "to" or "from".
local function calltree_expand_handler(node, linenr, direction, ui_state)
    return function(err, result, _, _)
        if err ~= nil then
            vim.api.nvim_err_writeln(vim.inspect(err))
            return
        end
        if result == nil then
            -- rewrite the tree still to expand node giving ui
            -- feedback that no further callers/callees exist
            tree.write_tree(ui_state.calltree_handle, ui_state.calltree_buf)
            vim.api.nvim_win_set_cursor(ui_state.calltree_win, linenr)
            return
        end

        local children = {}
        for _, call_hierarchy_call in pairs(result) do
            local child = tree_node.new(
                call_hierarchy_call[direction].name,
                0, -- tree.add_node will compute depth for us
                call_hierarchy_call[direction],
                call_hierarchy_call.fromRanges
            )
            -- try to resolve the workspace symbol for child
            child.symbol = lsp_util.symbol_from_node(ui_state.active_lsp_clients, child, ui_state.calltree_buf)
            table.insert(children, child)
        end

        tree.add_node(ui_state.calltree_handle, node, children)
        tree.write_tree(ui_state.calltree_handle, ui_state.calltree_buf)
        vim.api.nvim_win_set_cursor(ui_state.calltree_win, linenr)
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

    if tree_type == "calltree" then
        lsp_util.multi_client_request(
            ui_state.active_lsp_clients,
            direction_map[ui_state.calltree_dir].method,
            {item = node.call_hierarchy_item},
            calltree_expand_handler(node, linenr, ui_state.calltree_dir, ui_state),
            ui_state.calltree_buf
        )
    end
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
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

-- switch handler is the call_hierarchy handler
-- used when switching directions.
--
-- direction : string - the call hierarchy direction
-- "to" or "from".
local function ch_switch_handler(direction, ui_state)
    return function(err, result, ctx, _)
        if err ~= nil then
            return
        end
        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = tree_node.new(ctx.params.item.name,
        0,
        ctx.params.item,
        nil)
        -- try to resolve the workspace symbol for root
        root.symbol = lsp_util.symbol_from_node(ui_state.active_lsp_clients, root, ui_state.calltree_buf)

        -- create the root's children nodes via the response array.
        local children = {}
        for _, call_hierarchy_call in pairs(result) do
          local child = tree_node.new(
             call_hierarchy_call[direction].name,
             0, -- tree.add_node will set the depth correctly.
             call_hierarchy_call[direction],
             call_hierarchy_call.fromRanges
          )
          -- try to resolve the workspace symbol for child
          child.symbol = lsp_util.symbol_from_node(ui_state.active_lsp_clients, child, ui_state.calltree_buf)
          table.insert(children, child)
        end

        -- add the new root, its children, and rewrite the
        -- tree (will open the calltree ui if necessary).
        tree.add_node(ui_state.calltree_handle, root, children)

        tree.write_tree(ui_state.calltree_handle, ui_state.calltree_buf)
        vim.api.nvim_buf_set_name(ui_state.calltree_buf, direction_map[direction].buf_name)
    end
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
        ch_switch_handler(ui_state.calltree_dir, ui_state),
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
    if location == nil then
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
    lsp_util.multi_client_request(ui_state.active_lsp_clients, "textDocument/hover", params, hover.hover_handler, ui_state.calltree_buf)
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

M.dump_tree = function()
    local buf = vim.api.nvim_get_current_buf()
    local tree_handle = M.get_tree_from_buf(buf)
    if tree_handle == nil then
        return
    end
    tree.dump_tree(tree_handle)
end

return M
