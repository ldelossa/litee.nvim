local M = {}

-- _setup_help_buffer performs an idempotent creation
-- of the calltree help buffer
--
-- help_buf_handle : previous calltree help buffer handle
-- or nil
--
-- returns:
--   "buf_handle"  -- handle to a valid calltree help buffer
function M._setup_help_buffer(help_buf_handle)
    if
        help_buf_handle == nil
        or not vim.api.nvim_buf_is_valid(help_buf_handle)
    then
        local buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("ui.help failed: buffer create failed")
            return
        end
        help_buf_handle = buf
        local lines = {
            "CALLTREE HELP:",
            "press 'c' to close",
            "",
            "KEYMAP:",
            "zo                 - expand a symbol",
            "zc                 - collapse a symbol",
            "return             - jump to symbol",
            "f                  - focus the tree on this symbol (call hierarhies)",
            "s                  - switch the symbol from incoming/outgoing calls (call hierarchies)",
            "i                  - show hover info for symbol",
            "d                  - show symbol details",
            "c                  - close the current ui",
            "Up,Down,Right,Left - resize calltree windows"
        }
        vim.api.nvim_buf_set_lines(help_buf_handle, 0, #lines, false, lines)
    end
    -- set buf options
    vim.api.nvim_buf_set_name(help_buf_handle, "Calltree Help")
    vim.api.nvim_buf_set_option(help_buf_handle, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(help_buf_handle, 'filetype', 'Calltree')
    vim.api.nvim_buf_set_option(help_buf_handle, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(help_buf_handle, 'modifiable', false)
    vim.api.nvim_buf_set_option(help_buf_handle, 'swapfile', false)

    -- set buffer local keymaps
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(help_buf_handle, "n", "c", ":lua require('calltree.ui').help(false)<CR>", opts)

    return help_buf_handle
end

return M
