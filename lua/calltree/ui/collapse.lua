local marshal = require('calltree.ui.marshal')
local tree  = require('calltree.tree.tree')

local M = {}

function M.collapse(tree, node, linenr)
    node.expanded = false
    tree.remove_subtree(tree_handle, node, true)
    tree.write_tree(tree_handle, buf)
    vim.api.nvim_win_set_cursor(win, linenr)
end

return M
