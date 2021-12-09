local config = require('calltree').config
local M = {}

local function map_resize_keys(buffer_handle, opts)
    local l = config.layout
    if l == "top" or l == "bottom"  then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
    elseif l == "bottom" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize -5<cr>", opts)
    elseif l == "left" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
    elseif l == "right" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize -5<cr>", opts)
    end
end

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
            "press '?' to close",
            "",
            "KEYMAP:",
            "zo                 - expand a symbol",
            "zc                 - collapse a symbol",
            "zM                 - collapse all symbols",
            "return             - jump to symbol",
            "s                  - jump to symbol in a new split",
            "v                  - jump to symbol in a new vsplit",
            "t                  - jump to symbol in a new tab",
            "f                  - focus the tree on this symbol (call hierarchies)",
            "S                  - switch the symbol from incoming/outgoing calls (call hierarchies)",
            "i                  - show hover info for symbol",
            "d                  - show symbol details",
            "h                  - hide this element from the panel, will appear again on toggle",
            "x                  - remove this element from the panel, will not appear until another LSP request",
            "Up,Down,Right,Left - resize the panel"
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
    vim.api.nvim_buf_set_keymap(help_buf_handle, "n", "?", ":lua require('calltree.ui').help(false)<CR>", opts)
    map_resize_keys(help_buf_handle, opts)

    return help_buf_handle
end

return M
