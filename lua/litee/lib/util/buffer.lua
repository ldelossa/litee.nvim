local M = {}


local original_guicursor = ""
-- hide_cursor will dynamically create the LTCursorHide hi and
-- set the guicursor option to this hi group.
--
-- the LTCursorHide hi has the same bg/fg as the CursorLine hi which
-- is used inside the LITEE.nvim windows.
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
    local hi = string.format("hi LTCursorHide cterm=None ctermbg=%s ctermfg=%s gui=None guibg=%s guifg=%s",
        (function() if colors_256.background ~= nil then return colors_256.background else return "None" end end)(),
        (function() if colors_256.foreground ~= nil then return colors_256.foreground else return "None" end end)(),
        (function() if colors_rgb.background ~= nil then return string.format("#%x", colors_rgb.background) else return "None" end end)(),
        (function() if colors_rgb.foreground ~= nil then return string.format("#%x", colors_rgb.foreground) else return "None" end end)()
    )
    vim.cmd(hi)
    local cursorgui = "set guicursor=n:LTCursorHide"
    vim.cmd(cursorgui)
end

-- set_scrolloff will enable a global scrolloff
-- of 999 when set is true.
--
-- when set is false the scrolloff will be set back to 0.
-- useful for keeping the contents of a litee panel centered.
function M.set_scrolloff(set)
    if set then
        vim.cmd("set scrolloff=999")
    else
        vim.cmd("set scrolloff=0")
    end
end

function M.map_resize_keys(orientation, buffer_handle, opts)
    if orientation == "top" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
    elseif orientation == "bottom" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize -5<cr>", opts)
    elseif orientation == "left" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize +5<cr>", opts)
    elseif orientation == "right" then
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Up>", ":resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Down>", ":resize -5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Left>", ":vert resize +5<cr>", opts)
        vim.api.nvim_buf_set_keymap(buffer_handle, "n", "<Right>", ":vert resize -5<cr>", opts)
    end
end

-- a convenience method which will close any popups
-- generated by the litee library (not notifications).
function M.close_all_popups()
    require('litee.lib.lsp.hover').close_hover_popup()
    require('litee.lib.details').close_details_popup()
end

return M
