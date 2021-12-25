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
        -- whether this node is expanded in its containing
        -- tree.
        expanded = false,
    }
end

return M
