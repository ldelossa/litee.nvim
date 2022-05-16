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
        local base = M.basename(path)
        local diff = vim.fn.strlen(path) - (vim.fn.strlen(base)+1)
        local res = vim.fn.strpart(path, 0, diff)
        if vim.fn.strridx(path, "/") == #path-1 then
            return res
        else
            return res .. "/"
        end
end

function M.path_prefix_match(prefix, path)
    local idx = vim.fn.stridx(path, prefix)
    if idx == -1 then
        return false
    end
    return true
end

function M.swap_path_prefix(path, old_prefix, new_prefix)
    local new_path = vim.fn.substitute(path, old_prefix, new_prefix, "")
    return new_path
end

function M.strip_file_prefix(path)
    return vim.fn.substitute(path, "file://", "", "")
end

function M.add_file_prefix(path)
    vim.fn.substitute(path, "file://", "", "")
    return string.format("%s%s", "file://", path)
end

function M.strip_trailing_slash(path)
    if vim.fn.strridx(path, "/") == (vim.fn.strlen(path)-1) then
        return vim.fn.strpart(path, 0, vim.fn.strlen(path)-1)
    end
    return path
end

-- strip the prefix from the path, usually to make a
-- relative path, and ensure leading '/'
function M.strip_path_prefix(prefix, path)
    local new = vim.fn.substitute(path, prefix, "", "")
    if vim.fn.strridx(new, '/') == -1 then
        new = '/' .. new
    end
    return new
end

return M
