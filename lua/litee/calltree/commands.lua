local M = {}

function M.setup()
    vim.cmd("command! LTOpenToCalltree      lua require('litee.calltree').open_to()")
    vim.cmd("command! LTCloseCalltree       lua require('litee.calltree').close_calltree()")
    vim.cmd("command! LTNextCalltree        lua require('litee.calltree').navigation('n')")
    vim.cmd("command! LTPrevCalltree        lua require('litee.calltree').navigation('p')")
    vim.cmd("command! LTExpandCalltree      lua require('litee.calltree').expand_calltree()")
    vim.cmd("command! LTCollapseCalltree    lua require('litee.calltree').collapse_calltree()")
    vim.cmd("command! LTCollapseAllCalltree lua require('litee.calltree').collapse_all_calltree()")
    vim.cmd("command! LTFocusCalltree       lua require('litee.calltree').focus_calltree()")
    vim.cmd("command! LTSwitchCalltree      lua require('litee.calltree').switch_calltree()")
    vim.cmd("command! LTJumpCalltree        lua require('litee.calltree').jump_calltree()")
    vim.cmd("command! LTJumpCalltreeSplit   lua require('litee.calltree').jump_calltree('split')")
    vim.cmd("command! LTJumpCalltreeVSplit  lua require('litee.calltree').jump_calltree('vsplit')")
    vim.cmd("command! LTJumpCalltreeTab     lua require('litee.calltree').jump_calltree('tab')")
    vim.cmd("command! LTHoverCalltree       lua require('litee.calltree').hover_calltree()")
    vim.cmd("command! LTDetailsCalltree     lua require('litee.calltree').details_calltree()")
    vim.cmd("command! LTHideCalltree        lua require('litee.calltree').hide_calltree()")
end

return M
