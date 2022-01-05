local lib_state = require('litee.lib.state')
local lib_panel = require('litee.lib.panel')

local M = {}

function M.on_resize()
    local cur_win = vim.api.nvim_get_current_win()
    local cur_tab = vim.api.nvim_get_current_tabpage()
    local state = lib_state.get_state(cur_tab)
    if state == nil then
        return
    end
    local is_open = lib_panel.is_panel_open(state)
    if is_open then
        lib_panel.toggle_panel(state, false, true)
        vim.api.nvim_set_current_win(cur_win)
    end
end

return M
