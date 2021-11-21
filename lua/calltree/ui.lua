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

-- the global symboltree buffer
M.symboltree_buf = nil
-- handle to our symboltree tree
-- see calltree.tree.tree
M.symboltree_handle = nil
-- the global symboltree window
M.symboltree_win = nil
-- the last tabpage our symboltree ui was on
M.symboltree_tab = nil

-- the active lsp clients which invoked the calltree
M.active_lsp_clients = nil
-- the window in which the calltree was invoked.
M.invoking_win = nil
-- the buffer switched to when the user asks for help
M.help_buf = nil

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
    M.calltree_buf =
        ui_buf._setup_buffer(direction_map[M.calltree_dir].buf_name, M.calltree_buf)
    if M.calltree_handle ~= nil then
        tree.write_tree(M.calltree_handle, M.calltree_buf)
    end
    ui_win._open_window("calltree", M)
end

-- close will close the call tree ui
M.close_calltree = function()
    if M.calltree_win ~= nil then
        if vim.api.nvim_win_is_valid(M.calltree_win) then
            vim.api.nvim_win_close(M.calltree_win, true)
        end
    end
    M.calltree_win = nil
end

-- open_symboltree will open the symboltree ui
M.open_symboltree = function()
    M.symboltree_buf =
        ui_buf._setup_buffer("documentSymbols", M.symboltree_buf)
    if M.symboltree_handle ~= nil then
        tree.write_tree(M.symboltree_handle, M.symboltree_buf)
    end
    ui_win._open_window("symboltree", M)
end

M.close_symboltree = function()
    if M.symboltree_win ~= nil then
        if vim.api.nvim_win_is_valid(M.symboltree_win) then
            vim.api.nvim_win_close(M.symoltree_win, true)
        end
    end
    M.symboltree_win = nil
end

-- collapse will collapse a symbol at the current cursor
-- position
M.collapse = function()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node   = marshal.marshal_line(linenr)
    if node == nil then
        return
    end

    node.expanded = false
    tree.remove_subtree(M.calltree_handle, node, true)

    tree.write_tree(M.calltree_handle, M.calltree_buf)

    vim.api.nvim_win_set_cursor(M.calltree_win, linenr)
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
local function ch_expand_handler(node, linenr, direction)
    return function(err, result, _, _)
        if err ~= nil then
            vim.api.nvim_err_writeln(vim.inspect(err))
            return
        end
        if result == nil then
            -- rewrite the tree still to expand node giving ui
            -- feedback that no further callers/callees exist
            tree.write_tree(M.calltree_handle, M.calltree_buf)
            vim.api.nvim_win_set_cursor(M.calltree_win, linenr)
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
            child.symbol = lsp_util.symbol_from_node(M.active_lsp_clients, child, M.calltree_buf)
            table.insert(children, child)
        end

        tree.add_node(M.calltree_handle, node, children)

        tree.write_tree(M.calltree_handle, M.calltree_buf)

        vim.api.nvim_win_set_cursor(M.calltree_win, linenr)
    end
end

-- expand will expand a symbol at the current cursor position
M.expand = function()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end

    if not node.expanded then
        node.expanded = true
    end

    lsp_util.multi_client_request(
        M.active_lsp_clients,
        direction_map[M.calltree_dir].method,
        {item = node.call_hierarchy_item},
        ch_expand_handler(node, linenr, M.calltree_dir),
        M.calltree_buf
    )
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
M.focus = function()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end

    tree.reparent_node(M.calltree_handle, 0, node)
    tree.write_tree(M.calltree_handle, M.calltree_buf)
end

-- switch handler is the call_hierarchy handler
-- used when switching directions.
--
-- direction : string - the call hierarchy direction
-- "to" or "from".
local function ch_switch_handler(direction)
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
        root.symbol = lsp_util.symbol_from_node(M.active_lsp_clients, root, M.calltree_buf)

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
          child.symbol = lsp_util.symbol_from_node(M.active_lsp_clients, child, M.calltree_buf)
          table.insert(children, child)
        end

        -- add the new root, its children, and rewrite the
        -- tree (will open the calltree ui if necessary).
        tree.add_node(M.calltree_handle, root, children)

        tree.write_tree(M.calltree_handle, M.calltree_buf)
        vim.api.nvim_buf_set_name(M.calltree_buf, direction_map[direction].buf_name)
    end
end

-- switch_direction will focus the symbol under the
-- cursor and then invert the call hierarchy direction.
M.switch_direction = function()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end

    if M.calltree_dir == "from" then
        M.calltree_dir = "to"
    else
        M.calltree_dir = "from"
    end

    lsp_util.multi_client_request(
        M.active_lsp_clients,
        direction_map[M.calltree_dir].method,
        {item = node.call_hierarchy_item},
        ch_switch_handler(M.calltree_dir),
        M.calltree_buf
    )
end

-- jump will jump to the source code location of the
-- symbol under the cursor.
M.jump = function()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end
    local location = {
        uri = node.call_hierarchy_item.uri,
        range = node.call_hierarchy_item.range
    }
    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end
    if ct.config.jump_mode == "invoking" then
        jumps.jump_invoking(location, M.invoking_win, node)
        return
    end
end

-- hover will show LSP hover information for the symbol
-- under the cursor.
M.hover = function()
    ui_buf.close_all_popups()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end
    local params = {
        textDocument = {
            uri = node.call_hierarchy_item.uri
        },
        position = {
            line = node.call_hierarchy_item.range.start.line,
            character = node.call_hierarchy_item.range.start.character
        }
    }
    lsp_util.multi_client_request(M.active_lsp_clients, "textDocument/hover", params, hover.hover_handler, M.calltree_buf)
end

-- details opens a popup window for the given symbol
-- showing more information.
M.details = function()
    ui_buf.close_all_popups()
    local linenr = vim.api.nvim_win_get_cursor(M.calltree_win)
    local node = marshal.marshal_line(linenr)
    if node == nil then
        return
    end
    deets.details_popup(node, M.calltree_dir)
end

M.dump_tree = function()
    tree.dump_tree(M.calltree_handle)
end

return M
