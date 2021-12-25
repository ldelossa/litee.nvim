local config = require('litee.symboltree.config').config
local lib_icons = require('litee.lib.icons')
local lib_util = require('litee.lib.util')

local M = {}

-- marshal_func is a function which returns the necessary
-- values for marshalling a calltree node into a buffer
-- line.
function M.marshal_func(node)
    local icon_set = nil
    if config.icon_set ~= nil then
        icon_set = lib_icons[config.icon_set]
    end
    local location = lib_util.resolve_location(node)
    local name, detail, icon = "", "", ""
    -- prefer the symbol info if available
    if node.symbol ~= nil then
        name = node.symbol.name
        local kind = vim.lsp.protocol.SymbolKind[node.symbol.kind]
        if kind ~= "" then
            if icon_set ~= nil then
                icon = icon_set[kind]
            else
                icon = "[" .. kind .. "]"
            end
        end
        local file, relative = lib_util.relative_path_from_uri(location.uri)
        if relative then
            detail = file
        elseif node.symbol.detail ~= nil then
            detail = node.symbol.detail
        end
    elseif node.call_hierarchy_item ~= nil then
        name = node.name
        local kind = vim.lsp.protocol.SymbolKind[node.call_hierarchy_item.kind]
        if kind ~= "" then
            if icon_set ~= nil  then
                icon = icon_set[kind]
            else
                icon = "[" .. kind .. "]"
            end
        end
        local file, relative = lib_util.relative_path_from_uri(location.uri)
        if relative then
            detail = file
        elseif node.call_hierarchy_item.detail ~= nil then
            detail = node.call_hierarchy_item.detail
        end
    end
    return name, detail, icon
end

return M
