local M = {}

-- config is explained via ":help calltree-config"
M.config = {
    layout = "left",
    layout_size = 30,
    auto_open = false,
    jump_mode = "invoking",
    icons = "none",
    icon_highlights = {},
    hls = {}
}

function M.setup(user_config)
    -- hijack the normal lsp handlers
    vim.lsp.handlers['callHierarchy/incomingCalls'] = vim.lsp.with(
                require('calltree.lsp.handlers').ch_lsp_handler("from"), {}
    )
    vim.lsp.handlers['callHierarchy/outgoingCalls'] = vim.lsp.with(
                require('calltree.lsp.handlers').ch_lsp_handler("to"), {}
    )
    vim.lsp.handlers['textDocument/documentSymbol'] = vim.lsp.with(
                require('calltree.lsp.handlers').ws_lsp_handler(), {}
    )

    -- merge config
    if user_config ~= nil then
        for k, v in pairs(user_config) do
            -- merge user provied icon_highlights
            if k == "icon_highlights" then
                for icon, hl in pairs(v) do
                    M.icon_hls[icon] = hl
                end
                goto continue
            end
            -- merge user provided highlights
            if k == "hls" then
                for hl_name, hl in pairs(v) do
                    M.hls[hl_name] = hl
                end
                goto continue
            end
            M.config[k] = v
            ::continue::
        end
    end

    -- sanatize the config
    if (M.config.layout ~= "left")
        and (M.config.layout ~= "right")
        and (M.config.layout ~= "top")
        and (M.config.layout ~= "bottom")
    then
        M.config.layout = "left"
    end
    if M.config.layout_size < 10 then
        M.config.layout_size = 10
    end
    if M.config.jump_mode ~= "invoking" and M.config.jump_mode ~= "neighbor" then
        M.config.jump_mode = "neighbor"
    end
    if M.config.icons ~= "codicons" and M.config.icons ~= "nerd" then
        M.config.icons = "none"
    else
        if M.config.icons == "codicons" then
            M.active_icon_set = M.codicons
        end
        if M.config.icons == "nerd" then
            M.active_icon_set = M.nerd
        end
    end

    -- automatically open the ui elements on buf enters.
    if M.config.auto_open then
        vim.cmd([[au BufEnter * lua require('calltree.ui').open_calltree()]])
        vim.cmd([[au BufEnter * lua require('calltree.ui').open_symboltree()]])
    end

    -- will keep the outline view up to date when moving around buffers.
    vim.cmd([[au TextChanged,BufEnter,BufWritePost * lua require('calltree.ui').refresh_symbol_tree()]])

   -- setup commands
   vim.cmd("command! CTOpen        lua require('calltree.ui').open_calltree()")
   vim.cmd("command! STOpen        lua require('calltree.ui').open_symboltree()")
   vim.cmd("command! CTClose       lua require('calltree.ui').close_calltree()")
   vim.cmd("command! STClose       lua require('calltree.ui').close_symboltree()")
   vim.cmd("command! CTExpand      lua require('calltree.ui').expand()")
   vim.cmd("command! CTCollapse    lua require('calltree.ui').collapse()")
   vim.cmd("command! CTSwitch      lua require('calltree.ui').switch_direction()")
   vim.cmd("command! CTFocus       lua require('calltree.ui').focus()")
   vim.cmd("command! CTJump        lua require('calltree.ui').jump()")
   vim.cmd("command! CTHover       lua require('calltree.ui').hover()")
   vim.cmd("command! CTDetails     lua require('calltree.ui').details()")
   vim.cmd("command! CTClearHL     lua require('calltree.ui.jumps').set_jump_hl(false)")
   vim.cmd("command! CTDumpTree    lua require('calltree.ui').dump_tree()")
end

-- the configured icon set after setup() is ran.
M.active_icon_set = nil

-- alot of these are yoinked from:
-- https://github.com/onsails/lspkind-nvim/blob/master/lua/lspkind/init.lua
M.nerd = {
    Array           = "",
    Class           = "ﴯ",
    Color           = "",
    Constant        = "",
    Constructor     = "",
    Enum            = "",
    EnumMember      = "",
    Event           = "",
    Field           = "ﰠ",
    File            = "",
    Folder          = "",
    Function        = "",
    Interface       = "",
    Key             = "",
    Keyword         = "",
    Method          = "",
    Module          = "",
    Namespace       = "",
    Null            = "ﳠ",
    Object          = "",
    Operator        = "",
    Package         = "",
    Property        = "ﰠ",
    Reference       = "",
    Snippet         = "",
    Struct          = "פּ",
    Text            = "",
    TypeParameter   = "",
    Unit            = "塞",
    Value           = "",
    Variable        = "",
}

M.codicons = {
    Array           = "",
    Class           = "",
    Collapsed       = "",
    Color           = "",
    Constant        = "",
    Constructor     = "",
    Enum            = "",
    EnumMember      = "",
    Event           = "",
    Expanded        = "",
    Field           = "",
    File            = "",
    Folder          = "",
    Function        = "",
    Interface       = "",
    Key             = "",
    Keyword         = "",
    Method          = "",
    Module          = "",
    Namespace       = "",
    Null            = "",
    Object          = "",
    Operator        = "",
    Package         = "",
    Property        = "",
    Reference       = "",
    Snippet         = "",
    Struct          = "",
    Text            = "",
    TypeParameter   = "",
    Unit            = "",
    Value           = "",
    Variable        = "",
}

M.icon_hls = {
    Array           = "CTConstant",
    Boolean         = "CTBoolean",
    Class           = "CTType",
    Constant        = "CTConstant",
    Constructor     = "CTFunction",
    Enum            = "CTType",
    EnumMember      = "CTField",
    Event           = "CTType",
    Field           = "CTField",
    File            = "CTURI",
    Folder          = "CTNamespace",
    Function        = "CTFunction",
    Interface       = "CTType",
    Key             = "CTType",
    Keyword         = "CTConstant",
    Method          = "CTFunction",
    Module          = "CTNamespace",
    Namespace       = "CTNamespace",
    Null            = "CTType",
    Number          = "CTNumber",
    Object          = "CTType",
    Operator        = "CTOperator",
    Package         = "CTNamespace",
    Property        = "CTMethod",
    Reference       = "CTType",
    Snippet         = "CTString",
    String          = "CTString",
    Struct          = "CTType",
    Text            = "CTString",
    TypeParameter   = "CTParameter",
    Unit            = "CTType",
    Value           = "CTType",
    Variable        = "CTConstant"
}

M.hls = {
    SymbolDetailHL      = "CTSymbolDetail",
    SymbolHL            = "CTSymbol",
    SymbolJumpHL        = "CTSymbolJump",
    SymbolJumpRefsHL    = "CTSymbolJumpRefs"
}

return M
