local lib_state         = require('litee.lib.state')
local lib_panel         = require('litee.lib.panel')
local lib_tree          = require('litee.lib.tree')
local lib_tree_node     = require('litee.lib.tree.node')
local lib_lsp           = require('litee.lib.lsp')
local lib_notify        = require('litee.lib.notify')
local config            = require('litee.calltree.config').config

local M = {}

-- direction_map maps the call hierarchy lsp method to our buffer name
local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

local function keyify(call_hierarchy_item)
    if call_hierarchy_item ~= nil then
        local key = call_hierarchy_item.name .. ":" ..
                call_hierarchy_item.uri .. ":" ..
                    call_hierarchy_item.range.start.line
        return key
    end
end

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

        local cur_win = vim.api.nvim_get_current_win()
        local cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)

        local state = lib_state.get_component_state(cur_tabpage, "calltree")
        if state == nil then
            state = {}
        end

        -- remove existing tree from memory if exists
        if state.tree ~= nil then
            lib_tree.remove_tree(state.tree)
        end
        -- snag the lsp clients from the buffer issuing the
        -- call hierarchy request
        state.active_lsp_clients = vim.lsp.get_active_clients()
        -- store the window invoking the call tree, jumps will
        -- occur here.
        state.invoking_win = vim.api.nvim_get_current_win()
        -- create a new tree.
        state.tree = lib_tree.new_tree("calltree")
        -- store what direction the call tree is being invoked
        -- with.
        state.direction = direction
        -- store the tab which triggered the lsp call.
        state.tab = cur_tabpage

        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = lib_tree_node.new_node(ctx.params.item.name, keyify(ctx.params.item), 0)
        root.call_hierarchy_item = ctx.params.item

        -- create the root's children nodes via the response array.
        local children = {}
        for _, call_hierarchy_call in pairs(result) do
          local child = lib_tree_node.new_node(
             call_hierarchy_call[direction].name,
             keyify(call_hierarchy_call[direction])
          )
          child.call_hierarchy_item = call_hierarchy_call[direction]
          table.insert(children, child)
        end

        -- if lsp.wrappers are being used this closes the notification
        -- popup.
        lib_notify.close_notify_popup()

        -- update component state and grab the global since we need it to toggle
        -- the panel open.
        local global_state = lib_state.put_component_state(cur_tabpage, "calltree", state)

        -- gather symbols async
        if config.resolve_symbols then
            lib_lsp.gather_symbols_async(root, children, state, function()
                lib_tree.add_node(state.tree, root, children)
                lib_panel.toggle_panel(global_state, false, true)
            end)
            return
        end
        lib_tree.add_node(state.tree, root, children)
        lib_panel.toggle_panel(global_state, true, false)
   end
end

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
function M.calltree_expand_handler(node, linenr, direction, state)
    return function(err, result, _, _)
        if err ~= nil then
            vim.api.nvim_err_writeln(vim.inspect(err))
            return
        end
        if result == nil then
            -- rewrite the tree still to expand node giving ui
            -- feedback that no further callers/callees exist
            lib_tree.write_tree_no_guide_leaf(state["calltree"].tree, state["calltree"].buf)
            vim.api.nvim_win_set_cursor(state["calltree"].win, linenr)
            return
        end

        local children = {}
        for _, call_hierarchy_call in pairs(result) do
            local child = lib_tree_node.new_node(
               call_hierarchy_call[direction].name,
               keyify(call_hierarchy_call[direction])
            )
            child.call_hierarchy_item = call_hierarchy_call[direction]
            table.insert(children, child)
        end

        if config.resolve_symbols then
            lib_lsp.gather_symbols_async(node, children, state["calltree"], function()
                lib_tree.add_node(state["calltree"].tree, node, children)
                lib_tree.write_tree_no_guide_leaf(
                    state["calltree"].buf,
                    state["calltree"].tree,
                    require('litee.calltree.marshal').marshal_func
                )
                vim.api.nvim_win_set_cursor(state["calltree"].win, linenr)
            end)
            vim.api.nvim_win_set_cursor(state["calltree"].win, linenr)
            return
        end

        lib_tree.add_node(state["calltree"].tree, node, children)
        lib_tree.write_tree_no_guide_leaf(
            state["calltree"].buf,
            state["calltree"].tree,
            require('litee.calltree.marshal').marshal_func
        )
        vim.api.nvim_win_set_cursor(state["calltree"].win, linenr)
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
function M.calltree_switch_handler(direction, state)
    return function(err, result, ctx, _)
        if err ~= nil or result == nil then
            return
        end
        -- create the root of our call tree, the request which
        -- signaled this response is in ctx.params
        local root = lib_tree_node.new_node(ctx.params.item.name, keyify(ctx.params.item), 0)
        root.call_hierarchy_item = ctx.params.item

        -- try to resolve the workspace symbol for root
        root.symbol = lib_lsp.symbol_from_node(state["calltree"].active_lsp_clients, root, state["calltree"].buf)

        -- create the root's children nodes via the response array.
        local children = {}
        for _, call_hierarchy_call in pairs(result) do
            local child = lib_tree_node.new_node(
               call_hierarchy_call[direction].name,
               keyify(call_hierarchy_call[direction])
            )
            child.call_hierarchy_item = call_hierarchy_call[direction]
            table.insert(children, child)
        end

        if config.resolve_symbols then
            lib_lsp.gather_symbols_async(root, children, state["calltree"], function()
                lib_tree.add_node(state["calltree"].tree, root, children)
                lib_tree.write_tree_no_guide_leaf(
                    state["calltree"].buf,
                    state["calltree"].tree,
                    require('litee.calltree.marshal').marshal_func
                )
                vim.api.nvim_buf_set_name(state["calltree"].buf, direction_map[direction].buf_name .. ":" .. state["calltree"].tab)
            end)
            return
        end

        lib_tree.add_node(state["calltree"].tree, root, children)
        lib_tree.write_tree_no_guide_leaf(
            state["calltree"].buf,
            state["calltree"].tree,
            require('litee.calltree.marshal').marshal_func
        )
    end
end

return M
