local tree_node = require('calltree.tree.node')
local notify = require('calltree.ui.notify')
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

function M.relative_path_from_uri(uri)
    local cwd = vim.fn.getcwd()
    local uri_path = vim.fn.substitute(uri, "file://", "", "")
    local idx = vim.fn.stridx(uri_path, cwd)
    if idx == -1 then
        -- we can't resolve a relative path, just give the
        -- full path to the file.
        return uri_path, false
    end
    return vim.fn.substitute(uri_path, cwd .. "/", "", ""), true
end

function M.absolute_path_from_uri(uri)
    local uri_path = vim.fn.substitute(uri, "file://", "", "")
    return uri_path
end

function M.resolve_relative_file_path(node)
    if node.symbol ~= nil then
        local uri = node.symbol.location.uri
        return M.relative_path_from_uri(uri)
    elseif node.call_hierarchy_item ~= nil then
        local uri = node.call_hierarchy_item.uri
        return M.relative_path_from_uri(uri)
    elseif node.document_symbol ~= nil then
        local uri = node.uri
        return M.relative_path_from_uri(uri)
    else
        return nil
    end

end

function M.resolve_absolute_file_path(node)
    if node.symbol ~= nil then
        local uri = node.symbol.location.uri
        return M.absolute_path_from_uri(uri)
    elseif node.call_hierarchy_item ~= nil then
        local uri = node.call_hierarchy_item.uri
        return M.absolute_path_from_uri(uri)
    elseif node.document_symbol ~= nil then
        local uri = node.uri
        return M.absolute_path_from_uri(uri)
    else
        return nil
    end
end

function M.resolve_location(node)
    local location = nil
    if node.symbol ~= nil then
        location = node.symbol.location
    elseif node.call_hierarchy_item ~= nil then
        location = {
            uri = node.call_hierarchy_item.uri,
            range = node.call_hierarchy_item.range
        }
    elseif node.document_symbol ~= nil then
        location = {
            uri = node.uri,
            range = node.document_symbol.selectionRange
        }
    end
    return location
end

function M.resolve_hover_params(node)
    local params = {}
    if node.symbol ~= nil then
        params.textDocument = {
            uri = node.symbol.location.uri
        }
        params.position = {
            line = node.symbol.location.range.start.line,
            character = node.symbol.location.range.start.character
        }
    elseif node.call_hierarchy_item ~= nil then
        params.textDocument = {
            uri = node.call_hierarchy_item.uri
        }
        params.position = {
            line = node.call_hierarchy_item.range.start.line,
            character = node.call_hierarchy_item.range.start.character
        }
    elseif node.document_symbol ~= nil then
        params.textDocument = {
            uri = node.uri
        }
        params.position = {
            line = node.document_symbol.selectionRange.start.line,
            character = node.document_symbol.selectionRange.start.character
        }
    else
        return nil
    end
    return params
end

function M.resolve_symbol_kind(node)
    if node.symbol ~= nil then
        return vim.lsp.protocol.SymbolKind[node.symbol.kind]
    elseif node.call_hierarchy_item ~= nil then
        return vim.lsp.protocol.SymbolKind[node.call_hierarchy_item.kind]
    elseif node.document_symbol ~= nil then
        return vim.lsp.protocol.SymbolKind[node.document_symbol.kind]
    else
        return nil
    end
end

function M.resolve_detail(node)
    if node.symbol ~= nil then
        return node.symbol.detail
    elseif node.call_hierarchy_item ~= nil then
        return node.call_hierarchy_item.detail
    elseif node.document_symbol ~= nil then
        return node.document_symbol.detail
    else
        return nil
    end
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

function M.gather_symbols_async(root, children, ui_state, callback)
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
            notify.notify_popup("gathering symbols [" .. i .. "/" .. #all_nodes .. "]", "warning")
            M.multi_client_request(
                ui_state.active_lsp_clients,
                "workspace/symbol",
                params,
                -- handler will call resume for this co.
                M.gather_symbols_async_handler(node, co),
                ui_state.invoking_calltree_win
            )
            node.symbol = coroutine.yield()
            notify.close_notify_popup()
        end
        callback()
    end)
    coroutine.resume(co)
end

function M.build_recursive_symbol_tree(depth, document_symbol, parent, prev_depth_table)
        local node = tree_node.new(
            document_symbol.name,
            depth,
            nil,
            nil,
            document_symbol
        )
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
