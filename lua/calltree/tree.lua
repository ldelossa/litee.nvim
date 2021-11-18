local M = {}

-- Node represents a symbol in a
-- call tree.
M.Node = {}

M.Node.mt = {
    __eq = M.Node.eq
}

-- new construct a new Node.
--
-- name : string - Name of the Node, this cooresponds
-- to it's symbol in the source code.
--
-- depth : int - the depth at which this node will exist
-- in the tree.
--
-- call_hierarchy_obj : table - the incoming or outgoing
-- call hierarchy object per the LSP spec.
--
-- kind : string - the kind of symbol this node represents.
function M.Node.new(name, depth, call_hierarchy_obj, kind)
    local node = {
        name=name,
        depth=depth,
        children={},
        expanded=false,
        call_hierarchy_obj=call_hierarchy_obj,
        kind=kind
    }
    setmetatable(node, M.Node.mt)
    return node
end

-- eq perfoms a recursive comparison
-- between the two roots and their children.
function M.Node.eq(a, b)
    if a.name ~= b.name then
        return false
    end
    if a.depth ~= b.depth then
        return false
    end
    if #a.children ~= #b.children then
        return false
    end
    for i, _ in ipairs(a.children) do
        -- recurse
        if not M.Node.eq(
            a.children[i],
            b.children[i]
        ) then
            return false
        end
    end
    return true
end

-- depth_table caches the depth at which
-- a Node in the tree exists.
--
-- this data structure looks as follows:
--
-- {
--    0 = {{Node}}
--    1 = {{Node}, {Node}}
--    2 = {{Node}, {Node}, {Node}}
--    etc...
-- }
M.depth_table = nil

-- the root of the current call tree.
M.root_node = nil

-- add_node adds the provided root and
-- its children to the tree.
--
-- parent : Node - the root of the subtree being added to the calltree.
-- root's dpeth field is required.
--
-- children : Node[] - children of the provided root.
-- children node's depth field is not required and will
-- be computed from root's.
function M.add_node(parent,  children)
    -- if depth is 0 we are creating a new call tree.
    if parent.depth == 0 then
        M.root_node = parent
        M.root_node.expanded = true
        M.depth_table = {}
        M.depth_table[0] = {}
        table.insert(M.depth_table[0], M.root_node)
    end

    -- if parent's depth doesn't exist we can't
    -- continue.
    if M.depth_table[parent.depth] == nil then
        -- this is an error
        return
    end

    -- lookup parent node in depth tree (faster then tree diving.)
    local pNode = nil
    for _, node in pairs(M.depth_table[parent.depth]) do
        if node.name == parent.name then
            pNode = node
            break
        end
    end
    if pNode == nil then
        return
    end

    -- ditch the old child array, we are refreshing the children
    pNode.children = {}

    -- add children to parent node and update
    -- depth_table.
    if M.depth_table[parent.depth+1] == nil then
        M.depth_table[parent.depth+1] = {}
    end

    local child_depth = parent.depth + 1
    for _, child  in ipairs(children) do
        child.depth = child_depth
        table.insert(pNode.children, child)
        table.insert(M.depth_table[child.depth], child)
    end
end

-- recursive_dpt_compute traverses the tree
-- and flattens it into out depth_table
--
-- node : Node - calltree's root node.
local function _recursive_dpt_compute(node)
    local depth = node.depth
    if M.depth_table[depth] == nil then
        M.depth_table[depth] = {}
    end
    table.insert(M.depth_table[depth], node)
    -- recurse
    for _, child in ipairs(node.children) do
        _recursive_dpt_compute(child)
    end
end

-- _refresh_dpt dumps the current depth_table
-- and writes a new one.
local function _refresh_dpt()
    M.depth_table = {}
    _recursive_dpt_compute(M.root_node)
end

-- remove_node will remove all nodes associated
-- with the given symbols from the call tree and depth table
--
-- symbols : string array - a list of symbols to delete from
-- the call tree and depth table.
function M.remove_node(symbols)
    local function recursive_delete(node)
        local tree_delete_indexes = {}
        for i, child in ipairs(node.children) do
            for _, symbol in ipairs(symbols) do
                if child.name == symbol then
                    table.insert(tree_delete_indexes, i)
                    goto skip_recursion
                end
            end
            recursive_delete(child)
            ::skip_recursion::
        end
        -- recursion is done, we can safely delete any matching
        -- nodes from the children array.
        for _, tree_delete_i in ipairs(tree_delete_indexes) do
            table.remove(node.children, tree_delete_i)
        end
    end
    recursive_delete(M.root_node)
    _refresh_dpt()
end

-- remove subtree will remove the subtree of the
-- provided node, leaving the root node present.
--
-- node : Node - the parent node who's subtree
--               is to be removed
-- root : bool - should be "true", indicator that
--               recursion is at the root node.
function M.remove_subtree(node, root)
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.remove_subtree(child, false)
    end
    if not root then
        -- remove yourself from the depth table
        local dt = M.depth_table[node.depth]
        local nw_dt = {}
        for _, dt_node in ipairs(dt) do
            if dt_node.name ~= node.name then
                table.insert(nw_dt, dt_node)
            end
        end
        M.depth_table[node.depth] = nw_dt
    end
    if root then
        -- remove your children
        node.children = {}
    end
end

-- reparent_node makes the provided node M.root_node,
-- creating a new calltree rooted at node.
--
-- the subtree from node down is preserved.
--
-- depth : int  - indicator of the incoming node's depth
--                useful for understanding when recursion is done.
-- node  : Node - the Node object being reparented.
function M.reparent_node(depth, node)
    -- we are the new root, dump the current root_node and
    -- set yourself
    if depth == 0 then
        M.root_node = node
        M.root_node.depth = 0
    end
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.reparent_node(depth+1, child)
        -- recursion done, update your depth
        child.depth = depth+1
    end
    if depth == 0 then
        -- we are the root node, refresh depth_table with
        -- new tree.
        _refresh_dpt()
    end
end

function M.dump_tree()
    print(vim.inspect(M.root_node))
end

return M
