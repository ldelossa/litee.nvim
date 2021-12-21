local tree_node = require('litee.tree.node')
local tree = require('litee.tree.tree')
local ui = require('litee.ui')
local lsp_util = require('litee.lsp.util')
local config = require('litee').config
local notify = require('litee.ui.notify')

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

        -- remove existing tree from memory if exists
        if ui_state.calltree_handle ~= nil then
            tree.remove_tree(ui_state.calltree_handle)
        end

        -- create a new tree
        ui_state.calltree_handle = tree.new_tree("calltree")

        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = tree_node.new(ctx.params.item.name,
        0,
        ctx.params.item,
        nil)

        -- create the root's children nodes via the response array.
        local children = {}
        for _, call_hierarchy_call in pairs(result) do
          local child = tree_node.new(
             call_hierarchy_call[direction].name,
             0, -- tree.add_node will set the depth correctly.
             call_hierarchy_call[direction],
             call_hierarchy_call.fromRanges
          )
          table.insert(children, child)
        end

        -- if lsp.wrappers are being used this closes the notification
        -- popup.
        notify.close_notify_popup()

        -- gather symbols async
        if config.resolve_symbols then
            lsp_util.gather_symbols_async(root, children, ui_state, function()
                tree.add_node(ui_state.calltree_handle, root, children)
                ui._open_calltree()
            end)
            return
        end
        tree.add_node(ui_state.calltree_handle, root, children)
        ui._open_calltree()
   end
end

-- ws_lsp_handler handles the initial request for building
-- a document symbols outline.
M.ws_lsp_handler = function()
    return function(err, result, ctx, _)
        if err ~= nil then
            return
        end
        if result == nil then
            return
        end

        local cur_win = vim.api.nvim_get_current_win()

        local cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)

        local ui_state = ui.ui_state_registry[cur_tabpage]
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

        -- remove existing tree from memory is exists
        if ui_state.symboltree_handle ~= nil then
            tree.remove_tree(ui_state.symboltree_handle)
        end

        -- create a new tree
        ui_state.symboltree_handle = tree.new_tree("symboltree")

        -- create a synthetic document symbol to act as a root
        local synthetic_range = {}
        synthetic_range["start"] = {line=0,character=0}
        synthetic_range["end"] = {line=0,character=0}
        local synthetic_root_ds = {
            name = lsp_util.relative_path_from_uri(ctx.params.textDocument.uri),
            kind = 1,
            range = synthetic_range, -- provide this so keyify works in tree_node.add
            selectionRange = synthetic_range, -- provide this so keyify works in tree_node.add
            children = result,
            uri = ctx.params.textDocument.uri,
            detail = "file"
        }

        local root = lsp_util.build_recursive_symbol_tree(0, synthetic_root_ds, nil, prev_depth_table)

        tree.add_node(ui_state.symboltree_handle, root, nil, true)

        local cursor = nil
        if vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
            cursor = vim.api.nvim_win_get_cursor(ui_state.symboltree_win)
        end

        -- if lsp.wrappers are being used this closes the notification
        -- popup.
        notify.close_notify_popup()

        ui._open_symboltree()

        -- restore cursor if possible
        if cursor ~= nil then
           local count = vim.api.nvim_buf_line_count(ui_state.symboltree_buf)
           if  count ~= nil
               and vim.api.nvim_buf_is_valid(ui_state.symboltree_buf)
               and vim.api.nvim_buf_line_count(ui_state.symboltree_buf) >= cursor[1] then
                vim.api.nvim_win_set_cursor(ui_state.symboltree_win, cursor)
            end
       end
    end
end

return M
