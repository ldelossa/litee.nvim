local M = {}

-- keyify creates a key for a node
--
-- node : tree.Node - the node a key is being created
-- for
--
-- returns:
--  string - the key
function M.keyify(node)
    local key = node.name .. ":"
        .. node.call_hierarchy_item.uri .. ":"
        .. node.call_hierarchy_item.range.start.line
    return key
end

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
--
-- references : array of references of the given symbol
function M.new(name, depth, call_hierarchy_item, references)
    local node = {
        name=name,
        depth=depth,
        call_hierarchy_item=call_hierarchy_item,
        references=references,
        children={},
        expanded=false,
        symbol=nil
    }
    node.key = M.keyify(node)
    return node
end

return M
