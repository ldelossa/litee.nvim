local M = {}

-- a singleton float window for a details popup.
local float_win = nil

-- close_details_popups closes the created popup window
-- if it exists.
function M.close_details_popup()
    if float_win ~= nil and
        vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
        float_win = nil
    end
end

-- details_popup creates a popup window showing futher details
-- about a symbol.
--
-- @param state (table) The global state as defined by
-- the lib/state library.
-- @param node (table) A node passed to `detail_func` representing
-- the item being described.
-- @param detail_func function(state, node) A function called with the
-- provided state and node that returns a list of buffer lines.
-- The function must evaluate both arguments and return a list of buffer
-- lines which describe any details about the node the caller defines.
function M.details_popup(state, node, detail_func)
    local buf = vim.api.nvim_create_buf(false, true)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'syntax', 'yaml')

    local lines = detail_func(state, node)
    if lines == nil then
        return
    end

    local width = 20
    for _, line in ipairs(lines) do
        local line_width = vim.fn.strdisplaywidth(line)
        if line_width > width then
            width = line_width
        end
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    local popup_conf = vim.lsp.util.make_floating_popup_options(
            width,
            #lines,
            {
                border= "rounded",
                focusable= false,
                zindex = 99,
            }
    )
    float_win = vim.api.nvim_open_win(buf, false, popup_conf)
end

return M
