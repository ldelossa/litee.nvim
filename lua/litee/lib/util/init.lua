local M = {}

function M.absolute_path_from_uri(uri)
    local uri_path = vim.fn.substitute(uri, "file://", "", "")
    return uri_path
end

-- safe_cursor_reset will attempt to move the
-- cursor to `linenr`, if the provided `linenr`
-- would overflow the buffer the cursor will
-- safely be placed at the lowest available
-- buffer line.
function M.safe_cursor_reset(win, linenr)
    if
        win == nil
        or not vim.api.nvim_win_is_valid(win)
        or linenr == nil
    then
        return
    end
    local lc = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
    if lc < linenr[1] then
        linenr[1] = lc
    end
    vim.api.nvim_win_set_cursor(win, linenr)
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
    elseif node.filetree_item ~= nil then
        local range = {}
        range["start"] = { line = 0, character = 0}
        range["end"] = { line = 0, character = 0}
        location = {
            uri = "file://" .. node.filetree_item.uri,
            range = range
        }
    end
    return location
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

return M
