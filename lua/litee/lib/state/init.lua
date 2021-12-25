local M = {}

-- registry is a per-tab-page registry for
-- state.
--
-- state defines information necessary for
-- a UI component to be used with litee-lib.
--
-- the state structure is as follows:
-- "component" = {
--     buf = 0,
--     win = 0,
--     tab = 0,
--     tree = 0,
--     win_dimensions = {0, 0},
--     invoking_win = 0,
--     active_lsp_clients = {list of lsp clients},
--     (component specific fields)...
-- }
--
-- a component using the registry should consider
-- only it's portion of the state as writable but
-- is free to pass the full state object to other
-- lib methods.
M.registry = {}

-- get_state returns the state for the given tab
-- @param tab (int) The tab ID to retrieve state for.
-- @returns state (table) The state as defined by this
-- module.
function M.get_state(tab)
    return M.registry[tab]
end

-- get_state_ctx is similiar to get_state but obtains
-- the tab ID from the current Neovim context.
function M.get_state_ctx()
    local win    = vim.api.nvim_get_current_win()
    local tab    = vim.api.nvim_win_get_tabpage(win)
    local state = M.registry[tab]
    return state
end

-- get_component_state returns the state for a
-- particular component that's utilizing lib state.
--
-- @param tab (int) The tab ID to retrieve state for.
-- @param component (string) The name of the component
-- storing its state.
function M.get_component_state(tab, component)
    local s = M.registry[tab]
    if s == nil then return nil end
    return s[component]
end

-- put_state writes a state table to the registry for
-- later retrieval.
--
-- this method overwrites all current state so use with
-- caution.
-- @param tab (int) The tab ID to associate the provided state
-- with
-- @param state (table) The state as defined by this
-- module.
-- @returns state (table) The updated state table as defined
-- by this module
function M.put_state(tab, state)
    M.registry[tab] = state
    return M.registry[tab]
end


-- put_component_state will store the component state for
-- later retrieval.
--
-- @param tab (int) The tab ID to associate the provided state
-- with
-- @param component (string) The name of the component
-- storing its state table.
-- @param state (table) The state as defined by this
-- module. This table should not include the component
-- name as a leading key.
-- @returns state (table) The updated state table as defined
-- by this module
function M.put_component_state(tab, component, state)
    local s = M.registry[tab]
    if s == nil then
        s = {}
        M.registry[tab] = s
    end
    s[component] = state
    return s
end

function M.get_active_components(tab)
    local s = M.registry[tab]
    local components = {}
    for component, _ in pairs(s) do
        table.insert(components, component)
    end
    return components
end

function M.get_type_from_buf(tab, buf)
    local state = M.registry[tab]
    if state == nil then
        return nil
    end
    for component, s in pairs(state) do
        if buf == s.buf then
            return component
        end
    end
    return nil
end

M.get_tree_from_buf = function(tab, buf)
    local state = M.registry[tab]
    if state == nil then
        return nil
    end
    local type = M.get_type_from_buf(tab, buf)
    if type == nil then
        return nil
    end
    return state[type].tree
end

return M
