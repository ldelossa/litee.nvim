local lib_state         = require('litee.lib.state')
local lib_tree_node     = require('litee.lib.tree.node')
local lib_tree          = require('litee.lib.tree')
local lib_panel         = require('litee.lib.panel')
local lib_util          = require('litee.lib.util')
local lib_notify        = require('litee.lib.notify')
local lib_jumps         = require('litee.lib.jumps')
local lib_navi          = require('litee.lib.navi')
local lib_util_win      = require('litee.lib.util.window')
local filetree_buf      = require('litee.filetree.buffer')
local marshal_func      = require('litee.filetree.marshal').marshal_func
local config            = require('litee.filetree.config').config

local M = {}

-- ui_req_ctx creates a context table summarizing the
-- environment when a filetree request is being
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
        if state["filetree"] ~= nil and state["filetree"].win ~= nil and
            vim.api.nvim_win_is_valid(state["filetree"].win) then
            cursor = vim.api.nvim_win_get_cursor(state["filetree"].win)
        end
        node = lib_tree.marshal_line(cursor, state["filetree"].tree)
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
        -- the pos of the filetree cursor if a valid caltree exists.
        cursor = cursor,
        -- the current state provided by lib_state
        state = state,
        -- the current marshalled node if there's a valid filetree
        -- window present.
        node = node
    }
end

function M.open_to()
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    lib_panel.open_to("filetree", ctx.state)
end

-- close_filetree will close the filetree ui in the current tab
-- and remove the corresponding tree from memory.
--
-- use hide_filetree if you simply want to hide a filetree
-- component temporarily (not removing the tree from memory)
function M.close_filetree()
    local ctx = ui_req_ctx()
    if ctx.state["filetree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["filetree"].win) then
            vim.api.nvim_win_close(ctx.state["filetree"].win, true)
        end
    end
    ctx.state["filetree"].win = nil

    if ctx.state["filetree"].tree ~= nil then
        lib_tree.remove_tree(ctx.state["filetree"].tree)
        ctx.state["filetree"].tree = nil
    end
end

-- hide_filetree will remove the filetree component from
-- the a panel temporarily.
--
-- on panel toggle the filetree will be restored.
function M.hide_filetree()
    local ctx = ui_req_ctx()
    if ctx.tree_type ~= "filetree" then
        return
    end
    if ctx.state["filetree"].win ~= nil then
        if vim.api.nvim_win_is_valid(ctx.state["filetree"].win) then
            vim.api.nvim_win_close(ctx.state["filetree"].win, true)
        end
    end
    if vim.api.nvim_win_is_valid(ctx.state["filetree"].invoking_win) then
        vim.api.nvim_set_current_win(ctx.state["filetree"].invoking_win)
    end
end

function M.collapse_filetree()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    ctx.node.expanded = false
    lib_tree.remove_subtree(ctx.state["filetree"].tree, ctx.node, true)
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )
    vim.api.nvim_win_set_cursor(ctx.state["filetree"].win, ctx.cursor)
end

M.collapse_all_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    local t = lib_tree.get_tree(ctx.state["filetree"].tree)
    lib_tree.collapse_subtree(t.root)
    lib_tree.write_tree(
        ctx.state["filetree"].buf,
        ctx.state["filetree"].tree,
        marshal_func
    )
end

M.expand_filetree = function()
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
    then
        lib_notify.notify_popup_with_timeout("Must open the file explorer first", 1750, "error")
        return
    end
    if not ctx.node.expanded then
        ctx.node.expanded = true
    end
    M.expand(ctx.node, ctx.state["filetree"])
    lib_panel.toggle_panel(ctx.state, true, true)
    vim.api.nvim_win_set_cursor(ctx.state["filetree"].win, ctx.cursor)
end

M.jump_filetree = function(split)
    local ctx = ui_req_ctx()
    if
        ctx.state == nil or
        ctx.cursor == nil or
        ctx.state["filetree"].tree == nil
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
            local invoking_win = ctx.state["filetree"].invoking_win
            ctx.state["filetree"].invoking_win = lib_jumps.jump_invoking(location, invoking_win, ctx.node)
        return
    end
end

-- resolves the parent directory of a given url
function M.resolve_parent_directory(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, 0, final_sep+1)
    return dir
end

-- provides the filename with no path details for
-- the provided uri.
function M.resolve_file_name(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, final_sep+1, vim.fn.strlen(uri))
    return dir
end

-- var for holding any currently selected
-- node.
local selected_node = nil

-- select stores the provided node for a following
-- action and updates cursorline hi for the filetree_win
-- to indicate the node is selected.
function M.select(node, component_state)
    M.deselect(component_state)
    selected_node = node
    vim.api.nvim_win_set_option(component_state.win, 'winhl', "CursorLine:" .. "LTSelectFiletree")
    local type = (function() if node.filetree_item.is_dir then return "[dir]" else return "[file]" end end)()
    local details = type .. " " .. lib_util.relative_path_from_uri(node.key)
    lib_notify.notify_popup(details .. " selected", "warning")
end

-- select stores the provided node for a following
-- action and updates cursorline hi for the filetree_win
-- to indicate the node is selected.
function M.deselect(component_state)
    selected_node = nil
    vim.api.nvim_win_set_option(component_state.win, 'winhl', "CursorLine:CursorLine")
    lib_notify.close_notify_popup()
end

-- expand expands a filetree_item in the tree, refreshing the sub directory
-- incase new content exists.
function M.expand(root, component_state)
    root.expanded = true
    local children = {}
    local files = vim.fn.readdir(root.filetree_item.uri)
    for _, child in ipairs(files) do
        local uri = root.filetree_item.uri .. "/" .. child
        local is_dir = vim.fn.isdirectory(uri)
        local child_node = lib_tree_node.new_node(child, uri, 0)
        child_node.filetree_item = {
            uri = uri,
            is_dir = (function() if is_dir == 0 then return false else return true end end)()
        }
        table.insert(children, child_node)
    end
    lib_tree.add_node(component_state.tree, root, children)
end

-- touch will create a new file on the file system.
-- if `node` is a directory the file will be created
-- as a child of said directory.
--
-- if `node` is a regular file the file will be created
-- at the same level as said regular file.
function M.touch(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local touch = function(input)
        if input == nil then
            return
        end
        local touch_path = ""
        local parent_dir = ""
        if node.filetree_item.is_dir then
            parent_dir = node.filetree_item.uri .. '/'
            touch_path = parent_dir .. input
            node.expanded = true
        else
            parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
            touch_path = parent_dir .. input
        end
        if vim.fn.writefile({},touch_path) == -1 then
            return
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, component_state, dpt, parent_dir)
        cb()
    end
    vim.ui.input({prompt = "New file name: "},
        touch
    )
end

-- mkdir will create a directory.
--
-- if `node` is a directory a subdirectory
-- will be created under the former directory.
--
-- if `node` is a regular file a directory
-- will be create at the same level as
-- said regular file.
function M.mkdir(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local mkdir = function(input)
        if input == nil then
            return
        end
        local mkdir_path = ""
        local parent_dir = ""
        if node.filetree_item.is_dir then
            parent_dir = node.filetree_item.uri .. '/'
            mkdir_path = parent_dir .. input
            node.expanded = true
        else
            parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
            mkdir_path = parent_dir .. input
        end
        if vim.fn.mkdir(mkdir_path) == -1 then
            return
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, component_state, dpt, parent_dir)
        cb()
    end
    vim.ui.input({prompt = "New directory name: "},
        mkdir
    )
end

-- rm will remove the file associated with the node
-- from the file system.
function M.rm(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    if node.depth == 0 then
        lib_notify.notify_popup_with_timeout("Cannot remove your project's root directory.", 1750, "error")
        return
    end

    if vim.fn.delete(node.filetree_item.uri, 'rf') == -1 then
        return
    end

    local t = lib_tree.get_tree(component_state.tree)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, component_state, dpt)

    cb()
end

-- rename will rename the file associated with the provided
-- node.
--
-- if the original file (before rename) is opened in a neovim
-- window the buffer will first be written to disk, then
-- renamed, and then any windows referencing the original buffer
-- will have that buffer swapped with the renamed one.
--
-- this sequence avoids annoying situations like with `nnn` plugins
-- where the original buffer sticks around in neovim.
function M.rename(node, component_state, cb)
    if node.filetree_item == nil then
        return
    end
    local rename = function(input)
        if input == nil then
            return
        end
        local cur_tabpage = vim.api.nvim_get_current_tabpage()
        local path = node.filetree_item.uri
        local parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
        local rename_path = parent_dir .. input

        -- do a search to determine if the file being
        -- rewritten has a buffer and any windows open
        local original_buf = nil
        local original_wins = {}
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if not vim.api.nvim_win_is_valid(win) then
                goto continue
            end
            local buf = vim.api.nvim_win_get_buf(win)
            local buf_name = vim.api.nvim_buf_get_name(buf)
            if buf_name == path then
                vim.api.nvim_set_current_win(win)
                vim.cmd('silent write')
                original_buf = buf
                table.insert(original_wins, win)
            end
            ::continue::
        end

        if vim.fn.rename(path, rename_path) == -1 then
            return
        end

        local t = lib_tree.get_tree(component_state.tree)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, component_state, dpt)
        cb()

        -- if we recorded any original windows swap them
        -- over to the new renamed buffer.
        for _, win in ipairs(original_wins) do
            vim.api.nvim_set_current_win(win)
            vim.cmd('silent edit ' .. rename_path)
        end
        -- if we have an original buffer then delete it.
        if original_buf ~= nil then
            vim.cmd('silent bdelete ' .. original_buf)
        end
        -- if the we swapped around some buffers in another
        -- tab, vim will switch to that tab, so restore the original
        -- tab page.
        vim.api.nvim_set_current_tabpage(cur_tabpage)
        lib_panel.toggle_panel(nil, true, false)
    end
    vim.ui.input({prompt = "Rename file to: "},
        rename
    )
end


-- mv_selected will move the currently selected node
-- into the directory or parent directory of the incoming `node`.
function M.mv_selected(node, component_state, cb)
    if selected_node == nil then
        lib_notify.notify_popup_with_timeout("No file selected.", 1750, "error")
        return
    end
    local parent_dir = ""
    local selected_file = M.resolve_file_name(selected_node.filetree_item.uri)
    if node.filetree_item.is_dir then
        parent_dir = node.filetree_item.uri .. '/'
        node.expanded = true
    else
        parent_dir = M.resolve_parent_directory(node.filetree_item.uri)
    end

    local from = selected_node.filetree_item.uri
    local to = parent_dir .. selected_file
    vim.fn.rename(from, to)

    -- if node is a dir expand it, since we just
    -- created something in it
    if node.is_dir then
        node.expanded = true
    end

    local t = lib_tree.get_tree(component_state.tree)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, component_state, dpt)
    cb()
    M.deselect(component_state)
end

-- recursive_cp performs a recursive copy of a directory.
local function recursive_cp(existing_dir, move_to)
    if vim.fn.isdirectory(existing_dir) == 1 then
        local basename = M.resolve_file_name(existing_dir)
        local to_create = move_to .. '/' .. basename
        move_to = move_to .. '/' .. basename
        vim.fn.mkdir(to_create, 'p')
    end
    for _, file in ipairs(vim.fn.readdir(existing_dir)) do
        local to_check = existing_dir .. '/' .. file
        if vim.fn.isdirectory(to_check) == 1 then
            recursive_cp(to_check, move_to)
        else
            local basename = M.resolve_file_name(to_check)
            local to_create = move_to .. '/' .. basename
            vim.fn.writefile(vim.fn.readfile(to_check), to_create)
        end
    end
end

-- cp_selected will copy the currently selected node.
--
-- if the node is a directory a recursive copy will be
-- performed.
function M.cp_selected(node, component_state, cb)
    if selected_node == nil then
        lib_notify.notify_popup_with_timeout("No file selected.", 1750, "error")
        return
    end
    -- the new directory we want to move `selected_node` to, including
    -- the trailing slash.
    local move_to = ""
    if node.filetree_item.is_dir then
        move_to = node.filetree_item.uri .. '/'
        node.expanded = true
    else
        move_to = M.resolve_parent_directory(node.filetree_item.uri)
    end

    if not selected_node.filetree_item.is_dir then
        local fname = M.resolve_file_name(selected_node.filetree_item.uri)
        local from = selected_node.filetree_item.uri
        local to = move_to .. fname
        if vim.fn.writefile(vim.fn.readfile(from), to) == -1 then
            return
        end
    else
        recursive_cp(selected_node.filetree_item.uri, move_to)
    end

    -- if node is a dir expand it, since we just
    -- created something in it
    if node.is_dir then
        node.expanded = true
    end

    local t = lib_tree.get_tree(component_state.tree)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, component_state, dpt)
    cb()
    M.deselect(component_state)
end

function M.build_filetree_recursive(root, component_state, old_dpt, expand_dir)
    root.children = {}
    local old_node = nil
    if old_dpt ~= nil then
        old_node = lib_tree.search_dpt(old_dpt, root.depth, root.key)
    end
    if old_node == nil then
        -- just makes it easier to shove into the if clause below.
        old_node = {}
    end
    local should_expand = false
    -- if we are provided a directory to expand check
    -- if the current root in the path to it and if so
    -- mark it for expansion.
    if expand_dir ~= nil and expand_dir ~= "" then
        local idx = vim.fn.stridx(expand_dir, root.filetree_item.uri)
        if idx ~= -1 then
            should_expand = true
        end
    end
    if
        root.depth == 0 or
        old_node.expanded or
        should_expand
    then
        M.expand(root, component_state)
    end
    for _, child in ipairs(root.children) do
        if child.filetree_item.is_dir then
            M.build_filetree_recursive(child, component_state, old_dpt, expand_dir)
        end
    end
end

-- filetree_ops switches the provided op to the correct
-- handling function.
--
-- input for any filetree operation is handled by vim.ui.input
-- if required.
M.filetree_ops = function(opt)
    local ctx = ui_req_ctx()
    if ctx.state == nil or ctx.cursor == nil then
        return
    end
    if ctx.node == nil then
        return
    end

    if opt == "select" then
        M.select(ctx.node, ctx.state)
        lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
    end
    if opt == "deselect" then
        M.deselect(ctx.state)
        lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
    end
    if opt == "touch" then
        M.touch(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "mkdir" then
        M.mkdir(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "rm" then
        M.rm(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "rename" then
        M.rename(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "mv" then
        M.mv_selected(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
    if opt == "cp" then
        M.cp_selected(ctx.node, ctx.state["filetree"], function()
            lib_panel.toggle_panel(ctx.state, true, false)
            lib_util.safe_cursor_reset(ctx.state["filetree"].win, ctx.cursor)
        end)
    end
end

function M.navigation(dir)
    local ctx = ui_req_ctx()
    if ctx.state == nil then
        return
    end
    if dir == "n" then
        lib_navi.next(ctx.state["filetree"])
    elseif dir == "p" then
        lib_navi.previous(ctx.state["filetree"])
    end
    vim.cmd("redraw!")
end

function M.on_tab_closed(tab)
    local state = lib_state.get_state[tab]
    if state == nil then
        return
    end
    lib_tree.remove_tree(state["filetree"].tree)
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
        local cur_win = vim.api.nvim_get_current_win()
        -- unlike the other trees, we want invoked jumps
        -- to open the file in the last focused window.
        -- this updates the invoking window when the
        -- filetree is first opened.
        if cur_win ~= state["filetree"].win then
            state["filetree"].invoking_win = cur_win
        end
        local buf_name = "explorer"
        state["filetree"].buf =
            filetree_buf._setup_buffer(buf_name, state["filetree"].buf, state["filetree"].tab)
        if state["filetree"].tree == nil then
            return false
        end
        lib_tree.write_tree(
            state["filetree"].buf,
            state["filetree"].tree,
            marshal_func
        )
        return true
    end

    local function post_window_create()
        if not config.no_hls then
            lib_util_win.set_tree_highlights()
        end
        if config.use_web_devicons then
            local devicons = require("nvim-web-devicons")
            for _, icon_data in pairs(devicons.get_icons()) do
                local hl = "DevIcon" .. icon_data.name
                vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
            end
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

    if not pcall(require, "nvim-web-devicons") and config.use_web_devicons then
        lib_notify.notify_popup_with_timeout(
            "Litee-filetree is configured to use nvim-web-devicons but the module is not loaded.", 1750, "error")
    else
        -- setup the dir icon and file type.
        local devicons = require("nvim-web-devicons")
        require("nvim-web-devicons").set_icon({
          ["dir"] = {
            icon = "",
            color = "#6d8086",
            cterm_color = "108",
            name = "Directory",
          },
        })
        devicons.set_up_highlights()
    end


    lib_panel.register_component("filetree", pre_window_create, post_window_create)

    -- will enable filetree file tracking with source code buffers.
    vim.cmd([[au BufWinEnter,WinEnter * lua require('litee.filetree.autocmds').file_tracking()]])

    require('litee.filetree.commands').setup()
end

return M
