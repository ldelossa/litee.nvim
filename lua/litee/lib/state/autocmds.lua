local lib_tree  = require('litee.lib.tree')
local lib_state = require('litee.lib.state')

local M = {}

M.on_tab_closed = function(tab)
    local state = lib_state.get_state(tab)
    if state == nil then
        return
    end
    for _, s in pairs(state) do
        if s ~= nil then
            lib_tree.remove_tree(s.tree)
        end
    end
    lib_state.put_state(tab, nil)
end

return M
