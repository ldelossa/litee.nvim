local M = {}

-- commands will setup any Vim commands exported on litee.lib
-- setup.
function M.setup()
    vim.cmd("command! LTPanel lua require('litee.lib.panel').toggle_panel()")
end

return M
