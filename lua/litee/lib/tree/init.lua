local lib_marshal = require('litee.lib.tree.marshal')

local M = {}

-- registry keeps a mapping between tree handles
-- and a tree table.
--
-- the registry and tree table stricture is defined
-- below:
-- {
--   1: {root = {}, depth_table = {}, kind = "", source_line_map = nil, buf_line_map = nil}
-- }
-- 1 is the the associated handle returned by new_tree
-- root is the root node of the tree
--
-- depth_table is the depth table associated with the tree
--
-- kind is the kind of tree and will typically be a component's
-- name as defined in lib/state.lua
local registry = {}

-- new_tree registers an empty tree and returns
-- the handle to the caller.
--
-- @param kind (string) A string representing, at
-- a high level, the kind of tree being created.
-- @returns tree_handle (int) A handle representing
-- the created tree.
function M.new_tree(kind)
    local handle = #registry+1
    registry[handle] = {root = {}, depth_table = {}, kind = kind}
    return handle
end

-- get_tree takes a call handle and returns a table
-- representing our tree components.
--
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
-- @returns tree (table) A tree table as defined
-- in this module, see "registry" comments.
function M.get_tree(handle)
    local t = registry[handle]

    -- attach marshaler info to tree if it exists.
    if t ~= nil then
        t.source_line_map = lib_marshal.source_line_map[handle]
        t.buf_line_map = lib_marshal.buf_line_map[handle]
    end

    return registry[handle]
end

-- remove_tree takes a call handle and removes
-- the associated tree from memory.
--
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
function M.remove_tree(handle)
    if handle == nil then
        return
    end
    if registry[handle] == nil then
        return
    end
    registry[handle] = nil
end

-- search_dpt will search the dpt at the given
-- depth for the given key.
--
-- @param dpt (table) A depth table retrieved
-- from a previous call to get_tree.
-- @param depth (int) The depth at which to search
-- for the key
-- @param key (string) The node's key to search
-- for
-- @returns node (table) If found, a node table
-- as defined in lib/tree/node.lua. Nil if search
-- fails.
function M.search_dpt(dpt, depth, key)
    local nodes = dpt[depth]
    if nodes == nil then
        return nil
    end
    for _, node in ipairs(nodes) do
        if node.key == key then
            return node
        end
    end
    return nil
end

-- recursive_dpt_compute traverses the tree
-- and flattens it into out depth_table
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
local function _recursive_dpt_compute(handle, node)
    local depth = node.depth
    if registry[handle].depth_table[depth] == nil then
        registry[handle].depth_table[depth] = {}
    end
    table.insert(registry[handle].depth_table[depth], node)
    -- recurse
    for _, child in ipairs(node.children) do
        _recursive_dpt_compute(handle, child)
    end
end

-- _refresh_dpt dumps the current depth_table
-- and writes a new one.
--
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
local function _refresh_dpt(handle)
    registry[handle].depth_table = {}
    _recursive_dpt_compute(handle, registry[handle].root)
end

-- add_node will add a node to the tree pointed to by the
-- provided tree handle.
--
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
-- @param parent (table) The parent node table of the subtree being
-- added. the parent's "depth" field is significant. setting it to
-- 0 will throw away the current root and create a new tree.
-- See usages of this function to understand how depth can be safely
-- set.
-- @param children (table) The children of the parent.
-- the child's depth field has no significant and can be computed
-- from the parents (unless external is used, see below).
-- @param external (bool) If true an entire tree has been built externally
-- and the root will be added to the tree without any modifications.
-- the children param has no significance in this scenario.
-- note: when using external the calling code must set the all parent
-- and children depth fields correctly.
function M.add_node(handle, parent, children, external)
    if registry[handle] == nil then
        return
    end
    -- external nodes are roots of trees built externally
    -- if this is true set the tree's root to the incoming parent
    -- and immediately return
    if external then
        registry[handle].root = parent
        _refresh_dpt(handle)
        return
    end

    -- if depth is 0 we are creating a new call tree.
    if parent.depth == 0 then
        registry[handle].root = parent
        registry[handle].expanded = true
        registry[handle].depth_table = {}
        registry[handle].depth_table[0] = {}
        table.insert(registry[handle].depth_table[0], registry[handle].root)
    end

    -- if parent's depth doesn't exist we can't
    -- continue.
    if registry[handle].depth_table[parent.depth] == nil then
        -- this is an error
        return
    end

    -- lookup parent node in depth tree (faster then tree diving.)
    local pNode = nil
    for _, node in pairs(registry[handle].depth_table[parent.depth]) do
        if node.key == parent.key then
            pNode = node
            break
        end
    end
    if pNode == nil then
        return
    end

    -- ditch the old child array, we are refreshing the children
    pNode.children = {}

    local child_depth = parent.depth + 1
    for _, child  in ipairs(children) do
        child.depth = child_depth
        table.insert(pNode.children, child)
    end
    _refresh_dpt(handle)
end

-- remove subtree will remove the subtree of the
-- provided node, leaving the root node present.
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua. This node must
-- be the root of the subtree being removed.
-- @param root (bool) Should be "true", indicator that
-- recursion is at the root node.
function M.remove_subtree(tree, node, root)
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.remove_subtree(tree, child, false)
    end
    if not root then
        -- remove yourself from the depth table
        local dt = registry[tree].depth_table[node.depth]
        local nw_dt = {}
        for _, dt_node in ipairs(dt) do
            if dt_node.key ~= node.key then
                table.insert(nw_dt, dt_node)
            end
        end
        registry[tree].depth_table[node.depth] = nw_dt
    end
    if root then
        -- remove your children
        node.children = {}
    end
end

-- collapse subtree will recursively collapse the
-- subtree starting at root and inclusive to root.
--
-- this function does not modify the tree structure
-- like "remove_subtree" but rather sets all nodes in the
-- subtree to expanded = false. on next marshal of the
-- tree the nodes will be collapsed.
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua, this node must be
-- the root of the subtree to be collapsed.
function M.collapse_subtree(root)
    root.expanded = false
    for _, child in ipairs(root.children) do
        M.collapse_subtree(child)
    end
end

-- reparent_node will make the provided node
-- the root of the provided tree, discarding
-- any ancestors above it in the process.
--
-- @param handle (int) A tree handle ID previously
-- returned from a call to new_tree
--
-- @param depth (int) The depth at which to search
-- for the key
-- @param node (table) A node table
-- as defined in lib/tree/node.lua, this node must be
-- the desired new root of the tree.
function M.reparent_node(handle, depth, node)
    -- we are the new root, dump the current root_node and
    -- set yourself
    if depth == 0 then
        registry[handle].root = node
        registry[handle].root.depth = 0
    end
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.reparent_node(handle, depth+1, child)
        -- recursion done, update your depth
        child.depth = depth+1
    end
    if depth == 0 then
        -- we are the root node, refresh depth_table with
        -- new tree.
        _refresh_dpt(handle)
    end
end

-- dump_tree will dump the tree data structure to a
-- buffer for debugging.
--
-- @param node (table) A node table
-- as defined in lib/tree/node.lua, this node can be
-- a root or a child depending on where in the tree
-- you'd like to dump.
function M.dump_tree(node)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "calltree-dump")
    vim.cmd("botright split")
    local win = vim.api.nvim_get_current_win()
    local lines = vim.fn.split(vim.inspect(node), "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_set_current_win(win)
end

-- write_tree recursively marshals all nodes from the provided root
-- down, into UI lines and writes those lines to the provided buffer.
--
-- @param buf  (int) The buffer handle to write the marshalled tree to
-- @param tree (int) The tree handle to marshal into the provided buffer
-- @param marshal_func (function(node)) A function
-- when given a node returns the following strings
    -- name: the display name for the node
    -- detail: details to display about the node
    -- icon: any icon associated with the node
function M.write_tree(buf, tree, marshal_func, no_guide_leaf)
    local root = registry[tree].root
    if root == nil then
        return
    end
    lib_marshal._marshal_tree(buf, {}, root, tree, {}, marshal_func, no_guide_leaf)
    return buf
end

-- same as `write_tree` but forces `no_guide_leaf` to be true
-- on each call.
--
-- useful for clients of the lib which always choose this option.
function M.write_tree_no_guide_leaf(buf, tree, marshal_func)
    M.write_tree(buf, tree, marshal_func, true)
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
    return lib_marshal.marshal_line(linenr, handle)
end

function M.flatten_depth_table(dtp)
    local nodes = {}
    for _, depth in pairs(dtp) do
        for _, node in ipairs(depth) do
            table.insert(nodes, node)
        end
    end
    return nodes
end

return M
