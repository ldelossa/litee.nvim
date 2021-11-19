local M = {}

local direction_map = {
    from = {method ="callHierarchy/incomingCalls", buf_name="incomingCalls"},
    to   = {method="callHierarchy/outgoingCalls", buf_name="outgoingCalls"}
}

-- _setup_buffer performs an idempotent creation
-- of the calltree buffer
--
-- direction : string - the direction of the calltree
-- window. must be "to" or "from".
--
-- buffer_handle : int - previous calltree buffer
-- or nil
--
-- returns:
--  buffer_handle : int - handle to a valid calltree
--  buffer.
function M._setup_buffer(direction, buffer_handle)
    if buffer_handle == nil then
        local buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("ui.open failed: buffer create failed")
            return
        end
        buffer_handle = buf
    end

    -- allow empty calltree buffer
    -- only occurs if CTOpen is called before "nvim.lsp.buf.outgoingCalls" is.
    local buf_name = "empty calltree"
    if direction ~= nil then
        buf_name = direction_map[direction].buf_name
    end

    -- set buf options
    vim.api.nvim_buf_set_name(buffer_handle, buf_name)
    vim.api.nvim_buf_set_option(buffer_handle, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buffer_handle, 'filetype', 'Calltree')
    vim.api.nvim_buf_set_option(buffer_handle, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buffer_handle, 'modifiable', false)
    vim.api.nvim_buf_set_option(buffer_handle, 'swapfile', false)

    -- au to clear highlights on window close
    vim.cmd("au BufWinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.jumps').set_jump_hl(false)")
    -- au to close popup with cursor moves or buffer is closed.
    vim.cmd("au CursorMoved,BufWinLeave,WinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.details').close_details_popup()")

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

    return buffer_handle
end

return M
