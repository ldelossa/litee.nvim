local M = {}

-- commands will setup any Vim commands exported on litee.lib
-- setup.
function M.setup()
    vim.cmd("command! LTPanel           lua require('litee.lib.panel').toggle_panel()")
    vim.cmd("command! LTTerm            lua require('litee.lib.term').terminal()")
    vim.cmd("command! LTClearJumpHL     lua require('litee.lib.jumps').set_jump_hl(false)")
    vim.cmd("command! LTClosePanelPopOut lua require('litee.lib.panel').close_current_popout()")
end

return M
