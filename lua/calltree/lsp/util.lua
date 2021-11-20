local M = {}

M.multi_client_request = function(clients, method, params, handler, bufnr)
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

return M
