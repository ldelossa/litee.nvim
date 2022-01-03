local M = {}

-- new_node creates a polymorphic node
-- which the caller can attach their own
-- node specific fields to.
--
-- a unique key must be generated and provided
-- along with the desired depth of the node with
-- the tree it will belong in.
--
-- see function definition for node field documentation.
-- only the requird fields are present in the constructor
-- optional fields can be added on to the node by the caller.
--
-- @param name (string) a non-unique display name
-- for the node.
-- @param key (string) a unique key used to identify
-- the node when placed into a tree.
-- @param depth (int) the node's depth in the tree, zero
-- indexed. depth 0 indicates this node is the root of
-- the tree.
-- @returns (table) A table representing a node object.
-- the caller is free to attach domain specific fields
-- that convey the node's purpose othorgonal to the usage
-- in the tree.
function M.new_node(name, key, depth)
    return {
        -- a non-unique display name for the node
        name = name,
        -- the depth of the node in the target tree
        depth = depth,
        -- a unique key used to identify the node when
        -- placed into a tree
        key = key,
        -- a list of children nodes with recursive definitions.
        children = {},
        -- a "Location" object as defined by the LSP which
        -- associates this node with a source code file and line range.
        -- see:
        -- https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#location
        location = {},
        -- a list of "Range" objects, relative to the above location object,
        -- which relate in a domain specific way to this node.
        -- see:
        -- https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#range
        references = {},
        -- whether this node is expanded in its containing
        -- tree.
        expanded = false,
    }
end

return M
