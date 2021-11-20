local tree = require('calltree.tree')
local ct = require('calltree')
local lsp_util = require('calltree.lsp.util')

local M = {}

M.glyphs = {
    expanded= "▼",
    collapsed= "▶",
    separator = "•"
}

-- buf_line_map keeps a mapping between marshaled
-- buffer lines and the node objects
M.buf_line_map = {}

-- marshal_node takes a node and marshals
-- it into a UI buffer line.
--
-- node : tree.Node - the node to marshal into
-- a buffer line.
--
-- returns:
--    string - the marshalled string
function M.marshal_node(node)
    local str = ""
    local glyph
    if node.expanded then
        glyph = M.glyphs["expanded"]
    else
        glyph = M.glyphs["collapsed"]
    end

    -- prefer using workspace symbol details if available.
    -- fallback to callhierarchy object details.
    local name = ""
    local kind = ""
    if node.symbol ~= nil then
        name = node.symbol.name
        kind = vim.lsp.protocol.SymbolKind[node.symbol.kind]
    else
        name = node.name
        kind = vim.lsp.protocol.SymbolKind[node.kind]
    end

    -- add spacing up to node's depth
    for _=1, node.depth do
        str = str .. " "
    end

    -- ▶ Func1
    str = str .. glyph
    if ct.config.icons ~= "none" then
        -- ▶ Func1 []
        str = str .. " " .. "[" .. ct.active_icon_set[kind] .. "]" .. " " .. name .. " "
    else
        -- ▶ Func1 • [Function]
        str = str .. " " .. "[" .. kind .. "]" .. " " .. M.glyphs.separator .. " " .. name .. " "
    end

    if ct.config.layout == "bottom" or 
        ct.config.layout == "top" then
        -- now we got all the room in the world, add detail
        path = lsp_util.relative_path_from_uri(node.call_hierarchy_obj.uri)
        -- ▶ Func1 [] • relative/path/to/file
        -- or
        -- ▶ Func1 • [Function] • relative/path/to/file
        str = str .. M.glyphs.separator .. " " .. path
    end

    return str
end

-- marshal_line takes a UI buffer line and
-- marshals it into a tree.Node.
--
-- linenr : {row,col} - the UI buffer line typically returned by
-- vim.api.nvim_win_get_cursor(calltree_win_handle)
--
-- returns:
--   tree.Node - the marshaled tree.Node table.
function M.marshal_line(linenr)
    local node = M.buf_line_map[linenr[1]]
    return node
end

-- marshal_tree recursively marshals all nodes from the provided root
-- down into UI lines.
--
-- buf_handle : buffer_handle - the buffer to write the marshalled tree
-- to
--
-- lines : array of strings - recursive accumlator of marshaled lines.
-- call this function with an empty array.
--
-- node : tree.Node - the root node of the tree where marshaling will 
-- begin.
function M.marshal_tree(buf_handle, lines, node)
    if node.depth == 0 then
        -- create a new line mapping
        buf_line_map = {}
    end
    table.insert(lines, M.marshal_node(node))
    M.buf_line_map[#lines] = node

    -- if we are an expanded node or we are the root (always expand)
    -- recurse
    if node.expanded  or node.depth == 0 then
        for _, child in ipairs(node.children) do
            M.marshal_tree(buf_handle, lines, child)
        end
    end

    -- we are back at the root, all lines are inserted, lets write it out
    -- to the buffer
    if node.depth == 0 then
        vim.api.nvim_buf_set_option(buf_handle, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf_handle, 0, -1, true, {})
        vim.api.nvim_buf_set_lines(buf_handle, 0, #lines, false, lines)
        vim.api.nvim_buf_set_option(buf_handle, 'modifiable', false)
    end
end

return M
