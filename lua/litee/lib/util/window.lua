local lib_state         = require('litee.lib.state')
local lib_tree_config   = require('litee.lib.config').config["tree"]
local lib_icons         = require('litee.lib.icons')
local lib_hi            = require('litee.lib.highlights')

local M = {}

-- a convenience function for setting up tree window highlights
-- suitable for being ran inside a "post_window_create"
-- function.
--
-- see lib.tree.register_component for more details.
function M.set_tree_highlights()
    local icon_set = nil 
    if lib_tree_config.icon_set == nil then
        icon_set = lib_icons["default"]
    else
        icon_set = lib_icons[lib_tree_config.icon_set]
    end
    -- set configured icon highlights
    for icon, hl in pairs(lib_icons.icon_hls) do
        vim.cmd(string.format("syn match %s /%s/", hl, icon_set[icon]))
    end
    -- set configured symbol highlight
    vim.cmd(string.format("syn match %s /%s/", lib_hi.hls.SymbolHL, [[\w]]))
    -- set configured expanded indicator highlights
    vim.cmd(string.format("syn match %s /%s/", lib_hi.hls.ExpandedGuideHL, icon_set["Expanded"]))
    vim.cmd(string.format("syn match %s /%s/", lib_hi.hls.CollapsedGuideHL, icon_set["Collapsed"]))
    -- set configured indent guide highlight
    vim.cmd(string.format("syn match %s /%s/", lib_hi.hls.IndentGuideHL, icon_set["Guide"]))
end

-- inside_component_win is a helper functions which
-- tells the caller if the currently focused window
-- is a litee.nvim registered component window.
function M.inside_component_win()
    local tab = vim.api.nvim_get_current_tabpage()
    local win = vim.api.nvim_get_current_win()
    local state = lib_state.get_state(tab)
    if state == nil then
        return false
    end
    local active_components = lib_state.get_active_components(tab)

    local in_litee_panel = false
    for _, active_component in ipairs(active_components) do
        if win == state[active_component].win then
            in_litee_panel = true
        end
    end

    return in_litee_panel
end

return M
