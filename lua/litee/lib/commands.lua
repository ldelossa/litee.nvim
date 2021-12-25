local M = {}

function M.setup()
    vim.cmd("command! LTPanel lua require('litee.lib.panel').toggle_panel()")
end

return M
