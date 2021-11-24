local tree  = require('calltree.tree.tree')
local tree_node  = require('calltree.tree.node')
local lsp_util = require('calltree.lsp.util')
local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

-- calltree_expand_handler is the call_hierarchy request handler
-- used when expanding an existing node in the calltree.
--
-- node : tree.node.Node - the node being expanded
--
-- linenr : table - the line the cursor was on in the ui
-- buffer before expand writes to it.
--
-- direction : string - the call hierarchy direction
-- "to" or "from".
--
-- ui_state : table - a ui_state table which provides the ui state
-- of the current tab. defined in ui.lua
function M.calltree_expand_handler(node, linenr, direction, ui_state)
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

-- calltree_switch_handler is the call_hierarchy request handler
-- used when switching directions from incoming to outgoing or vice versa.
--
-- direction : string - the call hierarchy direction
-- "to" or "from".
--
-- ui_state : table - a ui_state table which provides the ui state
-- of the current tab. defined in ui.lua
function M.calltree_switch_handler(direction, ui_state)
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
        vim.api.nvim_buf_set_name(ui_state.calltree_buf, direction_map[direction].buf_name .. ":" .. ui_state.calltree_tab)
    end
end

return M
