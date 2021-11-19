local tree = require('calltree.tree')
local ct = require('calltree')
local lsp_util = require('calltree.lsp.util')
local ui_buf = require('calltree.ui.buffer')
local ui_win = require('calltree.ui.window')
local help_buf = require('calltree.ui.help_buffer')
local marshal = require('calltree.ui.marshal')
local jumps = require('calltree.ui.jumps')
local deets = require('calltree.ui.details')

local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"}
}

-- the global calltree buffer
M.buffer_handle = nil
-- the global calltree window
M.win_handle = nil
-- the last tabpage our calltree ui was on
M.win_tabpage = nil
-- the active lsp clients which invoked the calltree
M.active_lsp_clients = nil
-- direction of calltree (incoming(from)/outgoing(to))
M.direction = nil
-- the window in which the calltree was invoked.
M.invoking_win_handle = nil
-- the buffer switched to when the user asks for help
M.help_buffer_handle = nil

-- help opens the help buffer in the current calltree window
-- if it exists.
--
-- open : bool - whether to open or close the help window
-- closing really means, swap the calltree window to the
-- outline buffer.
M.help = function(open)
    if
        not vim.api.nvim_win_is_valid(M.win_handle) or
        M.win_handle == nil or
        not vim.api.nvim_buf_is_valid(M.buffer_handle) or
        M.buffer_handle == nil
    then
        return
    end
    if not open then
        vim.api.nvim_win_set_buf(M.win_handle, M.buffer_handle)
        return
    end
    M.help_buffer_handle =
        help_buf._setup_help_buffer(M.help_buffer_handle)
    vim.api.nvim_win_set_buf(M.win_handle, M.help_buffer_handle)
end

-- open will open the call tree ui
M.open = function()
    M.buffer_handle =
        ui_buf._setup_buffer(M.direction, M.buffer_handle)
    if tree.root_node ~= nil then
        M.write_tree()
    end
    M.win_handle, M.win_tabpage =
        ui_win._setup_window(M.buffer_handle, M.win_handle, M.win_tabpage, ct.config)
end

-- close will close the call tree ui
M.close = function()
    if M.win_handle ~= nil then
        if vim.api.nvim_win_is_valid(M.win_handle) then
            vim.api.nvim_win_close(M.win_handle, true)
        end
    end
    M.win_handle = nil
end

-- write_tree will write the current calltree to a
-- valid calltree buffer, opening the calltree ui if
-- necessary.
M.write_tree = function()
    M.buffer_handle =
        ui_buf._setup_buffer(M.direction, M.buffer_handle)

    marshal.marshal_tree(M.buffer_handle, {}, tree.root_node)

    M.win_handle, M.win_tabpage =
        ui_win._setup_window(M.buffer_handle, M.win_handle, M.win_tabpage, ct.config)
end

-- collapse will collapse a symbol at the current cursor
-- position
M.collapse = function()
    local linenr = vim.api.nvim_win_get_cursor(M.win_handle)
    local line   = vim.api.nvim_get_current_line()
    local node   = marshal.marshal_line(line)
    if node == nil then
        return
    end

    node.expanded = false
    tree.remove_subtree(node, true)

    M.write_tree()

    vim.api.nvim_win_set_cursor(M.win_handle, linenr)
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
            M.write_tree()
            vim.api.nvim_win_set_cursor(M.win_handle, linenr)
            return
        end

        local children = {}
        for _, call_hierarchy_call in pairs(result) do
            local child = tree.Node.new(
                call_hierarchy_call[direction].name,
                0, -- tree.add_node will compute depth for us
                call_hierarchy_call[direction],
                call_hierarchy_call[direction].kind,
                call_hierarchy_call.fromRanges
            )
            table.insert(children, child)
        end

        tree.add_node(node, children)

        M.write_tree()

        vim.api.nvim_win_set_cursor(M.win_handle, linenr)
    end
end

-- expand will expand a symbol at the current cursor position
M.expand = function()
    local linenr = vim.api.nvim_win_get_cursor(M.win_handle)
    local line   = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end

    if not node.expanded then
        node.expanded = true
    end

    lsp_util.multi_client_request(
        M.active_lsp_clients,
        direction_map[M.direction].method,
        {item = node.call_hierarchy_obj},
        ch_expand_handler(node, linenr, M.direction),
        M.buffer_handle
    )
end

-- focus will reparent the calltree to the symbol under
-- the cursor, creating a calltree with the symbol
-- as root.
M.focus = function()
    local line = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end

    tree.reparent_node(0, node)
    M.write_tree()
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
        local root = tree.Node.new(ctx.params.item.name,
        0,
        ctx.params.item,
        ctx.params.item.kind)

        -- create the root's children nodes via the response array.
        local children = {}
        for _, call_hierarchy_call in pairs(result) do
          local child = tree.Node.new(
             call_hierarchy_call[direction].name,
             0, -- tree.add_node will set the depth correctly.
             call_hierarchy_call[direction],
             call_hierarchy_call[direction].kind,
             call_hierarchy_call.fromRanges
          )
          table.insert(children, child)
        end

        -- add the new root, its children, and rewrite the
        -- tree (will open the calltree ui if necessary).
        tree.add_node(root, children)

        M.write_tree()
        vim.api.nvim_buf_set_name(M.buffer_handle, direction_map[direction].buf_name)
    end
end

-- switch_direction will focus the symbol under the
-- cursor and then invert the call hierarchy direction.
M.switch_direction = function()
    local line = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end

    if M.direction == "from" then
        M.direction = "to"
    else
        M.direction = "from"
    end

    lsp_util.multi_client_request(
        M.active_lsp_clients,
        direction_map[M.direction].method,
        {item = node.call_hierarchy_obj},
        ch_switch_handler(M.direction),
        M.buffer_handle
    )
end

-- jump will jump to the source code location of the
-- symbol under the cursor.
M.jump = function()
    local line = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end
    local location = {
        uri = node.call_hierarchy_obj.uri,
        range = node.call_hierarchy_obj.range
    }
    if ct.config.jump_mode == "neighbor" then
        jumps.jump_neighbor(location, ct.config.layout, node)
        return
    end
    if ct.config.jump_mode == "invoking" then
        jumps.jump_invoking(location, M.invoking_win_handle, node)
        return
    end
end

-- hover will show LSP hover information for the symbol
-- under the cursor.
M.hover = function()
    local line = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end
    local params = {
        textDocument = {
            uri = node.call_hierarchy_obj.uri
        },
        position = {
            line = node.call_hierarchy_obj.range.start.line,
            character = node.call_hierarchy_obj.range.start.character
        }
    }
    lsp_util.multi_client_request(M.active_lsp_clients, "textDocument/hover", params, nil, M.buffer_handle)
end

-- details opens a popup window for the given symbol
-- showing more information.
M.details = function()
    local line = vim.api.nvim_get_current_line()
    local node = marshal.marshal_line(line)
    if node == nil then
        return
    end
    deets.details_popup(node, M.direction)
end

return M
