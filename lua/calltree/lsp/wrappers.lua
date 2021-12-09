local notify = require('calltree.ui.notify')
local M = {}

function M.buf_document_symbol()
    notify.notify_popup_with_timeout("Creating document outline...", 7500, "info")
    vim.lsp.buf.document_symbol()
end

return M
