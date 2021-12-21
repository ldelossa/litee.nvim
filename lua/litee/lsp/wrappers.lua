local notify = require('litee.ui.notify')
local M = {}

function M.buf_document_symbol()
    notify.notify_popup_with_timeout("Creating document outline...", 7500, "info")
    vim.lsp.buf.document_symbol()
end

function M.buf_incoming_calls()
    notify.notify_popup_with_timeout("Creating incoming calls outline...", 7500, "info")
    vim.lsp.buf.incoming_calls()
end

function M.buf_outgoing_calls()
    notify.notify_popup_with_timeout("Creating outgoing calls outline...", 7500, "info")
    vim.lsp.buf.outgoing_calls()
end

return M
