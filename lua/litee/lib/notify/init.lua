local notify_config = require('litee.lib.config').config["notify"]
local M = {}

local float_wins = {}

function M.close_notify_popup()
    if not notify_config.enabled then
        return
    end
    if float_wins == nil then
        return
    end
    for _, float_win in ipairs(float_wins) do
        if vim.api.nvim_win_is_valid(float_win) then
            vim.api.nvim_win_close(float_win, true)
        end
    end
    float_wins = nil
end

function M.notify_popup_with_timeout(text, ms, sev)
    if not notify_config.enabled then
        return
    end
    M.notify_popup(text, sev)
    local timer = vim.loop.new_timer()
    timer:start(ms, 0, vim.schedule_wrap(
        M.close_notify_popup
    ))
end

function M.notify_popup(text, sev)
    if not notify_config.enabled then
        return
    end

    if float_wins == nil then
        float_wins = {}
    end

    local buf = vim.api.nvim_create_buf(false, true)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'syntax', 'yaml')

    local lines = {text}
    local width = 20
    local line_width = vim.fn.strdisplaywidth(text)
    if line_width > width then
        width = line_width
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    local popup_conf = {
        relative = "editor",
        anchor = "SE",
        width = width,
        height = 1,
        focusable = false,
        zindex = 99,
        style = "minimal",
        border = "rounded",
        row = 0,
        col = vim.opt.columns:get(),
    }
    local float_win = vim.api.nvim_open_win(buf, false, popup_conf)
    table.insert(float_wins, float_win)
    if sev == "error" then
        vim.api.nvim_win_set_option(float_win, 'winhl', "Normal:Error")
    elseif sev == "warning" then
        vim.api.nvim_win_set_option(float_win, 'winhl', "Normal:WarningMsg")
    else
        vim.api.nvim_win_set_option(float_win, 'winhl', "Normal:NormalFloat")
    end
end

return M
