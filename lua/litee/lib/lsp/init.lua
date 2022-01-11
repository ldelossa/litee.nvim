local lib_notify = require('litee.lib.notify')
local lib_tree_node = require('litee.lib.tree.node')

local M = {}

-- multi_client_request makes an LSP request to multiple clients.
--
-- the signature is the same as an individual LSP client request method
-- but takes a list of clients as the first argument.
function M.multi_client_request(clients, method, params, handler, bufnr)
    for _, client in ipairs(clients) do
        if not client.supports_method(method) then
            goto continue
        end
        client.request(method, params, handler, bufnr)
        ::continue::
    end
end

-- gather_sybmbols_async_handler is the async handler
-- for gather_symbols_async method and incrementally
-- builds a tree of symbols from a workspace symbols
-- request.
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

-- gather_symbols_async will acquire a list of workspace symbols given
-- a tree of call_hierarchy items.
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
-- @param clients (table) All active lsp clients
-- @param node (table) A node with a "call_hierarhcy_item"
-- field we are acquiring workspace symbols for.
-- @param bufnr (int) An window handle to the buffer
-- containing the node.
-- @returns (table) the SymbolInformation LSP structure, see:
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#symbolInformation
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

-- conv_symbolinfo_to_docsymbol will convert a SymbolInformation
-- model to a DocumentSymbol mode.
--
-- this is handy when working with documentSymbol requests and
-- users do not want to handle two data models in their code.
--
-- @param symbolinfo (table) A SymbolInformation structure as
-- defined by the LSP specification.
-- @returns (table) A DocumentSymbol structure as defined by
-- the LSP specification.
function M.conv_symbolinfo_to_docsymbol(symbolinfo)
    local document_symbol = {}

    -- these are mandatory fields per the LSP spec,
    -- return nil if they arent there.
    if
        symbolinfo.name == nil or
        symbolinfo.kind == nil or
        symbolinfo.location == nil or
        symbolinfo.location.range == nil
    then
        return nil
    end

    document_symbol.name    = symbolinfo.name
    document_symbol.kind    = symbolinfo.kind
    document_symbol.range   = symbolinfo.location.range
    document_symbol.children = {}
    document_symbol.details = ""
    document_symbol.tags = {}
    document_symbol.deprecated = false
    document_symbol.selectionRange = symbolinfo.location.range
    return document_symbol
end

return M
