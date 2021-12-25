local lib_notify = require('litee.lib.notify')
local M = {}

function M.buf_document_symbol()
    lib_notify.notify_popup_with_timeout("Creating document outline...", 7500, "info")
    vim.lsp.buf.document_symbol()
end

function M.buf_incoming_calls()
    lib_notify.notify_popup_with_timeout("Creating incoming calls outline...", 7500, "info")
    vim.lsp.buf.incoming_calls()
end

function M.buf_outgoing_calls()
    lib_notify.notify_popup_with_timeout("Creating outgoing calls outline...", 7500, "info")
    vim.lsp.buf.outgoing_calls()
end

return M
