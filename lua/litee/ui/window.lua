local config = require("litee").config
local lt = require("litee")
local marshal = require('litee.ui.marshal')
local webicons = require('litee.nvim-web-devicons')
local M = {}

-- window.lua offers a declartive way to open new windows
-- in a static layout.

-- static_layout defines the order of calltree windows in
-- the ui.
local static_layout = {symboltree=1, calltree=2, filetree=3}

-- type_to_ui_state_win is a helper map which maps the
-- window type being opened to the win field on the ui_state.
local type_to_ui_state_win = {
    calltree = "calltree_win",
    symboltree = "symboltree_win",
    filetree = "filetree_win"
}

-- realize_current_and_desired will determine the current and desired layouts
-- given a requested window type to open.
--
-- check_win_type is one of the windows in the static layout. we check if this
-- window is currently opened in the provided ui_state and whether its the desired window.
--
-- desired_win_type is the desired window type being opened. it is checked against the
-- check_win_type to determine its addition or omission into the desired_layout array.
--
-- returns:
--   continue : bool - whether to continue evaluating the open window request.
--                     false if we determine the window is already open on the current tab.
local function realize_current_and_desired(check_win_type, desired_win_type, current_layout, desired_layout, ui_state)
    local current_tabpage = vim.api.nvim_win_get_tabpage(
        vim.api.nvim_get_current_win()
    )

    -- check if the desired window exists.
    local win = ui_state[type_to_ui_state_win[check_win_type]]
    if win == nil or (not vim.api.nvim_win_is_valid(win)) then
        if check_win_type == desired_win_type then
            -- checked window is invalid, its also the desired window to open
            -- add it to desired layout.
            table.insert(desired_layout, desired_win_type)
        end
        return true
    end

    local win_tabpage = vim.api.nvim_win_get_tabpage(win)
    -- desired window type is already open on current tabpage, noop
    if check_win_type == desired_win_type and current_tabpage == win_tabpage then
        return false
    end
    -- the checked window type is open and on the current tab, unconditionally add it to
    -- desired_layout to preserve it existence.
    if current_tabpage == win_tabpage then
        table.insert(current_layout, win)
        table.insert(desired_layout, check_win_type)
    -- the window type we are checking is also the desired window type, but its
    -- opened in another tab, close it and add desired window type to desired layout.
    -- it will be opened on the current tab.
    elseif check_win_type == desired_win_type then
        vim.api.nvim_win_close(win, true)
        table.insert(desired_layout, desired_win_type)
    end
    return true
end

-- open_window will first compute the current UI layout
-- then compute the desired layout and finally call
-- _setup_window with both.
function M._open_window(kind, ui_state)
    -- holds open window handles we'll reuse
    local current_layout = {}
    -- holds the window types to ensure present in the ui
    local desired_layout = {}

    for win_type, _ in pairs(static_layout) do
        if not realize_current_and_desired(win_type, kind, current_layout, desired_layout, ui_state) then
            return
        end
    end

    M._setup_window(current_layout, desired_layout, ui_state)
end

-- setup_window evaluates the current layout and the desired layout
-- and opens the necessary windows to obtain the desired layout.
--
-- current_layout : array - list of win_handles expressing the
-- current layout. we will reuse these windows in place assigning them
-- the desired layout's buffers if possible.
--
-- desired_layout : array - list of window types to open. if there
-- are available windows in current_layout to use the desired layout
-- will be achieved by swapping the current_layout buffer with the desired
-- one. once no buffers are available in current_layout we will begin
-- to use splits to make additional windows.
function M._setup_window(current_layout, desired_layout, ui_state)
    for i, kind in ipairs(desired_layout) do
        local buffer_to_set = nil
        local win_handle_to_set = nil
        local dimensions_to_set = nil

        if kind == "calltree" then
            buffer_to_set = ui_state.calltree_buf
            win_handle_to_set = "calltree_win"
            if ui_state.calltree_win_dimensions ~= nil then
                dimensions_to_set = ui_state.calltree_win_dimensions
            end
        end
        if kind == "symboltree" then
            buffer_to_set = ui_state.symboltree_buf
            win_handle_to_set = "symboltree_win"
            if ui_state.symboltree_win_dimensions ~= nil then
                dimensions_to_set = ui_state.symboltree_win_dimensions
            end
        end
        if kind == "filetree" then
            buffer_to_set = ui_state.filetree_buf
            win_handle_to_set = "filetree_win"
            if ui_state.filetree_win_dimensions ~= nil then
                dimensions_to_set = ui_state.filetree_win_dimensions
            end
        end

        -- we can reuse the current layout windows
        if i <= #current_layout then
            vim.api.nvim_win_set_buf(current_layout[i], buffer_to_set)
            ui_state[win_handle_to_set] = current_layout[i]
            vim.api.nvim_set_current_win(ui_state[win_handle_to_set])
            goto continue
        end

        -- we are out of open windows, so we need to create some

        if #current_layout == 0 then
            -- there is no current layout, so just do a botright or equivalent
            if config.layout == "left" then
                vim.cmd("topleft vsplit")
                vim.cmd("vertical resize " ..
                            config.layout_size)
            elseif config.layout == "right" then
                vim.cmd("botright vsplit")
                vim.cmd("vertical resize " ..
                            config.layout_size)
            elseif config.layout == "top" then
                vim.cmd("topleft split")
                vim.cmd("resize " ..
                            config.layout_size)
            elseif config.layout == "bottom" then
                vim.cmd("botright split")
                vim.cmd("resize " ..
                            config.layout_size)
            end
            goto set
        end

        -- cursor currently in a reused window, split according to layout config
        if config.layout == "left" then
            vim.cmd("below split")
        elseif config.layout == "right" then
            vim.cmd("below split")
        elseif config.layout == "top" then
            vim.cmd("vsplit")
        elseif config.layout == "bottom" then
            vim.cmd("vsplit")
        end

        ::set::
        cur_win = vim.api.nvim_get_current_win()
        ui_state[win_handle_to_set] = cur_win
        vim.api.nvim_win_set_buf(ui_state[win_handle_to_set], buffer_to_set)
        vim.api.nvim_win_set_option(ui_state[win_handle_to_set], 'number', false)
        vim.api.nvim_win_set_option(ui_state[win_handle_to_set], 'cursorline', true)
        vim.api.nvim_win_set_option(ui_state[win_handle_to_set], 'wrap', false)
        vim.api.nvim_win_set_option(ui_state[win_handle_to_set], 'winfixwidth', true)
        vim.api.nvim_win_set_option(ui_state[win_handle_to_set], 'winfixheight', true)
        if
            dimensions_to_set ~= nil and
            dimensions_to_set.width ~= nil and
            dimensions_to_set.height ~= nil
        then
            if (config.layout == "left" or config.layout == "right") then
                vim.api.nvim_win_set_width(cur_win, dimensions_to_set.width)
            else
                vim.api.nvim_win_set_height(cur_win, dimensions_to_set.height)
            end
        else
            dimensions_to_set = {}
            dimensions_to_set.height = vim.api.nvim_win_get_height(cur_win)
            dimensions_to_set.wdith  = vim.api.nvim_win_get_width(cur_win)
            d = string.format("%s_%s", win_handle_to_set, "dimensions")
            ui_state[d] = dimensions_to_set
        end


        ::continue::
        if not config.no_hls then
            -- set configured icon highlights
            if lt.active_icon_set ~= nil then
                for icon, hl in pairs(lt.icon_hls) do
                    vim.cmd(string.format("syn match %s /%s/", hl, lt.active_icon_set[icon]))
                end
            end
            -- set configured symbol highlight
            vim.cmd(string.format("syn match %s /%s/", lt.hls.SymbolHL, [[\w]]))
            -- set configured expanded indicator highlights
            vim.cmd(string.format("syn match %s /%s/", lt.hls.ExpandedGuideHL, marshal.glyphs.expanded))
            vim.cmd(string.format("syn match %s /%s/", lt.hls.CollapsedGuideHL, marshal.glyphs.collapsed))
            -- set configured indent guide highlight
            vim.cmd(string.format("syn match %s /%s/", lt.hls.IndentGuideHL, marshal.glyphs.guide))
            for _, icon_data in pairs(webicons.icons) do
                local hl = "DevIcon" .. icon_data.name
                vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
            end
        end
    end
end

return M
