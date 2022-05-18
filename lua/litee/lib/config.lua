local M = {}

-- config is a global configuration object
-- for each module in the litee library.
--
-- config for a particular module is keyed
-- by the module's directory name.
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
    term = {
        position = "bottom",
        term_size = 15,
        map_resize_keys = true,
    },
    tree = {
        icon_set = "default",
        icon_set_custom = nil,
        indent_guides = true
    }
}

return M
