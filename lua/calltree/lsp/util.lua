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

return M
