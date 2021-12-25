local commands = require('litee.lib.commands')
local config = require('litee.lib.config').config
local lib_hi = require('litee.lib.highlights')

local M = {}

local function merge_subconfig(component, user_subconfig)
    local subconfig = config[component]
    if subconfig == nil then
        return
    end

    for key, val in pairs(user_subconfig) do
        subconfig[key] = val
    end
end

function M.setup(user_config)
    if user_config ~= nil then
        for component, user_subconfig in pairs(user_config) do
            merge_subconfig(component, user_subconfig)
        end
    end

    -- setup default highlights
    lib_hi.setup_default_highlights()

    -- setup commands
    commands.setup()

    -- au to close popup with cursor moves or buffer is closed.
    vim.cmd("au CursorMoved,BufWinLeave,WinLeave * lua require('litee.lib.util.buffer').close_all_popups()")

    -- on resize cycle the panel to re-adjust window sizes.
    vim.cmd("au VimResized * lua require('litee.lib.panel.autocmds').on_resize()")

    -- will clean out any tree data for a tab when closed. only necessary
    vim.cmd([[au TabClosed * lua require('litee.lib.state.autocmds').on_tab_closed(vim.fn.expand('<afile>'))]])
end

return M
