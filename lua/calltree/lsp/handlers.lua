local tree_node = require('calltree.tree.node')
local tree = require('calltree.tree.tree')
local ui = require('calltree.ui')
local lsp_util = require('calltree.lsp.util')

local M = {}

-- ch_lsp_handler is the call heirarchy handler
-- used in replacement to the default lsp handler.
--
-- this handler serves as the single entry point for creating
-- a calltree.
M.ch_lsp_handler = function(direction)
    return function(err, result, ctx, _)
        if err ~= nil then
            return
        end
        if result == nil then
            return
        end
        -- snag the lsp clients from the buffer issuing the
        -- call hierarchy request
        ui.active_lsp_clients = vim.lsp.get_active_clients()

        -- tell the ui what direction the call tree is being invoked
        -- with.
        ui.calltree_dir = direction

        -- store the window invoking the call tree, jumps will
        -- occur here.
        ui.invoking_win = vim.api.nvim_get_current_win()

        -- create a new tree
        ui.calltree_handle = tree.new_tree("calltree")

        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = tree_node.new(ctx.params.item.name,
        0,
        ctx.params.item,
        nil)

        -- try to resolve the workspace symbol for root.
        root.symbol = lsp_util.symbol_from_node(ui.active_lsp_clients, root, ui.invoking_win_handle)

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
          child.symbol = lsp_util.symbol_from_node(ui.active_lsp_clients, child, ui.invoking_win_handle)
          table.insert(children, child)
        end

        tree.add_node(ui.calltree_handle, root, children)
        ui.write_tree()
    end
end

return M
