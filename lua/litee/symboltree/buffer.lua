local config = require('litee.symboltree.config').config
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
            vim.api.nvim_err_writeln("symboltree.buffer: buffer create failed")
            return
        end
    else
        return buf
    end

    -- set buf options
    vim.api.nvim_buf_set_name(buf, name .. ":" .. tab)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'symboltree')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'textwidth', 0)
    vim.api.nvim_buf_set_option(buf, 'wrapmargin', 0)

    -- au to clear jump highlights on window close
    vim.cmd("au BufWinLeave <buffer=" .. buf .. "> lua require('litee.lib.jumps').set_jump_hl(false)")

    -- au to (re)set source code highlights when a symboltree node is hovered.
    if config.auto_highlight then
        vim.cmd("au BufWinLeave,WinLeave <buffer=" .. buf .. "> lua require('litee.symboltree.autocmds').auto_highlight(false)")
        vim.cmd("au CursorHold <buffer=" .. buf .. "> lua require('litee.symboltree.autocmds').auto_highlight(true)")
    end

    -- hide the cursor if possible since there's no need for it, resizing the panel should be used instead.
    if config.hide_cursor then
        vim.cmd("au WinLeave <buffer=" .. buf .. "> lua require('litee.lib.util.buffer').hide_cursor(false)")
        vim.cmd("au WinEnter <buffer=" .. buf .. "> lua require('litee.lib.util.buffer').hide_cursor(true)")
    end

    if config.scrolloff then
        vim.cmd("au WinLeave <buffer=" .. buf .. "> lua require('litee.lib.util.buffer').set_scrolloff(false)")
        vim.cmd("au WinEnter <buffer=" .. buf .. "> lua require('litee.lib.util.buffer').set_scrolloff(true)")
    end

    -- set buffer local keymaps
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(buf, "n", "zo", ":LTExpandSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "zc", ":LTCollapseSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "zM", ":LTCollapseAllSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":LTJumpSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "s", ":LTJumpSymboltreeSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "v", ":LTJumpSymboltreeVSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "t", ":LTJumpSymboltreeTab<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "i", ":LTHoverSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "d", ":LTDetailsSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "H", ":LTHideSymboltree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buf, "n", "X", ":LTCloseSymboltree<CR>", opts)
	if config.map_resize_keys then
           lib_util_buf.map_resize_keys(panel_config.orientation, buf, opts)
    end
    return buf
end

return M
