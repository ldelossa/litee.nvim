local M = {}

-- safe_encode returns a string which is safe to
-- use as a filesystem name.
--
-- this is helpful when encoding filesystem paths
-- to a string that can be used as a filename.
--
-- the encoding is just a sub-set of URL encoding.
--
-- @param str (string) The string to encode.
function M.safe_encode(str)
    str, _ = string.gsub(str, '/', '%%2F')
    str, _ = string.gsub(str, ' ', '%%20')
    str, _ = string.gsub(str, ':', '%%3A')
    return str
end

-- decodes a string encoded by safe_encode.
-- see safe_encode for details.
function M.safe_decode(str)
    str, _ = string.gsub(str, '%%2F', '/')
    str, _ = string.gsub(str, '%%20', ' ')
    str, _ = string.gsub(str, '%%3A', ':')
    return str
end

function M.is_dir(path)
    if vim.fn.isdirectory(path) == 0 then
        return false
    end
    return true
end

function M.file_exists(path)
    if vim.fn.filereadable(path) == 0 then
        return false
    end
    return true
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

-- provides the filename with no path details for
-- the provided uri.
function M.basename(uri)
    local final_sep = vim.fn.strridx(uri, "/")
    local uri_len   = vim.fn.strlen(uri)

    -- if its a dir, remove final "/"
    if final_sep+1 == uri_len then
        uri = vim.fn.strpart(uri, 0, uri_len-1)
        final_sep = vim.fn.strridx(uri, "/")
    end

    local dir = vim.fn.strpart(uri, final_sep+1, vim.fn.strlen(uri))
    return dir
end

function M.parent_dir(path)
    if M.is_dir(path) then
        local base = M.basename(path)
        local diff = vim.fn.strlen(path) - (vim.fn.strlen(base)+1)
        local res = vim.fn.strpart(path, 0, diff)
        return res
    elseif M.file_exists(path) then
        local base = M.basename(path)
        local diff = vim.fn.strlen(path) - vim.fn.strlen(base)
        local dir  = vim.fn.strpart(path, 0, diff)

        base = M.basename(dir)
        -- +1 to base because it returns the file's parent owning directory
        -- without a slash
        diff = vim.fn.strlen(dir) - (vim.fn.strlen(base)+1)
        return vim.fn.strpart(path, 0, diff)
    else
        return nil
    end
end

function M.strip_file_prefix(path)
    return vim.fn.substitute(path, "file://", "", "")
end

return M
