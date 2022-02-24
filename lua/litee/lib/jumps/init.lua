local config    = require('litee.lib.config').config
local lib_hi    = require('litee.lib.highlights')
local lib_panel = require('litee.lib.panel')

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
-- @param orientation (string) The orientation of the
-- surrouning plugin UI to make jumps intuitive.
-- This is typically the orientation of the litee.nvim
-- panel. Valid arguments are "left, right, top, bottom".
local function move_or_create(orientation)
    local cur_win = vim.api.nvim_get_current_win()
    if orientation == "left" then
        vim.cmd('wincmd l')
    elseif orientation == "right" then
        vim.cmd('wincmd h')
    elseif orientation == "top" then
        vim.cmd('wincmd j')
    elseif orientation == "bottom" then
        vim.cmd('wincmd k')
    end
    if cur_win == vim.api.nvim_get_current_win() then
        if orientation == "left" then
            vim.cmd("botright vsplit")
            return true
        elseif orientation == "right" then
            vim.cmd("topleft vsplit")
            return true
        elseif orientation == "top" then
            vim.cmd("topleft split")
            return true
        elseif orientation == "bottom" then
            vim.cmd("topleft split")
            return true
        end
    end
    return false
end

-- jump_tab will open a new tab then jump to the symbol
--
-- @param location (table) A location object as defined by
-- the LSP.
-- @param node (table) An element which is being jumped to,
-- if this element has a high level "references" field with
-- more "Location" objects, they will be highlighted as well.
function M.jump_tab(location, node)
    M.set_jump_hl(false, nil)
    vim.cmd("tabedit " .. location.uri)
    vim.cmd("set nocursorline")
    -- if the panel currently has a component "popped-out"
    -- close it before jumping.
    lib_panel.close_current_popout()
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
end

-- jump_split will open a new split then jump to the symbol
--
-- @param split (string) The type of split, valid arguments
-- are "split" or "vsplit".
-- @param location (table) A location object as defined by
-- the LSP.
-- @param node (table) An element which is being jumped to,
-- if this element has a high level "references" field with
-- more "Location" objects, they will be highlighted as well.
function M.jump_split(split, location, node)
    M.set_jump_hl(false, nil)
    if not move_or_create(config["panel"].orientation) then
        vim.cmd(split)
    end
    -- if the panel currently has a component "popped-out"
    -- close it before jumping.
    lib_panel.close_current_popout()
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)
end

-- jump_neighbor will jump to the symbol using the
-- closest left or right window.
--
-- a window will be created if it does not exist.
--
-- @param location (table) A location object as defined by
-- the LSP.
-- @param node (table) An element which is being jumped to,
-- if this element has a high level "references" field with
-- more "Location" objects, they will be highlighted as well.
function M.jump_neighbor(location, node)
    M.set_jump_hl(false, nil)
    move_or_create(config["panel"].orientation)
    -- if the panel currently has a component "popped-out"
    -- close it before jumping.
    lib_panel.close_current_popout()
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)

    -- cleanup any [No Name] buffers if they exist
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then
            vim.api.nvim_buf_delete(buf, {force=true})
        end
    end
end

-- jump_invoking will jump to the symbol using the
-- window that initially invoked the calltree.
--
-- a window is created and seen as the new invoking window
-- if the original invoking window has been closed.
--
-- @param location (table) A location object as defined by
-- the LSP.
-- @param win (int) A window handle of the invoking window
-- to jump to.
-- @param node (table) An element which is being jumped to,
-- if this element has a high level "references" field with
-- more "Location" objects, they will be highlighted as well.
function M.jump_invoking(location, win, node)
    M.set_jump_hl(false, nil)
    if not vim.api.nvim_win_is_valid(win) then
        if config["panel"].orientation == "left" then
            vim.cmd("botright vsplit")
        elseif config["panel"].orientation == "right" then
            vim.cmd("topleft vsplit")
        elseif config["panel"].orientation == "top" then
            vim.cmd("topleft split")
        elseif config["panel"].orientation == "bottom" then
            vim.cmd("topleft split")
        end
        win = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_set_current_win(win)

    -- if the panel currently has a component "popped-out"
    -- close it before jumping.
    lib_panel.close_current_popout()
    vim.lsp.util.jump_to_location(location)
    M.set_jump_hl(true, node)

    -- cleanup any [No Name] buffers if they exist
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then
            vim.api.nvim_buf_delete(buf, {force=true})
        end
    end

    return win
end

-- set_jump_hl will highlight the symbol and
-- any references to the symbol if set == true.
--
-- @param set (bool) If false highlights any previously created
-- jump highlights will be removed.
--
-- @param node (table) An element which is being jumped to,
-- the node must have a high level ".location" field.
-- if this element has a high level ".references" field with
-- an array of "Range" objects (specified by LSP),
-- they will be highlighted as well.
function M.set_jump_hl(set, node)
    if not set then
        if
            M.last_highlighted_buffer ~= nil
            and vim.api.nvim_buf_is_valid(M.last_highlighted_buffer)
        then
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
    local location = node.location
    if location == nil then
        return
    end
    local range = location.range

    vim.api.nvim_buf_add_highlight(
        M.last_highlighted_buffer,
        M.jump_higlight_ns,
        lib_hi.hls.SymbolJumpHL,
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
                lib_hi.hls.SymbolJumpRefsHL,
                ref["start"].line,
                ref["start"].character,
                ref["end"].character
            )
        end
    end
end

return M
