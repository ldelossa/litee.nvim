local M = {}

-- lib.lua holds various functions for working
-- with neovim typically outside the context
-- of calltree.nvim.
--
-- lib.lua should always remain an import-only
-- module, or else cyclic imports abound.

-- safe_cursor_reset will attempt to move the
-- cursor to `linenr`, if the provided `linenr`
-- would overflow the buffer the cursor will
-- safely be placed at the lowest available
-- buffer line.
function M.safe_cursor_reset(win, linenr)
    if
        win == nil
        or not vim.api.nvim_win_is_valid(win)
        or linenr == nil
    then
        return
    end
    local lc = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
    if lc < linenr[1] then
        linenr[1] = lc
    end
    vim.api.nvim_win_set_cursor(win, linenr)
end

return M
