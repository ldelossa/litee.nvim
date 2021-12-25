local M = {}

function M.next(component_state, pre_cb, post_cb)
    if component_state.win == nil
        or not vim.api.nvim_win_is_valid(component_state.win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(component_state.win)
    local lines_nr = vim.api.nvim_buf_line_count(component_state.buf)
    if cur_cursor[1] + 1 > lines_nr then
        return
    end
    cur_cursor[1] = cur_cursor[1] + 1
    if pre_cb ~= nil then pre_cb() end
    vim.api.nvim_win_set_cursor(component_state.win, cur_cursor)
    if post_cb ~= nil then pre_cb() end
end

function M.previous(component_state, pre_cb, post_cb)
    if component_state.win == nil
        or not vim.api.nvim_win_is_valid(component_state.win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(component_state.win)
    if cur_cursor[1] - 1 < 1 then
        return
    end
    cur_cursor[1] = cur_cursor[1] - 1
    if pre_cb ~= nil then pre_cb() end
    vim.api.nvim_win_set_cursor(component_state.win, cur_cursor)
    if post_cb ~= nil then pre_cb() end
end

return M
