local M = {}

-- _setup_buffer performs an idempotent creation
-- of the calltree window
--
-- buf_handle : a valid calltree buffer handle
--
-- win_handle : win_handle - previous calltree window
-- or nil
--
-- win_tabpage : tab_handle - prevous tab the previous
-- calltree window belong too.
--
-- config : table - the calltree configuration table.
--
-- returns:
--   "win_handle"  -- handle to a valid calltree window
--   "win_tabpage" -- the tabpage the valid calltree window exists
--    on
function M._setup_window(buf_handle, win_handle, win_tabpage, config)
    local current_tabpage = vim.api.nvim_win_get_tabpage(
        vim.api.nvim_get_current_win()
    )
    if
        win_handle == nil
        or (current_tabpage ~= win_tabpage)
        or not vim.api.nvim_win_is_valid(win_handle)
    then
        if
            win_handle ~= nil
            and vim.api.nvim_win_is_valid(win_handle)
        then
            vim.api.nvim_win_close(win_handle, true)
        end

        if config.layout == "left" then
            vim.cmd("topleft vsplit")
        else
            vim.cmd("botright vsplit")
        end

        vim.cmd("vertical resize " ..
                    config.layout_size)

        win_handle = vim.api.nvim_get_current_win()
        win_tabpage = vim.api.nvim_win_get_tabpage(win_handle)
        vim.api.nvim_win_set_buf(win_handle, buf_handle)
    end
    vim.api.nvim_win_set_option(win_handle, 'number', false)
    vim.api.nvim_win_set_option(win_handle, 'cursorline', true)
    vim.api.nvim_buf_set_option(buf_handle, 'textwidth', 0)
    vim.api.nvim_buf_set_option(buf_handle, 'wrapmargin', 0)
    vim.api.nvim_win_set_option(win_handle, 'wrap', false)
    return win_handle, win_tabpage
end

return M
