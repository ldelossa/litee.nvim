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

        cur_win = vim.api.nvim_get_current_win()

        cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)

        ui_state = ui.ui_state_registry[cur_tabpage] 
        if ui_state == nil then
            ui_state = {}
            ui.ui_state_registry[cur_tabpage] = ui_state
        end

        -- snag the lsp clients from the buffer issuing the
        -- call hierarchy request
        ui_state.active_lsp_clients = vim.lsp.get_active_clients()

        -- tell the ui what direction the call tree is being invoked
        -- with.
        ui_state.calltree_dir = direction

        -- store the window invoking the call tree, jumps will
        -- occur here.
        ui_state.invoking_calltree_win = vim.api.nvim_get_current_win()

        -- create a new tree
        ui_state.calltree_handle = tree.new_tree("calltree")

        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = tree_node.new(ctx.params.item.name,
        0,
        ctx.params.item,
        nil)

        -- try to resolve the workspace symbol for root.
        root.symbol = lsp_util.symbol_from_node(ui_state.active_lsp_clients, root, ui_state.invoking_calltree_win)

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
          child.symbol = lsp_util.symbol_from_node(ui_state.active_lsp_clients, child, ui_state.invoking_calltree_win)
          table.insert(children, child)
        end

        tree.add_node(ui_state.calltree_handle, root, children)
        ui.open_calltree()
    end
end

M.ws_lsp_handler = function()
    return function(err, result, ctx, _)
        if err ~= nil then
            return
        end
        if result == nil then
            return
        end

        cur_win = vim.api.nvim_get_current_win()

        cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)

        ui_state = ui.ui_state_registry[cur_tabpage] 
        if ui_state == nil then
            ui_state = {}
            ui.ui_state_registry[cur_tabpage] = ui_state
        end

        -- snag the lsp clients from the buffer issuing the
        -- call hierarchy request
        ui_state.active_lsp_clients = vim.lsp.get_active_clients()

        -- grab the previous depth table if it exists
        local prev_depth_table = nil
        local prev_tree = tree.get_tree(ui_state.symboltree_handle)
        if prev_tree ~= nil then
            prev_depth_table = prev_tree.depth_table
        end

        ui_state.invoking_symboltree_win = vim.api.nvim_get_current_win()

        -- create a new tree
        ui_state.symboltree_handle = tree.new_tree("symboltree")

        -- create a synthetic document symbol to act as a root
        local synthetic_root_ds = {
            name = lsp_util.relative_path_from_uri(ctx.params.textDocument.uri),
            kind = 1,
            range = {start = {line = -1}}, -- provide this so keyify works in tree_node.add
            selectionRange = {start = {line = -1}}, -- provide this so keyify works in tree_node.add
            children = result,
            uri = ctx.params.textDocument.uri,
            detail = "file"
        }

        local root = lsp_util.build_recursive_symbol_tree(0, synthetic_root_ds, nil, prev_depth_table)

        tree.add_node(ui_state.symboltree_handle, root, nil, true)

        ui.open_symboltree()
    end
end

return M
