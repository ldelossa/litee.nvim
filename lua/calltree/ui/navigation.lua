local M = {}

function M.calltree_n(ui_state)
    if ui_state.calltree_win == nil
        or not vim.api.nvim_win_is_valid(ui_state.calltree_win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(ui_state.calltree_win)
    local lines_nr = vim.api.nvim_buf_line_count(ui_state.calltree_buf)
    if cur_cursor[1] + 1 > lines_nr then
        return
    end
    cur_cursor[1] = cur_cursor[1] + 1
    vim.api.nvim_win_set_cursor(ui_state.calltree_win, cur_cursor)
end

function M.calltree_p(ui_state)
    if ui_state.calltree_win == nil
        or not vim.api.nvim_win_is_valid(ui_state.calltree_win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(ui_state.calltree_win)
    if cur_cursor[1] - 1 < 1 then
        return
    end
    cur_cursor[1] = cur_cursor[1] - 1
    vim.api.nvim_win_set_cursor(ui_state.calltree_win, cur_cursor)
end

function M.symboltree_n(ui_state)
    if ui_state.symboltree_win == nil
        or not vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(ui_state.symboltree_win)
    local lines_nr = vim.api.nvim_buf_line_count(ui_state.symboltree_buf)
    if cur_cursor[1] + 1 > lines_nr then
        return
    end
    cur_cursor[1] = cur_cursor[1] + 1
    vim.api.nvim_win_set_cursor(ui_state.symboltree_win, cur_cursor)
end
function M.symboltree_p(ui_state)
    if ui_state.symboltree_win == nil
        or not vim.api.nvim_win_is_valid(ui_state.symboltree_win) then
        return
    end
    local cur_cursor = vim.api.nvim_win_get_cursor(ui_state.symboltree_win)
    if cur_cursor[1] - 1 < 1 then
        return
    end
    cur_cursor[1] = cur_cursor[1] - 1
    vim.api.nvim_win_set_cursor(ui_state.symboltree_win, cur_cursor)
end

return M
