local lsp_util = require('calltree.lsp.util')

local M = {}

local direction_map = {
    from = "Incoming Calls: ",
    to   = "Outgoing Calls: "
}

local float_win = nil

-- close_details_popups closes the created popup window
-- if it exists.
function M.close_details_popup()
    if float_win ~= nil and
        vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
        float_win = nil
    end
end

-- details_popup creates a popup window showing futher details
-- about a symbol.
--
-- node : tree.Node - the node to show details for
--
-- direction : string - the current direction of the call tree
-- must be "to" or "from"
--
-- calltree_buffer : buffer_handle - the buffer_handle for the
-- current calltree.
function M.details_popup(node, direction, calltree_buffer)
    local buf = vim.api.nvim_create_buf(false, false)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'syntax', 'yaml')

    local lines = {}
    table.insert(lines, "==Symbol Details==")
    table.insert(lines, "Name: " .. node.name)
    table.insert(lines, "Kind: " .. vim.lsp.protocol.SymbolKind[node.call_hierarchy_item.kind])

    if node.expanded then
        table.insert(lines, direction_map[direction] .. #node.children)
    end

    if node.references ~= nil then
        table.insert(lines, "References: " .. #node.references)
    end

    table.insert(lines, "File: " .. lsp_util.relative_path_from_uri(node.call_hierarchy_item.uri))

    if node.call_hierarchy_item.detail ~= nil then
        table.insert(lines, "Details: " .. node.call_hierarchy_item.detail)
    end

    if node.call_hierarchy_item.data ~= nil then
        table.insert(lines, "Data: " .. node.call_hierarchy_item.data)
    end

    local width = 20
    for _, line in ipairs(lines) do
        local line_width = vim.fn.strdisplaywidth(line)
        if line_width > width then
            width = line_width
        end
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    local popup_conf = vim.lsp.util.make_floating_popup_options(
            width,
            #lines,
            {
                border= "rounded",
                focusable= false,
                zindex = 99,
            }
    )
    float_win = vim.api.nvim_open_win(buf, false, popup_conf)
    vim.api.nvim_win_set_option(float_win, 'winhighlight', 'NormalFloat:Normal')
end

return M
