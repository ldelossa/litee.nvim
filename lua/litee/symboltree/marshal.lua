local config = require('litee.symboltree.config').config
local lib_icons = require('litee.lib.icons')

local M = {}

-- marshal_func is a function which returns the necessary
-- values for marshalling a calltree node into a buffer
-- line.
function M.marshal_func(node)
    local icon_set = nil
    if config.icon_set ~= nil then
        icon_set = lib_icons[config.icon_set]
    end
    local name, detail, icon = "", "", ""
    if node.document_symbol ~= nil then
        name = node.document_symbol.name
        local kind = vim.lsp.protocol.SymbolKind[node.document_symbol.kind]
        if kind ~= "" then
            if config.icon_set ~= nil then
                icon = icon_set[kind]
            else
                icon = "[" .. kind .. "]"
            end
        end
        if node.document_symbol.detail ~= nil then
            detail = node.document_symbol.detail
        end
    end

    -- all nodes in a symboltree are known ahead of time,
    -- so if a node has no children leave off the expand_guide
    -- indicating it's a leaf without having to expand the node.
    if #node.children == 0 then
        return name, detail, icon, " "
    else
        return name, detail, icon
    end
end

return M
