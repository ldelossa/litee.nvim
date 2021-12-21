local tree_node = require('litee.tree.node')
local tree = require('litee.tree.tree')
local ui = require('litee.ui')
local filetree = require('litee.filetree')

local M = {}

-- filetree_handler handles the initial request for creating a filetree
-- for a particular tab.
function M.filetree_handler()
    -- create a new tree
    local cur_win = vim.api.nvim_get_current_win()
    local cur_tabpage = vim.api.nvim_win_get_tabpage(cur_win)
    local ui_state = ui.ui_state_registry[cur_tabpage]
    if ui_state == nil then
        ui_state = {}
        ui.ui_state_registry[cur_tabpage] = ui_state
    end
    if ui_state.filetree_handle ~= nil then
        tree.remove_tree(ui_state.filetree_handle)
    end
    ui_state.filetree_handle = tree.new_tree("filetree")
    -- store the window invoking the call tree, jumps will
    -- occur here.
    ui_state.invoking_filetree_win = vim.api.nvim_get_current_win()

    -- get the current working directory
    local cwd = vim.fn.getcwd()
    -- create the root of our filetree
    local root = tree_node.new(cwd, 0, nil, nil, nil,
        { uri = cwd, is_dir = true}
    )
    filetree.build_filetree_recursive(root, ui_state, nil, "")
    ui._open_filetree()
end

return M
