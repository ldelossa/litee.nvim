local lib_state     = require('litee.lib.state')
local lib_tree      = require('litee.lib.tree')
local lib_panel     = require('litee.lib.panel')
local lib_jumps     = require('litee.lib.jumps')
local lib_navi      = require('litee.lib.navi')
local lib_util      = require('litee.lib.util')
local lib_util_win  = require('litee.lib.util.window')
local lib_notify    = require('litee.lib.notify')
local lib_details   = require('litee.lib.details')

local symboltree_buf  = require('litee.symboltree.buffer')
local marshal_func  = require('litee.symboltree.marshal').marshal_func
local detail_func   = require('litee.symboltree.details').details_func
local config        = require('litee.symboltree.config').config

local M = {}

-- ui_req_ctx creates a context table summarizing the
-- environment when a symboltree request is being
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
        if state["symboltree"] ~= nil and state["symboltree"].win ~= nil and
            vim.api.nvim_win_is_valid(state["symboltree"].win) then
            cursor = vim.api.nvim_win_get_cursor(state["symboltree"].win)
        end
        node = lib_tree.marshal_line(cursor, state["symboltree"].tree)
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
        -- the pos of the symboltree cursor if a valid caltree exists.
        cursor = cursor,
        -- the current state provided by lib_state
        state = state,
        -- the current marshalled node if there's a valid symboltree
        -- window present.
        node = node
    }
end

function M.open_to()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    lib_panel.open_to("symboltree", ctx.state)
end

-- close_symboltree will close the symboltree ui in the current tab
-- and remove the corresponding tree from memory.
--
-- use hide_symboltree if you simply want to hide a symboltree
-- component temporarily (not removing the tree from memory)
function M.close_symboltree()
    local ctx = ui_req_ctx()
    if ctx.state["symboltree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["symboltree"].win) then
            vim.api.nvim_win_close(ctx.state["symboltree"].win, true)
        end
    end
    ctx.state["symboltree"].win = nil

    if ctx.state["symboltree"].tree ~= nil then
        lib_tree.remove_tree(ctx.state["symboltree"].tree)
        ctx.state["symboltree"].tree = nil
    end
end

-- hide_symboltree will remove the symboltree component from
-- the a panel temporarily.
--
-- on panel toggle the symboltree will be restored.
function M.hide_symboltree()
    local ctx = ui_req_ctx()
    if ctx.tree_type ~= "symboltree" then
        return
    end
    if ctx.state["symboltree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["symboltree"].win) then
            vim.api.nvim_win_close(ctx.state["symboltree"].win, true)
        end
    end
    if vim.api.nvim_win_is_valid(ctx.state["symboltree"].invoking_win) then
        vim.api.nvim_set_current_win(ctx.state["symboltree"].invoking_win)
    end
end

function M.collapse_symboltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    ctx.node.expanded = false
    lib_tree.collapse_subtree(ctx.node)
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["symboltree"].buf,
        ctx.state["symboltree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["symboltree"].win, ctx.cursor)
end

function M.collapse_all_symboltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local root = lib_tree.get_tree(ctx.state["symboltree"].tree).root
    if root == nil then
        return false
    end
    lib_tree.collapse_subtree(root)
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["symboltree"].buf,
        ctx.state["symboltree"].tree,
        marshal_func
    )
end

function M.expand_symboltree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    if not ctx.node.expanded then
        ctx.node.expanded = true
    end
    lib_tree.write_tree_no_guide_leaf(
        ctx.state["symboltree"].buf,
        ctx.state["symboltree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["symboltree"].win, ctx.cursor)
end

M.jump_symboltree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
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
        lib_jumps.jump_split(split, location, config.orientation, ctx.node)
        return
    end

    if config.jump_mode == "neighbor" then
        lib_jumps.jump_neighbor(location, config.orgientation, ctx.node)
        return
    end

    if config.jump_mode == "invoking" then
            local invoking_win = ctx.state["symboltree"].invoking_win
            ctx.state["symboltree"].invoking_win = lib_jumps.jump_invoking(location, invoking_win, ctx.node)
        return
    end
end

function M.navigation(dir)
    local ctx = ui_req_ctx()
    if ctx.state == nil or ctx.state["symboltree"] == nil then
        return
    end

    -- jump into the window and run auto-his to avoid a problem
    -- with refresh_symboltree au.
    local pre_cb = function()
        vim.api.nvim_set_current_win(ctx.state["symboltree"].win)
    end
    local post_cb = function()
        require('litee.lib.highlights.auto').highlight(ctx.node, true, ctx.state["symboltree"].win)
    end

    if dir == "n" then
        lib_navi.next(ctx.state["symboltree"], pre_cb, post_cb)
    elseif dir == "p" then
        lib_navi.previous(ctx.state["symboltree"], pre_cb, post_cb)
    end
    vim.cmd("redraw!")
end

M.hover_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    local params = lib_util.resolve_hover_params(ctx.node)
    if params == nil then
        return
    end
    lib_lsp.multi_client_request(
        ctx.state["symboltree"].active_lsp_clients,
        "textDocument/hover",
        params,
        lib_hover.hover_handler,
        ctx.state["symboltree"].buf
    )
end

M.details_symboltree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["symboltree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must perform an call hierarchy LSP request first", 1750, "error")
        return
    end
    lib_details.details_popup(ctx.state, ctx.node, detail_func)
end

function M.on_tab_closed(tab)
    local state = lib_state.get_state[tab]
    if state == nil then
        return
    end
    lib_tree.remove_tree(state["symboltree"].tree)
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
        local buf_name = "documentOutline"
        state["symboltree"].buf =
            symboltree_buf._setup_buffer(buf_name, state["symboltree"].buf, state["symboltree"].tab)
        if state["symboltree"].tree == nil then
            return false
        end
        if state["symboltree"].tree ~= nil then
            lib_tree.write_tree_no_guide_leaf(
                state["symboltree"].buf,
                state["symboltree"].tree,
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

    lib_panel.register_component("symboltree", pre_window_create, post_window_create)

    -- will keep the outline view up to date when moving around buffers.
    vim.cmd([[au TextChanged,BufEnter,BufWritePost,WinEnter * lua require('litee.symboltree.autocmds').refresh_symbol_tree()]])
    --
    -- will enable symboltree ui tracking with source code lines.
    vim.cmd([[au CursorHold * lua require('litee.symboltree.autocmds').source_tracking()]])

    vim.lsp.handlers['textDocument/documentSymbol'] = vim.lsp.with(
                require('litee.symboltree.handlers').ds_lsp_handler(), {}
    )

    require('litee.symboltree.commands').setup()
end

return M
