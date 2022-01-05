local lib_state = require('litee.lib.state')
local config = require('litee.lib.config').config
local lib_notify = require('litee.lib.notify')
local lib_util = require('litee.lib.util')

local M = {}

-- components maps a unique component map
-- with a set of callbacks (see M.register_component)
--
-- the order in which components exist in this map
-- determines the component's order in the panel.
local components = {}

-- register_component adds a component to
-- the panel.
--
-- the panel's layout is determined by the
-- order in which components are registered.
--
-- registering a component *must* include a "pre_window_create"
-- callback and can optionally provide a "post_window_create"
-- callback.
--
-- @param component (string) Unique name for a component,
-- subsequent calls for a unique component will over write
-- previous
-- @param pre_window_create (function(state)) A callback which must
-- prepare the provided state object, as defined by lib/state.lua
-- with a valid buffer. The callback is free to perform any other
-- tasks such as writing to the buffer if desired. The buffer
-- ID should be stored in the component's "buf" field in state
-- and will be displayed in the appropriate panel's window on
-- toggle. This callback can return false when the window should
-- not be opened in the panel and true to indicate it should.
-- @param post_window_create (function(state)) A callback which can customize
-- the component window further after being displayed in the panel. Useful for
-- setting up component-specific window options and winhl configurations.
-- The state[component].win field will be populated with the window id of the
-- panel window for further configuration.
function M.register_component(component, pre_window_create, post_window_create)
    components[component] = {
        pre = pre_window_create,
        post = post_window_create
    }
end

-- toggle_panel will toggle the panel open and
-- close in the common case. Arguments can be
-- used to alter how the toggle takes place.
--
-- @param state (table) The full state table as defined
-- in lib/state.lua
-- @param keep_open (bool) If the panel is currently open
-- perform a no-op, useful when the caller only wants to
-- confirm the panel is present.
-- @param cycle (bool) Close and open the panel in succession,
-- useful when resizing events occur to snap the panel back
-- into the appropriate size.
function M.toggle_panel(state, keep_open, cycle)
    local cur_win = vim.api.nvim_get_current_win()
    -- if state is nil then try to grab it from current tab.
    if state == nil then
        local cur_tab = vim.api.nvim_get_current_tabpage()
        state = lib_state.get_state(cur_tab)
        if state == nil then
            lib_notify.notify_popup_with_timeout("Must open a litee component before toggling the panel.", 1750, "error")
            return
        end
    end
    local component_open = false
    local component_cursors = {}
    for component, _ in pairs(components) do
        if
            state[component] ~= nil
            and state[component].win ~= nil
            and vim.api.nvim_win_is_valid(state[component].win)
        then
            component_open = true
            component_cursors[component] = vim.api.nvim_win_get_cursor(state[component].win)
        end
    end

    -- components are open, close them, recording its dimensions
    -- for proper restore.
    if
        cycle or
        not keep_open
    then
        if component_open then
            for component, _ in pairs(components) do
                if
                    state[component] ~= nil
                    and state[component].win ~= nil
                    and vim.api.nvim_win_is_valid(state[component].win)
                then
                    state[component].win_dimensions = {
                        height = vim.api.nvim_win_get_height(state[component].win),
                        width = vim.api.nvim_win_get_width(state[component].win)
                    }
                    vim.api.nvim_win_close(state[component].win, true)
                end
            end
            if cycle then
                M.toggle_panel(state, false, false)
            end
            return
        end
    end

    for component, callbacks in pairs(components) do
        if state[component] ~= nil then
            if callbacks.pre(state) then
                M._open_window(component, state)
                -- restore cursor positions if possible.
                if component_cursors[component] ~= nil then
                    lib_util.safe_cursor_reset(
                        state[component].win,
                        component_cursors[component]
                    )
                end
            end
        end
    end
    vim.api.nvim_set_current_win(cur_win)
end

-- Similar to toggle_panel but retrieves state from
-- Neovim's current context.
function M.toggle_panel_ctx(keep_open, cycle)
    local state = lib_state.get_state_ctx()
    if state == nil then
        return
    end
    M.toggle_panel(state, keep_open, cycle)
end

-- realize_current_and_desired will determine the current and desired layouts
-- given a requested window type to open.
--
-- @param check_component (string) The identifier of a registered component
-- which is checked against the current layout.
-- @param desired_compoent The identifier of a registered component which is
-- the desired component to add/display in the panel.
-- @param current_layout (list of int) A list of window ids currently comprising
-- any open panel components.
-- @param desired_layout (list of string) A list of panel components desired to be
-- displayed.
-- @param state (table) A table of state as defined by lib/state.lua
--
-- @returns continue (bool) A bool which informs the caller to stop processing
-- the declarative evaluation of the panel layout. This occurs if the desired
-- component is already being displayed.
local function realize_current_and_desired(check_component, desired_component, current_layout, desired_layout, state)
    local current_tabpage = vim.api.nvim_win_get_tabpage(
        vim.api.nvim_get_current_win()
    )

    -- check if the desired window exists.
    if
        state[check_component] == nil or
        state[check_component].win == nil or
        (not vim.api.nvim_win_is_valid(state[check_component].win))
    then
        if check_component == desired_component then
            -- checked window is invalid, its also the desired window to open
            -- add it to desired layout.
            table.insert(desired_layout, desired_component)
        end
        return true
    end
    local win = state[check_component].win

    local win_tabpage = vim.api.nvim_win_get_tabpage(win)
    -- desired window type is already open on current tabpage, noop
    if check_component == desired_component and current_tabpage == win_tabpage then
        return false
    end
    -- the checked window type is open and on the current tab, unconditionally add it to
    -- desired_layout to preserve it existence.
    if current_tabpage == win_tabpage then
        table.insert(current_layout, win)
        table.insert(desired_layout, check_component)
    -- the window type we are checking is also the desired window type, but its
    -- opened in another tab, close it and add desired window type to desired layout.
    -- it will be opened on the current tab.
    elseif check_component == desired_component then
        vim.api.nvim_win_close(win, true)
        table.insert(desired_layout, desired_component)
    end
    return true
end

-- open_window will first compute the current UI layout
-- then compute the desired layout and finally call
-- _setup_window with both.
--
-- @param desired_component (string) The registered component
-- which should be opened in the panel.
--
-- @param state (table) The state table as defined by
-- lib/state.lua
function M._open_window(desired_component, state)
    -- holds open window handles we'll reuse
    local current_layout = {}
    -- holds the window types to ensure present in the ui
    local desired_layout = {}

    for check_component, _ in pairs(components) do
        if not realize_current_and_desired(check_component, desired_component, current_layout, desired_layout, state) then
            return
        end
    end

    M._setup_window(current_layout, desired_layout, state)
end

-- open_to opens the panel and moves the cursor to the requested
-- component.
--
-- if open_to is called when nvim is focused inside
-- the component the focus will be switched back to the window the ui
-- was invoked from.
--
-- @param component (string) The component to open to.
-- @param state (table) The state table as defined by
-- lib/state.lua
-- @return opened (bool) Whether the panel has been open.
function M.open_to(component, state)
    if state[component] == nil then
        -- notify.notify_popup_with_timeout("Cannot toggle panel until ..", 1750, "error")
        return false
    end
    local current_win = vim.api.nvim_get_current_win()
    if  current_win == state[component].win then
        vim.api.nvim_set_current_win(state[component].invoking_win)
        return
    end
    if
        state[component].win ~= nil
        and vim.api.nvim_win_is_valid(state[component].win)
    then
        vim.api.nvim_set_current_win(state[component].win)
        return
    end
    M.toggle_panel(state, true, false)
    vim.api.nvim_set_current_win(state[component].win)
end

-- setup_window evaluates the current layout and the desired layout
-- and opens the necessary windows to obtain the desired layout.
--
-- @param current_layout (list of int) A list of win handles comprising
-- the currently opened panel windows. If present, they will be reused
-- to realize the desired_layout.
-- @param desired_layout (list of string) A list of components desired
-- to be opened and present in the panel.
-- @param state (table) The state table as defined by
-- lib/state.lua
function M._setup_window(current_layout, desired_layout, state)
    for i, component in ipairs(desired_layout) do
        local buffer_to_set = nil
        local dimensions_to_set = nil

        buffer_to_set = state[component].buf
        if state[component].win_dimensions ~= nil then
            dimensions_to_set = state[component].win_dimensions
        end

        -- we can reuse the current layout windows
        if i <= #current_layout then
            vim.api.nvim_win_set_buf(current_layout[i], buffer_to_set)
            state[component].win = current_layout[i]
            vim.api.nvim_set_current_win(state[component].win)
            goto continue
        end

        -- we are out of open windows, so we need to create some

        if #current_layout == 0 then
            -- there is no current layout, so just do a botright or equivalent
            if config["panel"].orientation == "left" then
                vim.cmd("topleft vsplit")
                vim.cmd("vertical resize " ..
                            config["panel"].panel_size)
            elseif config["panel"].orientation == "right" then
                vim.cmd("botright vsplit")
                vim.cmd("vertical resize " ..
                            config["panel"].panel_size)
            elseif config["panel"].orientation == "top" then
                vim.cmd("topleft split")
                vim.cmd("resize " ..
                            config["panel"].panel_size)
            elseif config["panel"].orientation == "bottom" then
                vim.cmd("botright split")
                vim.cmd("resize " ..
                            config["panel"].panel_size)
            end
            goto set
        end

        -- cursor currently in a reused window, split according to layout config
        if config["panel"].orientation == "left" then
            vim.cmd("below split")
        elseif config["panel"].orientation == "right" then
            vim.cmd("below split")
        elseif config["panel"].orientation == "top" then
            vim.cmd("vsplit")
        elseif config["panel"].orientation == "bottom" then
            vim.cmd("vsplit")
        end

        ::set::
        cur_win = vim.api.nvim_get_current_win()
        state[component].win = cur_win
        vim.api.nvim_win_set_buf(state[component].win, buffer_to_set)
        vim.api.nvim_win_set_option(state[component].win, 'number', false)
        vim.api.nvim_win_set_option(state[component].win, 'cursorline', true)
        vim.api.nvim_win_set_option(state[component].win, 'wrap', false)
        vim.api.nvim_win_set_option(state[component].win, 'winfixwidth', true)
        vim.api.nvim_win_set_option(state[component].win, 'winfixheight', true)
        if
            dimensions_to_set ~= nil and
            dimensions_to_set.width ~= nil and
            dimensions_to_set.height ~= nil
        then
            if (config["panel"].orientation == "left" or config["panel"].orientation == "right") then
                vim.api.nvim_win_set_width(cur_win, dimensions_to_set.width)
            else
                vim.api.nvim_win_set_height(cur_win, dimensions_to_set.height)
            end
        else
            dimensions_to_set = {}
            dimensions_to_set.height = vim.api.nvim_win_get_height(cur_win)
            dimensions_to_set.wdith  = vim.api.nvim_win_get_width(cur_win)
            state[component].dimensions = dimensions_to_set
        end

        ::continue::
        if components[component].post ~= nil then
            components[component].post(state)
        end
    end
end

return M
