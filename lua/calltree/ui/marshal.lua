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
    local detail = ""
    if node.symbol ~= nil then
        name = node.symbol.name
        kind = vim.lsp.protocol.SymbolKind[node.symbol.kind]
        detail = lsp_util.relative_path_from_uri(node.symbol.location.uri)
    elseif node.document_symbol ~= nil then
        name = node.document_symbol.name
        kind = vim.lsp.protocol.SymbolKind[node.document_symbol.kind]
        if node.document_symbol.detail ~= nil then
            detail = node.document_symbol.detail
        end
    elseif node.call_hierarchy_item then
        name = node.name
        kind = vim.lsp.protocol.SymbolKind[node.call_hierarchy_item.kind]
        detail = lsp_util.relative_path_from_uri(node.call_hierarchy_item.uri)
    end
    local icon = ""
    if kind ~= "" then
        icon = ct.active_icon_set[kind]
    end

    -- add spacing up to node's depth
    for _=1, node.depth do
        str = str .. " "
    end

    -- ▶ Func1
    str = str .. glyph

    if ct.config.icons ~= "none" then
        -- ▶   Func1
        str = str .. " " .. icon .. "  " .. name
    else
        -- ▶ [Function] Func1 
        str = str .. " " .. "[" .. kind .. "]" .. " " .. M.glyphs.separator .. " " .. name
    end

    --[[ -- ▶   Func1 main.go
    str = str .. detail ]]

    return str, {{detail, ct.hls.SymbolDetailHL}}
end

-- marshal_line takes a UI buffer line and
-- marshals it into a tree.Node.
--
-- linenr : {row,col} - the UI buffer line typically returned by
-- vim.api.nvim_win_get_cursor(calltree_win_handle)
--
-- tree: the handle of the tree we are marshaling the
-- line from.
--
-- returns:
--   tree.Node - the marshaled tree.Node table.
function M.marshal_line(linenr, tree)
    local node = M.buf_line_map[tree][linenr[1]]
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
-- node : tree.tree.Node - the root node of the tree where marshaling will
-- begin.
--
-- tree : tree_handle - a handle to a the tree we are marshaling.
function M.marshal_tree(buf_handle, lines, node, tree, virtual_text_lines)
    if node.depth == 0 then
        if virtual_text_lines == nil then
            virtual_text_lines = {}
        end
        -- create a new line mapping
        M.buf_line_map[tree] = {}
    end
    local line, virtual_text = M.marshal_node(node)
    table.insert(lines, line)
    table.insert(virtual_text_lines, virtual_text)
    M.buf_line_map[tree][#lines] = node

    -- if we are an expanded node or we are the root (always expand)
    -- recurse
    if node.expanded  or node.depth == 0 then
        for _, child in ipairs(node.children) do
            M.marshal_tree(buf_handle, lines, child, tree, virtual_text_lines)
        end
    end

    -- we are back at the root, all lines are inserted, lets write it out
    -- to the buffer
    if node.depth == 0 then
        vim.api.nvim_buf_set_option(buf_handle, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf_handle, 0, -1, true, {})
        vim.api.nvim_buf_set_lines(buf_handle, 0, #lines, false, lines)
        vim.api.nvim_buf_set_option(buf_handle, 'modifiable', false)
        for i, vt in ipairs(virtual_text_lines) do
            local opts = {
                virt_text = vt,
                virt_text_pos = 'eol',
                hl_mode = 'combine'
            }
            vim.api.nvim_buf_set_extmark(buf_handle, 1, i-1, 0, opts)
        end
    end
end

return M
