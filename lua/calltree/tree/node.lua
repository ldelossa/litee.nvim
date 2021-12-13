local M = {}

-- keyify creates a key for a node
--
-- node : tree.Node - the node a key is being created
-- for
--
-- returns:
--  string - the key
function M.keyify(node)
    local key = ""
    if node.document_symbol ~= nil then
        key = node.document_symbol.name .. ":" ..
                node.document_symbol.kind .. ":" ..
                    node.document_symbol.range.start.line
        return key
    end
    if node.symbol ~= nil then
        key = node.symbol.name .. ":" ..
                node.symbol.location.uri .. ":" ..
                    node.symbol.location.range.start.line
        return key
    end
    if node.call_hierarchy_item ~= nil then
        key = node.call_hierarchy_item.name .. ":" ..
                node.call_hierarchy_item.uri .. ":" ..
                    node.call_hierarchy_item.range.start.line
        return key
    end
    if node.filetree_item ~= nil then
        key = node.filetree_item.uri
        return key
    end
end

-- new construct a new Node.
--
-- name : string - Name of the Node, this cooresponds
-- to it's symbol in the source code.
--
-- depth : int - the depth at which this node will exist
-- in the tree.
--
-- call_hierarchy_item : table - the incoming or outgoing
-- call hierarchy object per the LSP spec. this is the "item" field of a
-- textDocument/[incoming|outgoing]Calls  response.
--
-- references : array - references of the given symbol. this field is the fromRanges
-- field of a call_hierarchy response datastructure hoisted up to the top level of he node.
--
-- document_symbol : table 
function M.new(name, depth, call_hierarchy_item, references, document_symbol, filetree_item)
    local node = {
        name=name,
        depth=depth,
        call_hierarchy_item=call_hierarchy_item,
        references=references,
        children={},
        expanded=false,
        symbol=nil,
        document_symbol=document_symbol,
        filetree_item=filetree_item,
        -- if the node is a document_symbol this field will be present
        -- containing the document uri the symbol belongs to.
        --
        -- not set until the documentSymbol handler is invoked in calltree.lsp.handlers
        uri=""
    }
    node.key = M.keyify(node)
    return node
end

return M
