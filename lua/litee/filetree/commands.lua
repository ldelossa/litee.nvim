local M = {}

function M.setup()
    vim.cmd("command! LTOpenFiletree          lua require('litee.filetree.handlers').filetree_handler()")
    vim.cmd("command! LTOpenToFiletree        lua require('litee.filetree').open_to()")
    vim.cmd("command! LTCloseFiletree         lua require('litee.filetree').close_filetree()")
    vim.cmd("command! LTNextFiletree          lua require('litee.filetree').navigation('n')")
    vim.cmd("command! LTPrevFiletree          lua require('litee.filetree').navigation('p')")
    vim.cmd("command! LTExpandFiletree        lua require('litee.filetree').expand_filetree()")
    vim.cmd("command! LTCollapseFiletree      lua require('litee.filetree').collapse_filetree()")
    vim.cmd("command! LTCollapseAllFiletree   lua require('litee.filetree').collapse_all_filetree()")
    vim.cmd("command! LTJumpFiletree          lua require('litee.filetree').jump_filetree()")
    vim.cmd("command! LTJumpFiletreeSplit     lua require('litee.filetree').jump_filetree('split')")
    vim.cmd("command! LTJumpFiletreeVSplit    lua require('litee.filetree').jump_filetree('vsplit')")
    vim.cmd("command! LTJumpFiletreeTab       lua require('litee.filetree').jump_filetree('tab')")
    vim.cmd("command! LTHoverFiletree         lua require('litee.filetree').hover_filetree()")
    vim.cmd("command! LTDetailsFiletree       lua require('litee.filetree').details_filetree()")
    vim.cmd("command! LTSelectFiletree        lua require('litee.filetree').filetree_ops('select')")
    vim.cmd("command! LTDeSelectFiletree      lua require('litee.filetree').filetree_ops('deselect')")
    vim.cmd("command! LTTouchFiletree         lua require('litee.filetree').filetree_ops('touch')")
    vim.cmd("command! LTRemoveFiletree        lua require('litee.filetree').filetree_ops('rm')")
    vim.cmd("command! LTCopyFiletree          lua require('litee.filetree').filetree_ops('cp')")
    vim.cmd("command! LTMoveFiletree          lua require('litee.filetree').filetree_ops('mv')")
    vim.cmd("command! LTMkdirFiletree         lua require('litee.filetree').filetree_ops('mkdir')")
    vim.cmd("command! LTRenameFiletree        lua require('litee.filetree').filetree_ops('rename')")
end

return M
