local lib_util = require('litee.lib.util')

local M = {}

local direction_map = {
    from = "Incoming",
    to   = "Outgoing",
}

function M.details_func(state, node)
    local lines = {}
    local component_state = state["calltree"]

    local name = node.name
    local direction = direction_map[component_state.direction]
    local references = nil; references = (function() if node.references ~= nil then return #node.references end end)()
    local detail = node.call_hierarchy_item.detail
    local children = nil
    if node.expanded then
        children = #node.children
    end
    local file = lib_util.relative_path_from_uri(node.call_hierarchy_item.uri)
    local kind = vim.lsp.protocol.SymbolKind[node.call_hierarchy_item.kind]

    if direction == nil then
        direction = ""
    end
    table.insert(lines, "=== " .. direction .. " Call Hierarchy Item ===")
    table.insert(lines, "Name: " .. name)

    if kind ~= nil then
        table.insert(lines, "Kind: " .. kind)
    end

    if file ~= nil then
        table.insert(lines, "File: " .. file)
    end

    table.insert(lines, "Detail: " .. detail)

    if references ~= nil then
        table.insert(lines, "References: " .. references)
    end

    if children ~= nil then
        table.insert(lines, "Children: " .. children)
    end

    return lines
end

return M
