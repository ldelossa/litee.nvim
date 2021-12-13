local tree_node = require('calltree.tree.node')
local tree = require('calltree.tree.tree')
local notify = require('calltree.ui.notify')
local ct = require('calltree')
local lsp_util = require('calltree.lsp.util')

local M = {}

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
function M.select(node, ui_state)
    M.deselect(ui_state)
    selected_node = node
    vim.api.nvim_win_set_option(ui_state.filetree_win, 'winhl', "CursorLine:" .. ct.hls.SelectFiletreeHL)
    local type = (function() if node.filetree_item.is_dir then return "[dir]" else return "[file]" end end)()
    local details = type .. " " .. lsp_util.relative_path_from_uri(node.key)
    notify.notify_popup(details .. " selected", "warning")
end

-- select stores the provided node for a following
-- action and updates cursorline hi for the filetree_win
-- to indicate the node is selected.
function M.deselect(ui_state)
    selected_node = nil
    vim.api.nvim_win_set_option(ui_state.filetree_win, 'winhl', "CursorLine:CursorLine")
    notify.close_notify_popup()
end

-- expand expands a filetree_item in the tree, refreshing the sub directory
-- incase new content exists.
function M.expand(root, ui_state)
    root.expanded = true
    local children = {}
    local files = vim.fn.readdir(root.filetree_item.uri)
    for _, child in ipairs(files) do
        local uri = root.filetree_item.uri .. "/" .. child
        local is_dir = vim.fn.isdirectory(uri)
        local child_node = tree_node.new(
            child,
            0,
            nil,
            nil,
            nil,
            {
                uri = uri,
                is_dir = (function() if is_dir == 0 then return false else return true end end)()
            }
        )
        table.insert(children, child_node)
    end
    tree.add_node(ui_state.filetree_handle, root, children)
end

-- touch will create a new file on the file system.
-- if `node` is a directory the file will be created
-- as a child of said directory.
--
-- if `node` is a regular file the file will be created
-- at the same level as said regular file.
function M.touch(node, ui_state, cb)
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

        local t = tree.get_tree(ui_state.filetree_handle)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, ui_state, dpt, parent_dir)
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
function M.mkdir(node, ui_state, cb)
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

        local t = tree.get_tree(ui_state.filetree_handle)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, ui_state, dpt, parent_dir)
        cb()
    end
    vim.ui.input({prompt = "New directory name: "},
        mkdir
    )
end

-- rm will remove the file associated with the node
-- from the file system.
function M.rm(node, ui_state, cb)
    if node.filetree_item == nil then
        return
    end
    if node.depth == 0 then
        notify.notify_popup_with_timeout("Cannot remove your project's root directory.", 1750, "error")
        return
    end

    if vim.fn.delete(node.filetree_item.uri, 'rf') == -1 then
        return
    end

    local t = tree.get_tree(ui_state.filetree_handle)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, ui_state, dpt)

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
function M.rename(node, ui_state, cb)
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

        local t = tree.get_tree(ui_state.filetree_handle)
        local dpt = t.depth_table
        M.build_filetree_recursive(t.root, ui_state, dpt)
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
    end
    vim.ui.input({prompt = "Rename file to: "},
        rename
    )
end


-- mv_selected will move the currently selected node
-- into the directory or parent directory of the incoming `node`.
function M.mv_selected(node, ui_state, cb)
    if selected_node == nil then
        notify.notify_popup_with_timeout("No file selected.", 1750, "error")
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

    local t = tree.get_tree(ui_state.filetree_handle)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, ui_state, dpt)
    cb()
    M.deselect(ui_state)
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
function M.cp_selected(node, ui_state, cb)
    if selected_node == nil then
        notify.notify_popup_with_timeout("No file selected.", 1750, "error")
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

    local t = tree.get_tree(ui_state.filetree_handle)
    local dpt = t.depth_table
    M.build_filetree_recursive(t.root, ui_state, dpt)
    cb()
    M.deselect(ui_state)
end

function M.build_filetree_recursive(root, ui_state, old_dpt, expand_dir)
    root.children = {}
    local old_node = nil
    if old_dpt ~= nil then
        old_node = tree.search_dpt(old_dpt, root.depth, root.key)
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
        M.expand(root, ui_state)
    end
    for _, child in ipairs(root.children) do
        if child.filetree_item.is_dir then
            M.build_filetree_recursive(child, ui_state, old_dpt, expand_dir)
        end
    end
end

return M
