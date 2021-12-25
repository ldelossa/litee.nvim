local lib_state     = require('litee.lib.state')
local lib_tree      = require('litee.lib.tree')
local lib_panel     = require('litee.lib.panel')
local lib_lsp       = require('litee.lib.lsp')
local lib_jumps     = require('litee.lib.jumps')
local lib_navi      = require('litee.lib.navi')
local lib_util      = require('litee.lib.util')
local lib_util_win  = require('litee.lib.util.window')
local lib_notify    = require('litee.lib.notify')
local lib_hover     = require('litee.lib.lsp.hover')
local lib_details   = require('litee.lib.details')

local handlers      = require('litee.calltree.handlers')
local calltree_buf  = require('litee.calltree.buffer')
local marshal_func  = require('litee.calltree.marshal').marshal_func
local detail_func   = require('litee.calltree.details').details_func
local config        = require('litee.calltree.config').config

local M = {}

-- direction_map maps the call hierarchy lsp method to our buffer name
local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"},
    empty = {method="callHierarchy/outgoingCalls", buf_name="calltree: empty"}
}

-- ui_req_ctx creates a context table summarizing the
-- environment when a calltree request is being
-- made.
--
-- see return type for details.
local function ui_req_ctx()
    local buf    = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local linenr = vim.api.nvim_win_get_cursor(win)
    local tree_type   = lib_state.get_type_from_buf(tab, buf)
    local tree_handle = lib_state.get_tree_from_buf(tab, buf)
    local state       = lib_state.get_state(tab)

    local cursor = nil
    local node = nil
    if state ~= nil then
        if state["calltree"] ~= nil and state["calltree"].win ~= nil and
            vim.api.nvim_win_is_valid(state["calltree"].win) then
            cursor = vim.api.nvim_win_get_cursor(state["calltree"].win)
        end
        node = lib_tree.marshal_line(cursor, state["calltree"].tree)
    end

    return {
        -- the current buffer when the request is made
        buf = buf,
        -- the current win when the request is made
        win = win,
        -- the current tab when the request is made
        tab = tab,
        -- the current cursor pos when the request is made
        linenr = linenr,
        -- the type of tree if request is made in a lib_panel
        -- window.
        tree_type = tree_type,
        -- a hande to the tree if the request is made in a lib_panel
        -- window.
        tree_handle = tree_handle,
        -- the pos of the calltree cursor if a valid caltree exists.
        cursor = cursor,
        -- the current state provided by lib_state
        state = state,
        -- the current marshalled node if there's a valid calltree
        -- window present.
        node = node
    }
end

function M.open_to()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    lib_panel.open_to("calltree", ctx.state)
end

-- close_calltree will close the calltree ui in the current tab
-- and remove the corresponding tree from memory.
--
-- use hide_calltree if you simply want to hide a calltree
-- component temporarily (not removing the tree from memory)
function M.close_calltree()
    local ctx = ui_req_ctx()
    if ctx.state["calltree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["calltree"].win) then
            vim.api.nvim_win_close(ctx.state["calltree"].win, true)
        end
    end
    ctx.state["calltree"].win = nil

    if ctx.state["calltree"].tree ~= nil then
        lib_tree.remove_tree(ctx.state["calltree"].tree)
        ctx.state["calltree"].tree = nil
    end
end

-- hide_calltree will remove the calltree component from
-- the a panel temporarily.
--
-- on panel toggle the calltree will be restored.
function M.hide_calltree()
    local ctx = ui_req_ctx()
    if ctx.tree_type ~= "calltree" then
        return
    end
    if ctx.state["calltree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["calltree"].win) then
            vim.api.nvim_win_close(ctx.state["calltree"].win, true)
        end
    end
    if vim.api.nvim_win_is_valid(ctx.state["calltree"].invoking_win) then
        vim.api.nvim_set_current_win(ctx.state["calltree"].invoking_win)
    end
end

function M.collapse_calltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    ctx.node.expanded = false
    lib_tree.remove_subtree(ctx.state["calltree"].tree, ctx.node, true)
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["calltree"].buf,
        ctx.state["calltree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["calltree"].win, ctx.cursor)
end

function M.collapse_all_calltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local root = lib_tree.get_tree(ctx.state["calltree"].tree).root
    if root == nil then
        return false
    end
    lib_tree.collapse_subtree(root)
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["calltree"].buf,
        ctx.state["calltree"].tree,
        marshal_func
    )
end

function M.expand_calltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    if not ctx.node.expanded then
        ctx.node.expanded = true
    end
    lib_lsp.multi_client_request(
        ctx.state["calltree"].active_lsp_clients,
        direction_map[ctx.state["calltree"].direction].method,
        {item = ctx.node.call_hierarchy_item},
        handlers.calltree_expand_handler(ctx.node, ctx.cursor, ctx.state["calltree"].direction, ctx.state),
        ctx.state["calltree"].buf
    )
    vim.api.nvim_win_set_cursor(ctx.state["calltree"].win, ctx.cursor)
end

function M.focus_calltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    lib_tree.reparent_node(ctx.state["calltree"].tree, 0, ctx.node)
    local root = lib_tree.get_tree(ctx.state["calltree"].tree).root
    if root == nil then
        return false
    end
    lib_tree.collapse_subtree(root)
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["calltree"].buf,
        ctx.state["calltree"].tree,
        marshal_func
    )
end

function M.switch_calltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end

    if ctx.state["calltree"].direction == "from" then
        ctx.state["calltree"].direction = "to"
    else
        ctx.state["calltree"].direction = "from"
    end

    lib_lsp.multi_client_request(
        ctx.state["calltree"].active_lsp_clients,
        direction_map[ctx.state["calltree"].direction].method,
        {item = ctx.node.call_hierarchy_item},
        handlers.calltree_switch_handler(ctx.state["calltree"].direction, ctx.state),
        ctx.state["calltree"].buf
    )
end

M.jump_calltree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local location = lib_util.resolve_location(ctx.node)
    if location == nil or location.range.start.line == -1 then
        return
    end

    if split == "tab" then
        lib_jumps.jump_tab(location, ctx.node)
        return
    end

    if split == "split" or split == "vsplit" then
        lib_jumps.jump_split(split, location, ctx.node)
        return
    end

    if config.jump_mode == "neighbor" then
        lib_jumps.jump_neighbor(location, ctx.node)
        return
    end

    if config.jump_mode == "invoking" then
            local invoking_win = ctx.state["calltree"].invoking_win
            ctx.state["calltree"].invoking_win = lib_jumps.jump_invoking(location, invoking_win, ctx.node)
        return
    end
end

function M.navigation(dir)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if dir == "n" then
        lib_navi.next(ctx.state["calltree"])
    elseif dir == "p" then
        lib_navi.previous(ctx.state["calltree"])
    end
    vim.cmd("redraw!")
end

function M.on_tab_closed(tab)
    local state = lib_state.get_state[tab]
    if state == nil then
        return
    end
    lib_tree.remove_tree(state["calltree"].tree)
end

M.hover_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local params = lib_util.resolve_hover_params(ctx.node)
    if params == nil then
        return
    end
    lib_lsp.multi_client_request(
        ctx.state["calltree"].active_lsp_clients,
        "textDocument/hover",
        params,
        lib_hover.hover_handler,
        ctx.state["calltree"].buf
    )
end

M.details_calltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["calltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    lib_details.details_popup(ctx.state, ctx.node, detail_func)
end

function M.dump_tree()
    local ctx = ui_req_ctx()
    if ctx.tree_handle == nil then
        return
    end
    lib_tree.dump_tree(lib_tree.get_tree(ctx.tree_handle).root)
end

function M.dump_node()
    local ctx = ui_req_ctx()
    lib_tree.dump_tree(ctx.node)
end

function M.setup(user_config)
    local function pre_window_create(state)
        local buf_name = "calltree: empty"
        if state["calltree"].direction ~= nil then
            buf_name = direction_map[state["calltree"].direction].buf_name
        end
        state["calltree"].buf =
            calltree_buf._setup_buffer(buf_name, state["calltree"].buf, state["calltree"].tab)
        if state["calltree"].tree == nil then
            return false
        end
        if state["calltree"].tree ~= nil then
            lib_tree.write_tree_no_guide_leaf(
                state["calltree"].buf,
                state["calltree"].tree,
                marshal_func
            )
        end
        return true
    end

    local function post_window_create()
        if not config.no_hls then
            lib_util_win.set_tree_highlights()
        end
    end

    -- merge in config
    if user_config ~= nil then
        for key, val in pairs(user_config) do
            config[key] = val
        end
    end

    if not pcall(require, "litee.lib") then
        lib_notify.notify_popup_with_timeout("Cannot start litee-filetree without the litee.lib library.", 1750, "error")
        return
    end

    lib_panel.register_component("calltree", pre_window_create, post_window_create)

    vim.lsp.handlers['callHierarchy/incomingCalls'] = vim.lsp.with(
                require('litee.calltree.handlers').ch_lsp_handler("from"), {}
    )
    vim.lsp.handlers['callHierarchy/outgoingCalls'] = vim.lsp.with(
                require('litee.calltree.handlers').ch_lsp_handler("to"), {}
    )

    require('litee.calltree.commands').setup()
end

return M
