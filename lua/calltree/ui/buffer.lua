local config = require('calltree').config

local original_guicursor = ""

local M = {}

-- close_all_popups is a convenience function to close any
-- popup windows associated with calltree buffers.
--
-- used as an autocommand on cursor move.
function M.close_all_popups()
    require('calltree.ui.hover').close_hover_popup()
    require('calltree.ui.details').close_details_popup()
end

-- set_scrolloff will enable a global scrolloff
-- of 999 when set is true.
--
-- when set is false the scrolloff will be set back to 0.
function M.set_scrolloff(set)
    if set then
        vim.cmd("set scrolloff=999")
    else
        vim.cmd("set scrolloff=0")
    end
end

-- hide_cursor will dynamically create the CTCursorHide hi and
-- set the guicursor option to this hi group.
--
-- the CTCursorHide hi has the same bg/fg as the CursorLine hi which
-- is used inside the Calltree.nvim windows.
--
-- this effectively hides the cursor by making it blend into the cursor
-- line.
--
-- hide : bool - if true hides the cursor if false sets the guicursor
-- option back to the value when Neovim started.
function M.hide_cursor(hide)
    if original_guicursor == "" then
        for _, section in ipairs(vim.opt.guicursor:get()) do
            original_guicursor = original_guicursor .. section .. ','
        end
    end
    if not hide then
        vim.cmd('set guicursor=' .. original_guicursor)
        return
    end
    local colors_rgb = vim.api.nvim_get_hl_by_name("CursorLine", true)
    local colors_256 = vim.api.nvim_get_hl_by_name("CursorLine", false)
    local hi = string.format("hi CTCursorHide cterm=None ctermbg=%s ctermfg=%s gui=None guibg=%s guifg=%s",
        (function() if colors_256.background ~= nil then return colors_256.background else return "None" end end)(),
        (function() if colors_256.foreground ~= nil then return colors_256.foreground else return "None" end end)(),
        (function() if colors_rgb.background ~= nil then return string.format("#%x", colors_rgb.background) else return "None" end end)(),
        (function() if colors_rgb.foreground ~= nil then return string.format("#%x", colors_rgb.foreground) else return "None" end end)()
    )
    vim.cmd(hi)
    local cursorgui = "set guicursor=n:CTCursorHide"
    vim.cmd(cursorgui)
end

local function map_resize_keys(buffer_handle, opts)
    local l = config.layout
    if l == "top" then
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
function M._setup_buffer(name, buffer_handle, tab, type)
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

    -- au to clear jump highlights on window close
    vim.cmd("au BufWinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.jumps').set_jump_hl(false)")


    -- hide the cursor if possible since there's no need for it, resizing the panel should be used instead.
    if config.hide_cursor then
        vim.cmd("au WinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.buffer').hide_cursor(false)")
        vim.cmd("au WinEnter <buffer=" .. buffer_handle .. "> lua require('calltree.ui.buffer').hide_cursor(true)")
    end

    -- au to (re)set source code highlights when a symboltree node is hovered.
    if config.auto_highlight then
        vim.cmd("au BufWinLeave,WinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui').auto_highlight(false)")
        vim.cmd("au CursorHold <buffer=" .. buffer_handle .. "> lua require('calltree.ui').auto_highlight(true)")
    end

    if config.scrolloff then
        vim.cmd("au WinLeave <buffer=" .. buffer_handle .. "> lua require('calltree.ui.buffer').set_scrolloff(false)")
        vim.cmd("au WinEnter <buffer=" .. buffer_handle .. "> lua require('calltree.ui.buffer').set_scrolloff(true)")
    end

    -- set buffer local keymaps
    local close_cmd = nil
    if type == "calltree" then
        close_cmd = ":CTCloseCalltree<CR>"
    end
    if type == "symboltree" then
        close_cmd = ":CTCloseSymboltree<CR>"
    end
    if type == "filetree" then
        close_cmd = ":CTCloseFiletree<CR>"
    end
    local opts = {silent=true}
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "zo", ":CTExpand<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "zc", ":CTCollapse<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "zM", ":CTCollapseAll<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<CR>", ":CTJump<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "s", ":CTJumpSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "v", ":CTJumpVSplit<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "t", ":CTJumpTab<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "f", ":CTFocus<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "i", ":CTHover<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "d", ":CTDetails<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "S", ":CTSwitch<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "?", ":lua require('calltree.ui').help(true)<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "H", ":lua require('calltree.ui')._smart_close()<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "x", close_cmd, opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "n", ":CTTouchFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "D", ":CTRemoveFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "d", ":CTMkdirFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "r", ":CTRenameFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "m", ":CTMoveFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "p", ":CTCopyFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "s", ":CTSelectFiletree<CR>", opts)
    vim.api.nvim_buf_set_keymap(buffer_handle, "n", "S", ":CTDeSelectFiletree<CR>", opts)
	if config.map_resize_keys then
        map_resize_keys(buffer_handle, opts)
    end
    return buffer_handle
end

return M
