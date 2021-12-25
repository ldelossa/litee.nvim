local config    = require('litee.filetree.config').config
local lib_util  = require('litee.lib.util')
local lib_icons = require('litee.lib.icons')
local devicons  = require("nvim-web-devicons")

local M = {}

-- provides the filename with no path details for
-- the provided uri.
local function resolve_file_name(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local dir = vim.fn.strpart(uri, final_sep+1, vim.fn.strlen(uri))
    return dir
end

-- marshal_func is a function which returns the necessary
-- values for marshalling a calltree node into a buffer
-- line.
function M.marshal_func(node)
    local icon_set = nil
    if config.icon_set ~= nil then
        icon_set = lib_icons[config.icon_set]
    end
    local name, detail, icon = "", "", ""

    name = node.name

    -- this option will make all filetree entries show their relative paths
    -- from root. usefule for bottom/top layouts.
    if config.relative_filetree_entries then
        local file, relative = lib_util.relative_path_from_uri(node.filetree_item.uri)
        if relative then
            name = file
        end
    end

    if node.depth == 0 then
        name = resolve_file_name(node.filetree_item.uri)
    end

    -- we know unless the node is a dir, it will have no
    -- children so leave off the expand guide to display
    -- a leaf without having to evaluate this node further.
    if not node.filetree_item.is_dir then
        if config.use_web_devicons then
            icon = devicons.get_icon(node.name, nil, {default=true})
        end
        local expand_guide = " "
        return name, detail, icon, expand_guide
    end

    if config.use_web_devicons then
        icon = devicons.get_icon("dir")
    end
    return name, detail, icon
end

return M
