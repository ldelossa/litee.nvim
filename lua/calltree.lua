local M = {}

-- config is explained via ":help calltree-config"
M.config = {
    layout = "left",
    layout_size = 30,
    auto_open = false,
    jump_mode = "invoking",
    icons = "none",
    no_hls = false,
    indent_guides = true,
    icon_highlights = {},
    hls = {},
    resolve_symbols = true,
    unified_panel = false,
    auto_highlight = true
}

function _setup_default_highlights() 
    local dark = {
        CTBoolean              = 'hi CTBoolean                guifg=#0087af guibg=None',
        CTConstant             = 'hi CTConstant               guifg=#0087af guibg=None',
        CTConstructor          = 'hi CTConstructor            guifg=#4DC5C6 guibg=None',
        CTField                = 'hi CTField                  guifg=#0087af guibg=None',
        CTFunction             = 'hi CTFunction               guifg=#988ACF guibg=None',
        CTMethod               = 'hi CTMethod                 guifg=#0087af guibg=None',
        CTNamespace            = 'hi CTNamespace              guifg=#87af87 guibg=None',
        CTNumber               = 'hi CTNumber                 guifg=#9b885c guibg=None',
        CTOperator             = 'hi CTOperator               guifg=#988ACF guibg=None',
        CTParameter            = 'hi CTParameter              guifg=#988ACF guibg=None',
        CTParameterReference   = 'hi CTParameterReference     guifg=#4DC5C6 guibg=None',
        CTString               = 'hi CTString                 guifg=#af5f5f guibg=None',
        CTSymbol               = 'hi CTSymbol                 guifg=#87afd7 gui=underline',
        CTSymbolDetail         = 'hi CTSymbolDetail           ctermfg=024 cterm=italic guifg=#988ACF gui=italic',
        CTSymbolJump           = 'hi CTSymbolJump             ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#87afd7 gui=italic,bold',
        CTSymbolJumpRefs       = 'hi CTSymbolJumpRefs         ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#9b885c gui=italic,bold',
        CTType                 = 'hi CTType                   guifg=#9b885c guibg=None',
        CTURI                  = 'hi CTURI                    guifg=#988ACF guibg=None',
    }
    local light = {
        CTBoolean               = 'hi CTBoolean                guifg=#005f87 guibg=None',
        CTConstant              = 'hi CTConstant               guifg=#005f87 guibg=None',
        CTConstructor           = 'hi CTConstructor            guifg=#9b885c guibg=None',
        CTField                 = 'hi CTField                  guifg=#005f87 guibg=None',
        CTFunction              = 'hi CTFunction               guifg=#806CCF guibg=None',
        CTMethod                = 'hi CTMethod                 guifg=#005f87 guibg=None',
        CTNamespace             = 'hi CTNamespace              guifg=#87af87 guibg=None',
        CTNumber                = 'hi CTNumber                 guifg=#9b885c guibg=None',
        CTOperator              = 'hi CTOperator               guifg=#806CCF guibg=None',
        CTParameter             = 'hi CTParameter              guifg=#806CCF guibg=None',
        CTParameterReference    = 'hi CTParameterReference     guifg=#268889 guibg=None',
        CTString                = 'hi CTString                 guifg=#af5f5f guibg=None',
        CTSymbol                = 'hi CTSymbol                 guifg=#806CCF gui=underline',
        CTSymbolDetail          = 'hi CTSymbolDetail           ctermfg=024 cterm=italic guifg=#005f87 gui=italic',
        CTSymbolJump            = 'hi CTSymbolJump             ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#87afd7 gui=italic,bold',
        CTSymbolJumpRefs        = 'hi CTSymbolJumpRefs         ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#9b885c gui=italic,bold',
        CTType                  = 'hi CTType                   guifg=#268889 guibg=None',
        CTURI                   = 'hi CTURI                    guifg=#806CCF guibg=None',
    }
    local bg = vim.api.nvim_get_option("background")
    if bg == "dark" then
        for hl_name, hl in pairs(dark) do
            if vim.fn.hlexists(hl_name) == 0 then
                vim.cmd(hl)
            end
        end
    end
    if bg == "light" then
        for hl_name, hl in pairs(light) do
            if vim.fn.hlexists(hl_name) == 0 then
                vim.cmd(hl)
            end
        end
    end
end

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

    -- setup default highlights
    if not M.config.no_hls then
        _setup_default_highlights()
    end

    -- automatically open the ui elements on buf enters.
    if M.config.auto_open then
        vim.cmd([[au BufEnter * lua require('calltree.ui').open_calltree()]])
        vim.cmd([[au BufEnter * lua require('calltree.ui').open_symboltree()]])
    end

    -- will keep the outline view up to date when moving around buffers.
    vim.cmd([[au TextChanged,BufEnter,BufWritePost * lua require('calltree.ui').refresh_symbol_tree()]])

    -- will enable symboltree ui tracking with source code lines.
    vim.cmd([[au CursorHold * lua require('calltree.ui').source_tracking()]])

   -- setup commands
   vim.cmd("command! CTOpen        lua require('calltree.ui').open_to('calltree')")
   vim.cmd("command! STOpen        lua require('calltree.ui').open_to('symboltree')")
   vim.cmd("command! CTToggle      lua require('calltree.ui').toggle_panel()")
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
    Boolean         = "",
    Class           = "ﴯ",
    Collapsed       = "",
    Color           = "",
    Constant        = "",
    Constructor     = "",
    Enum            = "",
    EnumMember      = "",
    Event           = "",
    Expanded        = "",
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
    Number          = "",
    Object          = "",
    Operator        = "",
    Package         = "",
    Property        = "ﰠ",
    Reference       = "",
    Snippet         = "",
    String          = "",
    Struct          = "פּ",
    Text            = "",
    TypeParameter   = "",
    Unit            = "塞",
    Value           = "",
    Variable        = "",
}

M.codicons = {
    Array           = "",
    Boolean         = "",
    Class           = "",
    Collapsed       = "",
    Color           = "",
    Constant        = "",
    Constructor     = "",
    Enum            = "",
    EnumMember      = "",
    Event           = "",
    Expanded        = "",
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
    Number          = "",
    Object          = "",
    Operator        = "",
    Package         = "",
    Property        = "",
    Reference       = "",
    Snippet         = "",
    String          = "",
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
