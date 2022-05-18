local lib_util = require('litee.lib.util')
local lib_hi    = require('litee.lib.highlights')
local lib_tree_config = require('litee.lib.config').config["tree"]
local icon_set = require('litee.lib').icon_set

local M = {}

-- buf_line_map keeps a mapping between marshaled
-- buffer lines and the node objects for a given tree.
--
-- the structure of this table is as follows:
-- {
--   tree_handle = {
--      line_number = node,
--      ...
--   },
--   ...
-- }
M.buf_line_map = {}

-- maps source code lines to buffer lines
-- for a given tree.
--
-- currently only useful for symboltree.
--
-- the struture of this table is as follows:
-- {
--   tree_handle = {
--      source_file_line_number = {
--          uri = relative_path_to_file,
--          line = calltree_buffer_line_number
--      }
--      ...
--   }
--   ...
-- }
M.source_line_map = {}

-- marshal_node takes a node and a marshal_func and
-- produces a buffer line.
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua, this node must
-- be the node being marshalled into a line.
-- @param marshal_func (function(node)) A function
-- when given a node returns the following strings
-- name: the display name for the node
-- detail: details to display about the node
-- icon: any icon associated with the node
-- expand_guide: optional override when the marshal
-- func want to specify a specific expand guide.
-- @param no_guide_leaf (bool) If node is a leaf
-- node and this bool is true an expansion guide
-- will be ommited from the rendered line.
-- @return buffer_line (string) a string with
-- the preamble of the buffer line.
-- @return virt_text (table) A table suitable for
-- configuring virtual text containing the details
-- of the node. This virtual text will be placed EOL
-- in the buffer line.
function M.marshal_node(node, marshal_func, no_guide_leaf)
    local expand_guide = ""
    if node.expanded then
        expand_guide = icon_set["Expanded"]
    else
        expand_guide = icon_set["Collapsed"]
    end
    if no_guide_leaf
        and #node.children == 0
        and node.expanded == true
    then
        expand_guide = icon_set["Space"]
    end

    local str = ""

    local name, detail, icon, expand_guide_override = marshal_func(node)

    if expand_guide_override ~= nil then
        expand_guide = expand_guide_override
    end

    if lib_tree_config.indent_guides then
        for i=1, node.depth do
            if i == 1 then
                str = str .. icon_set["Space"]
            else
                str = str .. icon_set["IndentGuide"] .. icon_set["Space"]
            end
        end
    else
        for _=1, node.depth do
            str = str .. icon_set["Space"]
        end
    end

    if icon == nil then
        icon = " "
    end

    -- ▶ Func1
    str = str .. expand_guide .. icon_set["Space"]
    str = str .. icon .. icon_set["Space"]  .. icon_set["Space"] .. name
    -- return detail as virtual text chunk.
    return str, {{detail, lib_hi.hls.SymbolDetailHL}}
end

-- marshal_line takes a UI buffer line and
-- marshals it into a tree.Node.
--
-- @param linenr (table) A buffer line as returned by
-- vim.api.nvim_win_get_cursor()
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua, nil if
-- marshal failed.
function M.marshal_line(linenr, handle)
    if M.buf_line_map == nil then
        return nil
    end
    if M.buf_line_map[handle] == nil then
        return nil
    end
    local node = M.buf_line_map[handle][linenr[1]]
    return node
end

-- marshal_tree recursively marshals all nodes from the provided root
-- down, into UI lines.
--
-- @param buf (int) The buffer handle to write the marshalled tree to
-- @param lines (list of string) Recursive accumlator of marshaled
-- lines. Start this function with an empty table.
-- @param node (table) A node table as defined in lib/tree/node.lua,
-- this node must be the root  of the tree being marshalled into buffer lines.
-- @param virtual_text_lines (list of string) Recursive accumlator of marshaled
-- virtual text lines. Start this function with an empty table.
-- @param marshal_func (function(node)) A function
-- when given a node returns the following strings
    -- name: the display name for the node
    -- detail: details to display about the node
    -- icon: any icon associated with the node
function M._marshal_tree(buf, lines, node, tree, virtual_text_lines, marshal_func, no_guide_leaf)
    if node.depth == 0 then
        virtual_text_lines = {}
        -- create a new line mapping
        M.buf_line_map[tree] = {}
        M.source_line_map[tree] = {}
    end

    local line, virtual_text = M.marshal_node(node, marshal_func, no_guide_leaf)
    table.insert(lines, line)
    table.insert(virtual_text_lines, virtual_text)
    M.buf_line_map[tree][#lines] = node

    -- if the node has a location we can track where it
    -- exists in the source code file.
    if node.location ~= nil and not vim.tbl_isempty(node.location) then
        local start_line = node.location["range"]["start"].line
        M.source_line_map[tree][start_line+1] = {
            uri = lib_util.absolute_path_from_uri(node.location.uri),
            line = #lines
        }
    end

    -- if we are an expanded node or we are the root (always expand)
    -- recurse
    if node.expanded  or node.depth == 0 then
        for _, child in ipairs(node.children) do
            M._marshal_tree(buf, lines, child, tree, virtual_text_lines, marshal_func, no_guide_leaf)
        end
    end

    -- we are back at the root, all lines are inserted, lets write it out
    -- to the buffer
    if node.depth == 0 then
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, true, {})
        vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        for i, vt in ipairs(virtual_text_lines) do
            if vt[1][1] == "" then
                goto continue
            end
            local opts = {
                virt_text = vt,
                virt_text_pos = 'eol',
                hl_mode = 'combine'
            }
            vim.api.nvim_buf_set_extmark(buf, 1, i-1, 0, opts)
            ::continue::
        end
    end
end

return M
