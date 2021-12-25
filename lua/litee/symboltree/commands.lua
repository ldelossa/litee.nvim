local M = {}

function M.setup()
    vim.cmd("command! LTOpenToSymboltree      lua require('litee.symboltree').open_to()")
    vim.cmd("command! LTCloseSymboltree       lua require('litee.symboltree').close_symboltree()")
    vim.cmd("command! LTNextSymboltree        lua require('litee.symboltree').navigation('n')")
    vim.cmd("command! LTPrevSymboltree        lua require('litee.symboltree').navigation('p')")
    vim.cmd("command! LTExpandSymboltree      lua require('litee.symboltree').expand_symboltree()")
    vim.cmd("command! LTCollapseSymboltree    lua require('litee.symboltree').collapse_symboltree()")
    vim.cmd("command! LTCollapseAllSymboltree lua require('litee.symboltree').collapse_all_symboltree()")
    vim.cmd("command! LTJumpSymboltree        lua require('litee.symboltree').jump_symboltree()")
    vim.cmd("command! LTJumpSymboltreeSplit   lua require('litee.symboltree').jump_symboltree('split')")
    vim.cmd("command! LTJumpSymboltreeVSplit  lua require('litee.symboltree').jump_symboltree('vsplit')")
    vim.cmd("command! LTJumpSymboltreeTab     lua require('litee.symboltree').jump_symboltree('tab')")
    vim.cmd("command! LTHoverSymboltree       lua require('litee.symboltree').hover_symboltree()")
    vim.cmd("command! LTDetailsSymboltree     lua require('litee.symboltree').details_symboltree()")
    vim.cmd("command! LTHideSymboltree        lua require('litee.symboltree').hide_symboltree()")
end

return M
