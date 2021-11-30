local config = require('calltree').config
local M = {}

-- close_all_popups is a convenience function to close any
-- popup windows associated with calltree buffers.
--
-- used as an autocommand on cursor move.
function M.close_all_popups()
    require('calltree.ui.hover').close_hover_popup()
    require('calltree.ui.details').close_details_popup()
end

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

-- _setup_buffer performs an idempotent creation
-- of the calltree buffer
--
-- direction : string - the direction of the calltree
-- window. must be "to" or "from".
--
-- buffer_handle : int - previous calltree buffer
-- or nil
--
-- tab : tabpage_handle - a handle to the tab the provided
-- buffer exists on. used to break buffer name conflicts betwee
-- tabs.
--
-- returns:
--  buffer_handle : int - handle to a valid buffer.
function M._setup_buffer(name, buffer_handle, tab)
    if buffer_handle == nil or not vim.api.nvim_buf_is_valid(buffer_handle) then
        local buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("ui.buffer: buffer create failed")
            return
        end
        buffer_handle = buf
    else
        -- we have  valid buffer on the requested tab.
        return buffer_handle
    end

    -- set buf options
    vim.api.nvim_buf_set_name(buffer_handle, name .. ":" .. tab)
    vim.api.nvim_buf_set_option(buffer_handle, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buffer_handle, 'filetype', 'Calltree')
    vim.api.nvim_buf_set_option(buffer_handle, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buffer_handle, 'modifiable', false)
    vim.api.nvim_buf_set_option(buffer_handle, 'swapfile', false)
    vim.api.nvim_buf_set_option(buffer_handle, 'textwidth', 0)
    vim.api.nvim_buf_set_option(buffer_handle, 'wrapmargin', 0)

    -- au to clear highlights on window close
    vim.cmd("au BufWinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.jumps').set_jump_hl(false)")
    -- au to close popup with cursor moves or buffer is closed.
    vim.cmd("au CursorMoved,BufWinLeave,WinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.buffer').close_all_popups()")

    -- set buffer local keymaps
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "zo", ":CTExpand<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "zc", ":CTCollapse<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<CR>", ":CTJump<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "f", ":CTFocus<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "i", ":CTHover<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "d", ":CTDetails<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "s", ":CTSwitch<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "?", ":lua require('calltree.ui').help(true)<CR>", opts)
    map_resize_keys(buffer_handle, opts)

    return buffer_handle
end

return M
