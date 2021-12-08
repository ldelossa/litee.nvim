local lsp_util = require('calltree.lsp.util')

local M = {}

local direction_map = {
    from = "Incoming Calls: ",
    to   = "Outgoing Calls: ",
    symboltree   = nil
}

-- a singleton float window for a details popup.
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
-- type : string - the type of tree (calltree|symboltree)
--
-- direction : string - the current direction of the call tree
-- must be "to" or "from"
function M.details_popup(node, type, direction)
    local buf = vim.api.nvim_create_buf(false, true)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'syntax', 'yaml')

    local name = node.name
    local kind = lsp_util.resolve_symbol_kind(node)
    local calltree_children = nil; calltree_children = (function() if direction_map[direction] ~= nil then return #node.children end end)()
    local references = nil; references = (function() if node.references ~= nil then return #node.references end end)()
    local file = lsp_util.resolve_relative_file_path(node)
    local detail = lsp_util.resolve_detail(node)

    local lines = {}
    table.insert(lines, "==Symbol Details==")
    table.insert(lines, "Name: " .. node.name)
    if kind ~= nil then
        table.insert(lines, "Kind: " .. kind)
    end
    if node.references ~= nil then
        table.insert(lines, "References: " .. references)
    end
    if file ~= nil then
        table.insert(lines, "File: " .. file)
    end
    if detail ~= nil then
        table.insert(lines, "Details: " .. detail)
    end
    -- handle Children fields
    if type == "calltree" then
        -- calltrees are lazily loaded so we don't know children count until
        -- the node is expanded.
        if node.expanded and calltree_children ~= nil then
            table.insert(lines, direction_map[direction] .. calltree_children)
        end
    elseif type == "symboltree" then
        -- symboltrees are loaded all at once so we know children count
        -- immediately.
        table.insert(lines, "Children: " .. #node.children)
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
end

return M
