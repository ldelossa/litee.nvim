local tree = require('calltree.tree')
local ct = require('calltree')
local lsp_util = require('calltree.lsp.util')

local M = {}

M.glyphs = {
    expanded= "▼",
    collapsed= "▶",
    separator = "•"
}

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

    local kind = vim.lsp.protocol.SymbolKind[node.kind]

    -- add spacing up to node's depth
    for _=1, node.depth do
        str = str .. " "
    end

    -- ▶ Func1
    str = str .. glyph .. " " .. node.name
    if ct.config.icons ~= "none" then
        -- ▶ Func1[]
        str = str .. "[" .. ct.active_icon_set[kind] .. "]" .. " "
    else
        -- ▶ Func1 • [Function]
        str = str .. M.glyphs.separator .. " " .. "[" .. kind .. "]" .. " "
    end

    if ct.config.layout == "bottom" or 
        ct.config.layout == "top" then
        -- now we got all the room in the world, add detail
        path = lsp_util.relative_path_from_uri(node.call_hierarchy_obj.uri)
        -- ▶ Func1[] • relative/path/to/file
        -- or
        -- ▶ Func1 • [Function] • relative/path/to/file
        str = str .. M.glyphs.separator .. " " .. path
    end

    return str
end

-- marshal_line takes a UI buffer line and
-- marshals it into a tree.Node.
--
-- line : string - the UI buffer line representing
-- the node to marshal.
--
-- returns:
--   tree.Node - the marshaled tree.Node table.
function M.marshal_line(line)
    -- number of characters up to the expand symbol encode
    -- the node's tree depth.
    local depth  = vim.fn.match(line, "[▼▶]")
    if depth == -1 then
        vim.api.nvim_err_writeln("failed to find matching character: " .. depth)
        return
    end

    -- just your normal string parsing to carve out the symbol portion
    -- of the line.
    local symbol_and_type = vim.fn.strcharpart(line, depth+2)
    local symbol_end_idx = vim.fn.stridx(symbol_and_type, "[")
    local symbol = vim.fn.strpart(symbol_and_type, 0, symbol_end_idx)

    for _, node in ipairs(tree.depth_table[depth]) do
        if node.name == symbol then
            return node
        end
    end
    return nil
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
    table.insert(lines, M.marshal_node(node))

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
