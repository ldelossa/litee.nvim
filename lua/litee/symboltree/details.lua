local lib_util = require('litee.lib.util')

local M = {}

function M.details_func(_, node)
    local lines = {}

    local name = node.name
    local detail = node.document_symbol.detail
    local children = #node.children
    local file = lib_util.relative_path_from_uri(node.uri)
    local kind = vim.lsp.protocol.SymbolKind[node.document_symbol.kind]

    table.insert(lines, "=== Document Symbol ===")
    table.insert(lines, "Name: " .. name)
    if kind ~= nil then
        table.insert(lines, "Kind: " .. kind)
    end
    if file ~= nil then
        table.insert(lines, "File: " .. file)
    end
    table.insert(lines, "Detail: " .. detail)
    if children ~= nil then
        table.insert(lines, "Children: " .. children)
    end

    return lines
end

return M
