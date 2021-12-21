local ct = require('litee')
local config = require('litee').config
local lsp_util = require('litee.lsp.util')

local M = {}

-- the current highlight source, reset on jumps
M.jump_higlight_ns = vim.api.nvim_create_namespace("calltree-jump")
-- the buffer we highlighted last.
M.last_highlighted_buffer = nil

-- move_or_create will a attempt to move from the
-- calltree ui window to the nearest editor window
--
-- if the move fails, assumingly because no other window
-- exists, a new window will be created.
--
-- layout : string - the current configured layout.
-- returns
--   bool : whether a new window was created or not
local function move_or_create(layout) 
    local cur_win = vim.api.nvim_get_current_win()
    if layout == "left" then
        vim.cmd('wincmd l')
    elseif layout == "right" then
        vim.cmd('wincmd h')
    elseif layout == "top" then
        vim.cmd('wincmd j')
    elseif layout == "bottom" then
        vim.cmd('wincmd k')
    end
    if cur_win == vim.api.nvim_get_current_win() then
        if layout == "left" then
            vim.cmd("botright vsplit")
            return true
        elseif layout == "right" then
            vim.cmd("topleft vsplit")
            return true
        elseif layout == "top" then
            vim.cmd("topleft split")
            return true
        elseif layout == "bottom" then
            vim.cmd("topleft split")
            return true
        end
    end
    return false
end

-- jump_tab will open a new tab then jump to the symbol
function M.jump_tab(location, node)
    M.set_jump_hl(false, nil)
    vim.cmd("tabedit " .. location.uri)
    vim.cmd("set nocursorline")
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
end

-- jump_split will open a new split then jump to the symbol
function M.jump_split(split, location, layout, node)
    M.set_jump_hl(false, nil)
    if not move_or_create(layout) then
        vim.cmd(split)
    end
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
end

-- jump_neighbor will jump to the symbol using the
-- closest left or right window.
--
-- a window will be created if it does not exist.
--
-- location : table - an LSP location object usable by
-- lsp.jump_to_location
--
-- layout : string - calltree's configured layout option
--
-- node : tree.Node - the node being highlighted
function M.jump_neighbor(location, layout, node)
    M.set_jump_hl(false, nil)
    move_or_create(layout)
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
end

-- jump_invoking will jump to the symbol using the
-- window that initially invoked the calltree.
--
-- a window is created and seen as the new invoking window
-- if the original invoking window has been closed.
--
-- location : table - an LSP location object usable by
-- lsp.jump_to_location
--
-- win_handle : window_handle - the previous invoking window
-- handle.
--
-- node : tree.Node - the node being highlighted
-- returns:
--  wind_handle : window_handle - a valid window_handle
--  for the invoking window.
function M.jump_invoking(location, win_handle, node)
    M.set_jump_hl(false, nil)
    if not vim.api.nvim_win_is_valid(win_handle) then
        if config.layout == "left" then
            vim.cmd("botright vsplit")
        elseif config.layout == "right" then
            vim.cmd("topleft vsplit")
        elseif config.layout == "top" then
            vim.cmd("topleft split")
        elseif config.layout == "bottom" then
            vim.cmd("topleft split")
        end
        win_handle = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_set_current_win(win_handle)
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
    return win_handle
end

-- set_jump_hl will highlight the symbol and
-- any references to the symbol if set == true.
--
-- set : bool - if false highlights any previously created
-- jump highlights will be removed.
--
-- node : tree.Node - the node being highlighted
function M.set_jump_hl(set, node)
    if not set then
        if M.last_highlighted_buffer ~= nil then
            vim.api.nvim_buf_clear_namespace(
                M.last_highlighted_buffer,
                M.jump_higlight_ns,
                0,
                -1
            )
        end
        return
    end

    M.last_highlighted_buffer = vim.api.nvim_get_current_buf()

    -- set highlght for function itself
    local location = lsp_util.resolve_location(node)
    if location == nil then
        return
    end
    local range = location.range

    vim.api.nvim_buf_add_highlight(
        M.last_highlighted_buffer,
        M.jump_higlight_ns,
        ct.hls.SymbolJumpHL,
        range["start"].line,
        range["start"].character,
        range["end"].character
    )
    -- apply it to all the references
    if node.references ~= nil then
        for _, ref in ipairs(node.references) do
            vim.api.nvim_buf_add_highlight(
                M.last_highlighted_buffer,
                M.jump_higlight_ns,
                ct.hls.SymbolJumpRefsHL,
                ref["start"].line,
                ref["start"].character,
                ref["end"].character
            )
        end
    end
end

return M
