local config = require('calltree').config
local M = {}

local float_wins = {}

function M.close_notify_popup()
    for _, float_win in ipairs(float_wins) do
        if vim.api.nvim_win_is_valid(float_win) then
            vim.api.nvim_win_close(float_win, true)
        end
    end
    float_wins = nil
end

function M.notify_popup_with_timeout(text, ms, sev)
    if not config.enable_notify then
        return
    end
    M.notify_popup(text, sev)
    local timer = vim.loop.new_timer()
    timer:start(ms, 0, vim.schedule_wrap(
        M.close_notify_popup
    ))
end

function M.notify_popup(text, sev)
    if not config.enable_notify then
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
        row = vim.opt.lines:get() - (vim.opt.cmdheight:get() + 1),
        col = vim.opt.columns:get(),
    }
    local cur_win = vim.api.nvim_get_current_win()
    table.insert(float_wins, vim.api.nvim_open_win(buf, true, popup_conf))
    if sev == "error" then
        vim.cmd(string.format("syn match %s /%s/", "Error", [[.]]))
    elseif sev == "warning" then
        vim.cmd(string.format("syn match %s /%s/", "WarningMsg", [[.]]))
    else
        vim.cmd(string.format("syn match %s /%s/", "NormalFloat", [[.]]))
    end
    vim.api.nvim_set_current_win(cur_win)

end

return M
