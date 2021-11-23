local M = {}

local float_win = nil

-- close_hover_popups closes the created popup window
-- if it exists.
function M.close_hover_popup()
    if float_win ~= nil and
        vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
        float_win = nil
    end
end

-- hover_handle shows hover information for a symbol in a calltree
-- ui window.
--
-- modified from neovim runtime/lua/vim/lsp/handlers.lua
-- function conforms to client LSP handler signature.
function M.hover_handler(_, result, ctx, config)
    M.close_hover_popup()
    -- get lines from result
    config = config or {}
    config.focus_id = ctx.method
    if not (result and result.contents) then
      -- return { 'No information available' }
      return
    end
    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    lines = vim.lsp.util.trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then
      -- return { 'No information available' }
      return
    end

    -- create buffer for popup
    local buf = vim.api.nvim_create_buf(false, false)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'syntax',    'markdown')
    vim.api.nvim_buf_set_option(buf, 'filetype',  'markdown')

    lines = vim.lsp.util.stylize_markdown(buf, lines, {})

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

  return float_win
end


return M
