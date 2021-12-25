local config = require('litee.calltree.config').config
local panel_config = require('litee.lib.config').config["panel"]
local lib_util_buf = require('litee.lib.util.buffer')

local M = {}

-- _setup_buffer performs an idempotent creation of
-- a calltree buffer.
function M._setup_buffer(name, buf, tab)
    -- see if we can reuse a buffer that currently exists.
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_create_buf(false, false)
        if buf == 0 then
            vim.api.nvim_err_writeln("calltree.buffer: buffer create failed")
            return
        end
    else
        return buf
    end

    -- set buf options
    vim.api.nvim_buf_set_name(buf, name .. ":" .. tab)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'calltree')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'textwidth', 0)
    vim.api.nvim_buf_set_option(buf, 'wrapmargin', 0)

    -- set buffer local keymaps
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(buf, "n", "zo", ":LTExpandFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "zc", ":LTCollapseFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "zM", ":LTCollapseAllFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":LTJumpFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "s", ":LTJumpFiletreeSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "v", ":LTJumpFiletreeVSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "t", ":LTJumpFiletreeTab<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "H", ":LTHideFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "X", ":LTCloseFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "n", ":LTTouchFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "D", ":LTRemoveFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "d", ":LTMkdirFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "r", ":LTRenameFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "m", ":LTMoveFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "p", ":LTCopyFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "s", ":LTSelectFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "S", ":LTDeSelectFiletree<CR>", opts)
	if config.map_resize_keys then
           lib_util_buf.map_resize_keys(panel_config.orientation, buf, opts)
    end
    return buf
end

return M
