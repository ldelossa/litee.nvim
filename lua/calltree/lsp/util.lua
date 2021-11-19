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

return M
