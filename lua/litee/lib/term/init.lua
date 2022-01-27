local lib_panel = require('litee.lib.panel')
local lib_state = require('litee.lib.state')
local lib_util_buf = require('litee.lib.util.buffer')
local config = require('litee.lib.config').config["term"]

local M = {}

local opts = {noremap = true, silent=true}
local function terminal_buf_setup(buf)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>v", "<cmd>lua require('configs.terminal').terminal_vsplit()<cr>", opts)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>n", "<C-\\><C-n>", opts)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>h", "<C-\\><C-n> <C-w>h", opts)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>j", "<C-\\><C-n> <C-w>j", opts)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>k", "<C-\\><C-n> <C-w>k", opts)
    vim.api.nvim_buf_set_keymap(buf, 't', "<C-w>l", "<C-\\><C-n> <C-w>l", opts)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
	if config.map_resize_keys then
           lib_util_buf.map_resize_keys(config.position, buf, opts)
    end
end
local function terminal_win_setup(win)
    vim.api.nvim_win_set_option(win, 'winfixheight', true)
end

-- terminal opens a native Neovim terminal instance that
-- is aware of the litee.panel layout.
--
-- the terminal will not truncate the panel if it is open
-- on the left or right position.
--
-- the terminal can be opened at the top of bottom of the
-- editor, but not left or right and this is configured
-- via the 'litee.lib.config.term["position"]' stanza.
--
-- the terminal has a fixed height so a call to <C-w>=
-- does not effect the height and only evenly spaces
-- any vsplit terminals in the pane.
--
-- the $SHELL environment variable must be set correctly
-- to open the appropriate shell.
function M.terminal()
    local shell = vim.fn.getenv('SHELL')
    if shell == nil or shell == "" then
        return
    end
    local buf = vim.api.nvim_create_buf(false, false)
    if buf == 0 then
        vim.api.nvim_err_writeln("failed to create terminal buffer")
        return
    end

    terminal_buf_setup(buf)

    if config.position == "top" then
        vim.cmd('topleft split')
    else
        vim.cmd('botright split')
    end
    vim.cmd("resize " .. config.term_size)
    terminal_win_setup(vim.api.nvim_get_current_win())

    local cur_win = vim.api.nvim_get_current_win()
    local cur_tab = vim.api.nvim_get_current_tabpage()
    local state = lib_state.get_state(cur_tab)
    vim.api.nvim_win_set_buf(cur_win, buf)
    vim.fn.termopen(shell)
    if state ~= nil then
        if lib_panel.is_panel_open(state) then
            lib_panel.toggle_panel_ctx(true, true)
        end
    end
    vim.api.nvim_set_current_win(cur_win)
end

function M.terminal_vsplit()
    local shell = vim.fn.getenv('SHELL')
    if shell == nil or shell == "" then
        return
    end
    local buf = vim.api.nvim_create_buf(false, false)
    if buf == 0 then
        vim.api.nvim_err_writeln("failed to create terminal buffer")
        return
    end
    terminal_buf_setup(buf)
    vim.cmd('vsplit')
    local cur_win = vim.api.nvim_get_current_win()
    terminal_win_setup(cur_win)
    vim.api.nvim_win_set_buf(cur_win, buf)
    vim.fn.termopen(shell)
end
return M
