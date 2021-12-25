local M = {}

-- config is a global configuration object
-- for each module in the litee library.
--
-- config for a particular module is keyed
-- by the module's directory.
M.config = {
    icons = {},
    jumps = {},
    lsp = {},
    navi = {},
    notify = {
        enabled = true,
    },
    panel = {
        orientation = "left",
        panel_size = 30,
    },
    state = {},
    tree = {
        icon_set = "default",
        indent_guides = true
    }
}

return M
