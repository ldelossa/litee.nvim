local lib_state         = require('litee.lib.state')
local lib_panel         = require('litee.lib.panel')
local lib_tree          = require('litee.lib.tree')
local lib_tree_node     = require('litee.lib.tree.node')
local filetree          = require('litee.filetree')


local M = {}

-- filetree_handler handles the initial request for creating a filetree
-- for a particular tab.
function M.filetree_handler()
    local cur_win = vim.api.nvim_get_current_win()
    local cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)

    local state = lib_state.get_component_state(cur_tabpage, "filetree")
    if state == nil then
        state = {}
    end

    if state.filetree_handle ~= nil then
        lib_tree.remove_tree(state.tree)
    end
    state.tree = lib_tree.new_tree("filetree")

    -- store the window invoking the filetree, jumps will
    -- occur here.
    state.invoking_win = vim.api.nvim_get_current_win()

    -- store the tab which invoked the filetree.
    state.tab = cur_tabpage

    -- get the current working directory
    local cwd = vim.fn.getcwd()

    -- create the root of our filetree
    local root = lib_tree_node.new_node(
         cwd,
         cwd,
         0
    )
    root.filetree_item = { uri = cwd, is_dir = true}

    filetree.build_filetree_recursive(root, state, nil, "")

    local global_state = lib_state.put_component_state(cur_tabpage, "filetree", state)

    lib_panel.toggle_panel(global_state, true, false)
end

return M
