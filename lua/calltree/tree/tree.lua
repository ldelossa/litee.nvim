local marshal = require('calltree.ui.marshal')

local M = {}

-- reg is a registry holding references to root
-- nodes indexed by their handle.
-- {
--   1: {root: {}, depth_table: {}, kind: ""}
-- }
-- where 1 is the tree handle, root is a
-- calltree.tree.Node and type is the type
-- of tree (calltree, symboltree)
local reg = {}

-- new_tree registers an empty tree and returns
-- the handle to the caller.
--
-- kind : string - "calltree" | "symboltree"
-- returns:
--  tree_handle
function M.new_tree(kind)
    local handle = #reg+1
    reg[handle] = {root = {}, depth_table = {}, kind = kind}
    return handle
end

-- get_tree takes a call handle and returns a table
-- representing our tree components.
--
-- handle : tree_handle - a valid handle to a tree
--
-- returns:
--  tree : table - a table with our tree componnts,
-- see "reg" comments above.
function M.get_tree(handle)
    return reg[handle]
end

-- remove_tree takes a call handle and removes
-- the associated tree from memory.
--
-- handle : tree_handle - a valid handle to a tree
function M.remove_tree(handle)
    if handle == nil then
        return
    end
    if reg[handle] == nil then
        return
    end
    reg[handle] = nil
end

-- recursive_dpt_compute traverses the tree
-- and flattens it into out depth_table
--
-- tree : tree_handle - a handle to a valid tree
--
-- node : Node - calltree's root node.
local function _recursive_dpt_compute(tree, node)
    local depth = node.depth
    if reg[tree].depth_table[depth] == nil then
        reg[tree].depth_table[depth] = {}
    end
    table.insert(reg[tree].depth_table[depth], node)
    -- recurse
    for _, child in ipairs(node.children) do
        _recursive_dpt_compute(tree, child)
    end
end

-- _refresh_dpt dumps the current depth_table
-- and writes a new one.
--
-- tree : tree_handle - a handle to a valid tree
local function _refresh_dpt(tree)
    reg[tree].depth_table = {}
    _recursive_dpt_compute(tree, reg[tree].root)
end

-- add_node will add a node to the tree pointed to by the
-- provided tree handle.
--
-- tree : tree_handle - a handle to a valid tree
--
-- parent : tree.tree.Node - the parent of the subtree being
-- added. the parent's "depth" field is significant. setting it to
-- 0 will throw away the current root and create a new tree.
-- See usages of this function to understand how depth can be safely
-- set.
--
--
-- children : tree.tree.Node array - the children of the parent.
-- the child's depth field has no significant and can be computed
-- from the parent's.
--
-- external : bool - if true an entire tree has been built externally
-- and the root will be added to the tree without any modifications.
-- the children param has no significance in this scenario.
function M.add_node(tree, parent, children, external)
    -- external nodes are roots of trees built externally
    -- if this is true set the tree's root to the incoming parent
    -- and immediately return
    if external then
        reg[tree].root = parent
        _refresh_dpt(tree)
        return
    end

    -- if depth is 0 we are creating a new call tree.
    if parent.depth == 0 then
        reg[tree].root = parent
        reg[tree].expanded = true
        reg[tree].depth_table = {}
        reg[tree].depth_table[0] = {}
        table.insert(reg[tree].depth_table[0], reg[tree].root)
    end

    -- if parent's depth doesn't exist we can't
    -- continue.
    if reg[tree].depth_table[parent.depth] == nil then
        -- this is an error
        return
    end

    -- lookup parent node in depth tree (faster then tree diving.)
    local pNode = nil
    for _, node in pairs(reg[tree].depth_table[parent.depth]) do
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
    _refresh_dpt(tree)
end

M.write_tree = function(tree, buf)
    marshal.marshal_tree(buf, {}, reg[tree].root, tree)
    return buf
end

-- remove subtree will remove the subtree of the
-- provided node, leaving the root node present.
--
-- node : Node - the parent node who's subtree
--               is to be removed
-- root : bool - should be "true", indicator that
--               recursion is at the root node.
function M.remove_subtree(tree, node, root)
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.remove_subtree(tree, child, false)
    end
    if not root then
        -- remove yourself from the depth table
        local dt = reg[tree].depth_table[node.depth]
        local nw_dt = {}
        for _, dt_node in ipairs(dt) do
            if dt_node.key ~= node.key then
                table.insert(nw_dt, dt_node)
            end
        end
        reg[tree].depth_table[node.depth] = nw_dt
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
-- tree : tree_handle - a handle to a valid tree
--
-- depth : int  - indicator of the incoming node's depth
--                useful for understanding when recursion is done.
-- node  : Node - the Node object being reparented.
function M.reparent_node(tree, depth, node)
    -- we are the new root, dump the current root_node and
    -- set yourself
    if depth == 0 then
        reg[tree].root = node
        reg[tree].root.depth = 0
    end
    -- recurse to leafs
    for _, child in ipairs(node.children) do
        M.reparent_node(tree, depth+1, child)
        -- recursion done, update your depth
        child.depth = depth+1
    end
    if depth == 0 then
        -- we are the root node, refresh depth_table with
        -- new tree.
        _refresh_dpt(tree)
    end
end

-- dump_tree will dump the tree data structure to a
-- buffer for debugging.
--
-- tree : tree_handle - a handle to a valid tree
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

return M
