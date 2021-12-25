local lib_notify = require('litee.lib.notify')
local lib_tree_node = require('litee.lib.tree.node')

local M = {}

function M.multi_client_request(clients, method, params, handler, bufnr)
    for _, client in ipairs(clients) do
        if not client.supports_method(method) then
            goto continue
        end
        client.request(method, params, handler, bufnr)
        ::continue::
    end
end

function M.gather_symbols_async_handler(node, co)
    return function(err, result, _, _)
        if err ~= nil then
            coroutine.resume(co, nil)
            return
        end
        if result == nil then
            coroutine.resume(co, nil)
            return
        end

        local start_line, uri = "", ""
        if node.call_hierarchy_item ~= nil then
            start_line = node.call_hierarchy_item.range.start.line
            uri = node.call_hierarchy_item.uri
        elseif node.document_symbol ~= nil then
            start_line = node.document_symbol.range.start.line
            uri = node.uri
        end

        for _, res in ipairs(result) do
            if
                res.location.uri == uri and
                res.location.range.start.line ==
                start_line
            then
                coroutine.resume(co, res)
                return
            end
        end
        coroutine.resume(co, nil)
    end
end

function M.gather_symbols_async(root, children, component_state, callback)
    local co = nil
    local all_nodes = {}
    table.insert(all_nodes, root)
    for _, child in ipairs(children) do
        table.insert(all_nodes, child)
    end
    co = coroutine.create(function()
        for i, node in ipairs(all_nodes) do
            local params = {
                query = node.name,
            }
            lib_notify.notify_popup("gathering symbols [" .. i .. "/" .. #all_nodes .. "]", "warning")
            M.multi_client_request(
                component_state.active_lsp_clients,
                "workspace/symbol",
                params,
                -- handler will call resume for this co.
                M.gather_symbols_async_handler(node, co),
                component_state.invoking_win
            )
            node.symbol = coroutine.yield()
            lib_notify.close_notify_popup()
        end
        callback()
    end)
    coroutine.resume(co)
end

-- symbol_from_node attempts to extract the workspace
-- symbol the node represents.
--
-- clients : table - all active lsp clients
--
-- node : tree.Node - the node which we are resolving
-- a symbol for.
--
-- bufnr : buffer_handle - the calltree buffer handle
--
-- returns:
--  table - the SymbolInformation LSP structure
--  https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#symbolInformation
function M.symbol_from_node(clients, node, bufnr)
    local params = {
        query = node.name,
    }
    for _, client in ipairs(clients) do
        if not client.supports_method("workspace/symbol") then
            goto continue
        end
        -- not all LSPs are optimized, specially ones in early development, set
        -- this timeout high.
        local out = client.request_sync("workspace/symbol", params, 5000, bufnr)
        if out == nil then
            goto continue
        end
        if out.err ~= nil or (out.result == nil or #out.result <= 0) then
            goto continue
        end
        for _, res in ipairs(out.result) do
            if
                res.uri == node.uri and
                res.location.range.start.line ==
                node.call_hierarchy_item.range.start.line
            then
                return res
            end
        end
        ::continue::
    end
    return nil
end

local function keyify_document_symbol(document_symbol)
    if document_symbol ~= nil then
        local key = document_symbol.name .. ":" ..
                    document_symbol.kind .. ":" ..
                    document_symbol.range.start.line
        return key
    end
end

function M.build_recursive_symbol_tree(depth, document_symbol, parent, prev_depth_table)
        local node = lib_tree_node.new_node(
            document_symbol.name,
            keyify_document_symbol(document_symbol),
            depth
        )
        node.document_symbol = document_symbol
        if parent == nil then
            -- if no parent the document_symbol is our synthetic one and carries the uri
            -- which will be recursively added to all children nodes in the document symboltree.
            node.uri = document_symbol.uri
        end
        -- if we have a previous depth table search it for an old reference of self
        -- and set expanded state correctly.
        if prev_depth_table ~= nil and prev_depth_table[depth] ~= nil then
            for _, child in ipairs(prev_depth_table[depth]) do
                if child.key == node.key then
                    node.expanded = child.expanded
                end
            end
        end
        if parent ~= nil then
            -- the parent will be carrying the uri for the document symbol tree we are building.
            node.uri = parent.uri
            table.insert(parent.children, node)
        end
        if document_symbol.children ~= nil then
            for _, child_document_symbol in ipairs(document_symbol.children) do
            M.build_recursive_symbol_tree(depth+1, child_document_symbol, node, prev_depth_table)
            end
        end
        return node
end

return M
