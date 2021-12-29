local webicons = require('litee.nvim-web-devicons')
local M = {}

-- config is explained via ":help calltree-config"
M.config = {
    layout = "left",
    layout_size = 30,
    jump_mode = "invoking",
    icons = "none",
    no_hls = false,
    indent_guides = true,
    icon_highlights = {},
    hls = {},
    resolve_symbols = true,
    auto_highlight = true,
    scrolloff = false,
    map_resize_keys = true,
    hide_cursor = false,
    enable_notify = true,
    relative_filetree_entries = false,
    disable_default_bindings = false
}

local function _setup_default_highlights()
    local dark = {
        LTBoolean              = 'hi LTBoolean                guifg=#0087af guibg=None',
        LTConstant             = 'hi LTConstant               guifg=#0087af guibg=None',
        LTConstructor          = 'hi LTConstructor            guifg=#4DC5C6 guibg=None',
        LTField                = 'hi LTField                  guifg=#0087af guibg=None',
        LTFunction             = 'hi LTFunction               guifg=#988ACF guibg=None',
        LTMethod               = 'hi LTMethod                 guifg=#0087af guibg=None',
        LTNamespace            = 'hi LTNamespace              guifg=#87af87 guibg=None',
        LTNumber               = 'hi LTNumber                 guifg=#9b885c guibg=None',
        LTOperator             = 'hi LTOperator               guifg=#988ACF guibg=None',
        LTParameter            = 'hi LTParameter              guifg=#988ACF guibg=None',
        LTParameterReference   = 'hi LTParameterReference     guifg=#4DC5C6 guibg=None',
        LTString               = 'hi LTString                 guifg=#af5f5f guibg=None',
        LTSymbol               = 'hi LTSymbol                 guifg=#87afd7 gui=underline',
        LTSymbolDetail         = 'hi LTSymbolDetail           ctermfg=024 cterm=italic guifg=#988ACF gui=italic',
        LTSymbolJump           = 'hi LTSymbolJump             ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#87afd7 gui=italic,bold',
        LTSymbolJumpRefs       = 'hi LTSymbolJumpRefs         ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#9b885c gui=italic,bold',
        LTType                 = 'hi LTType                   guifg=#9b885c guibg=None',
        LTURI                  = 'hi LTURI                    guifg=#988ACF guibg=None',
        LTIndentGuide          = 'hi LTIndentGuide            guifg=None    guibg=None',
        LTExpandedGuide        = 'hi LTExpandedGuide          guifg=None    guibg=None',
        LTCollapsedGuide       = 'hi LTCollapsedGuide         guifg=None    guibg=None',
        LTSelectFiletree       = 'hi LTSelectFiletree ctermbg=131  ctermfg=246 cterm=None guibg=#af5f5f guifg=#e4e4e4 gui=None'
    }
    local light = {
        LTBoolean               = 'hi LTBoolean                guifg=#005f87 guibg=None',
        LTConstant              = 'hi LTConstant               guifg=#005f87 guibg=None',
        LTConstructor           = 'hi LTConstructor            guifg=#9b885c guibg=None',
        LTField                 = 'hi LTField                  guifg=#005f87 guibg=None',
        LTFunction              = 'hi LTFunction               guifg=#806CCF guibg=None',
        LTMethod                = 'hi LTMethod                 guifg=#005f87 guibg=None',
        LTNamespace             = 'hi LTNamespace              guifg=#87af87 guibg=None',
        LTNumber                = 'hi LTNumber                 guifg=#9b885c guibg=None',
        LTOperator              = 'hi LTOperator               guifg=#806CCF guibg=None',
        LTParameter             = 'hi LTParameter              guifg=#806CCF guibg=None',
        LTParameterReference    = 'hi LTParameterReference     guifg=#268889 guibg=None',
        LTString                = 'hi LTString                 guifg=#af5f5f guibg=None',
        LTSymbol                = 'hi LTSymbol                 guifg=#806CCF gui=underline',
        LTSymbolDetail          = 'hi LTSymbolDetail           ctermfg=024 cterm=italic guifg=#005f87 gui=italic',
        LTSymbolJump            = 'hi LTSymbolJump             ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#87afd7 gui=italic,bold',
        LTSymbolJumpRefs        = 'hi LTSymbolJumpRefs         ctermfg=015 ctermbg=110 cterm=italic,bold,underline   guifg=#464646 guibg=#9b885c gui=italic,bold',
        LTType                  = 'hi LTType                   guifg=#268889 guibg=None',
        LTURI                   = 'hi LTURI                    guifg=#806CCF guibg=None',
        LTIndentGuide           = 'hi LTIndentGuide            guifg=None    guibg=None',
        LTExpandedGuide         = 'hi LTExpandedGuide          guifg=None    guibg=None',
        LTCollapsedGuide        = 'hi LTCollapsedGuide         guifg=None    guibg=None',
        LTSelectFiletree       = 'hi LTSelectFiletree ctermbg=131  ctermfg=246 cterm=None guibg=#af5f5f guifg=#e4e4e4 gui=None'
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

local function sanatize_config()
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
end

function M.setup(user_config)
    -- hijack the normal lsp handlers
    vim.lsp.handlers['callHierarchy/incomingCalls'] = vim.lsp.with(
                require('litee.lsp.handlers').ch_lsp_handler("from"), {}
    )
    vim.lsp.handlers['callHierarchy/outgoingCalls'] = vim.lsp.with(
                require('litee.lsp.handlers').ch_lsp_handler("to"), {}
    )
    vim.lsp.handlers['textDocument/documentSymbol'] = vim.lsp.with(
                require('litee.lsp.handlers').ws_lsp_handler(), {}
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

    sanatize_config()

    -- setup default highlights
    if not M.config.no_hls then
        _setup_default_highlights()
        webicons.set_up_highlights()
    end

    -- will keep the outline view up to date when moving around buffers.
    vim.cmd([[au TextChanged,BufEnter,BufWritePost,WinEnter * lua require('litee.ui').refresh_symbol_tree()]])

    -- will enable symboltree ui tracking with source code lines.
    vim.cmd([[au CursorHold * lua require('litee.ui').source_tracking()]])

    -- will enable filetree file tracking with source code buffers.
    vim.cmd([[au BufWinEnter,WinEnter * lua require('litee.ui').file_tracking()]])

    -- will clean out any tree data for a tab when closed. only necessary
    -- when CTClose or STClose is not issued before a tab is closed.
    vim.cmd([[au TabClosed * lua require('litee.ui').on_tab_closed(vim.fn.expand('<afile>'))]])

    -- au to close popup with cursor moves or buffer is closed.
    vim.cmd("au CursorMoved,BufWinLeave,WinLeave * lua require('litee.ui.buffer').close_all_popups()")

    -- on resize cycle the panel to re-adjust window sizes.
    vim.cmd("au VimResized * lua require('litee.ui').toggle_panel(nil, false, true)")

    -- calltree specific commands
    vim.cmd("command! LTOpenToCalltree      lua require('litee.ui').open_to('calltree')")
    vim.cmd("command! LTCloseCalltree       lua require('litee.ui').close_calltree()")
    vim.cmd("command! LTNextCalltree        lua require('litee.ui').navigation('calltree', 'n')")
    vim.cmd("command! LTPrevCalltree        lua require('litee.ui').navigation('calltree', 'p')")
    vim.cmd("command! LTExpandCalltree      lua require('litee.ui').expand_calltree()")
    vim.cmd("command! LTCollapseCalltree    lua require('litee.ui').collapse_calltree()")
    vim.cmd("command! LTCollapseAllCalltree lua require('litee.ui').collapse_all_calltree()")
    vim.cmd("command! LTFocusCalltree       lua require('litee.ui').focus_calltree()")
    vim.cmd("command! LTSwitchCalltree      lua require('litee.ui').switch_calltree()")
    vim.cmd("command! LTJumpCalltree        lua require('litee.ui').jump_calltree()")
    vim.cmd("command! LTJumpCalltreeSplit   lua require('litee.ui').jump_calltree('split')")
    vim.cmd("command! LTJumpCalltreeVSplit  lua require('litee.ui').jump_calltree('vsplit')")
    vim.cmd("command! LTJumpCalltreeTab     lua require('litee.ui').jump_calltree('tab')")
    vim.cmd("command! LTHoverCalltree       lua require('litee.ui').hover_calltree()")
    vim.cmd("command! LTDetailsCalltree     lua require('litee.ui').details_calltree()")

    -- symboltree specific commands
    vim.cmd("command! LTOpenToSymboltree        lua require('litee.ui').open_to('symboltree')")
    vim.cmd("command! LTCloseSymboltree         lua require('litee.ui').close_symboltree()")
    vim.cmd("command! LTNextSymboltree          lua require('litee.ui').navigation('symboltree', 'n')")
    vim.cmd("command! LTPrevSymboltree          lua require('litee.ui').navigation('symboltree', 'p')")
    vim.cmd("command! LTExpandSymboltree        lua require('litee.ui').expand_symboltree()")
    vim.cmd("command! LTCollapseSymboltree      lua require('litee.ui').collapse_symboltree()")
    vim.cmd("command! LTCollapseAllSymboltree   lua require('litee.ui').collapse_all_symboltree()")
    vim.cmd("command! LTJumpSymboltree          lua require('litee.ui').jump_symboltree()")
    vim.cmd("command! LTJumpSymboltreeSplit     lua require('litee.ui').jump_symboltree('split')")
    vim.cmd("command! LTJumpSymboltreeVSplit    lua require('litee.ui').jump_symboltree('vsplit')")
    vim.cmd("command! LTJumpSymboltreeTab       lua require('litee.ui').jump_symboltree('tab')")
    vim.cmd("command! LTHoverSymboltree         lua require('litee.ui').hover_symboltree()")
    vim.cmd("command! LTDetailsSymboltree       lua require('litee.ui').details_symboltree()")

    -- filetree specific commands
    vim.cmd("command! LTOpenFiletree          lua require('litee.filetree.handlers').filetree_handler()")
    vim.cmd("command! LTOpenToFiletree        lua require('litee.ui').open_to('filetree')")
    vim.cmd("command! LTCloseFiletree         lua require('litee.ui').close_filetree()")
    vim.cmd("command! LTNextFiletree          lua require('litee.ui').navigation('filetree', 'n')")
    vim.cmd("command! LTPrevFiletree          lua require('litee.ui').navigation('filetree', 'p')")
    vim.cmd("command! LTExpandFiletree        lua require('litee.ui').expand_filetree()")
    vim.cmd("command! LTCollapseFiletree      lua require('litee.ui').collapse_filetree()")
    vim.cmd("command! LTCollapseAllFiletree   lua require('litee.ui').collapse_all_filetree()")
    vim.cmd("command! LTJumpFiletree          lua require('litee.ui').jump_filetree()")
    vim.cmd("command! LTJumpFiletreeSplit     lua require('litee.ui').jump_filetree('split')")
    vim.cmd("command! LTJumpFiletreeVSplit    lua require('litee.ui').jump_filetree('vsplit')")
    vim.cmd("command! LTJumpFiletreeTab       lua require('litee.ui').jump_filetree('tab')")
    vim.cmd("command! LTHoverFiletree         lua require('litee.ui').hover_filetree()")
    vim.cmd("command! LTDetailsFiletree       lua require('litee.ui').details_filetree()")
    vim.cmd("command! LTSelectFiletree        lua require('litee.ui').filetree_ops('select')")
    vim.cmd("command! LTDeSelectFiletree      lua require('litee.ui').filetree_ops('deselect')")
    vim.cmd("command! LTTouchFiletree         lua require('litee.ui').filetree_ops('touch')")
    vim.cmd("command! LTRemoveFiletree        lua require('litee.ui').filetree_ops('rm')")
    vim.cmd("command! LTCopyFiletree          lua require('litee.ui').filetree_ops('cp')")
    vim.cmd("command! LTMoveFiletree          lua require('litee.ui').filetree_ops('mv')")
    vim.cmd("command! LTMkdirFiletree         lua require('litee.ui').filetree_ops('mkdir')")
    vim.cmd("command! LTRenameFiletree       lua require('litee.ui').filetree_ops('rename')")

    -- in-window commands
    vim.cmd("command! LTPanel       lua require('litee.ui').toggle_panel()")
    vim.cmd("command! LTExpand      lua require('litee.ui').expand()")
    vim.cmd("command! LTCollapse    lua require('litee.ui').collapse()")
    vim.cmd("command! LTCollapseAll lua require('litee.ui').collapse_all()")
    vim.cmd("command! LTSwitch      lua require('litee.ui').switch()")
    vim.cmd("command! LTFocus       lua require('litee.ui').focus()")
    vim.cmd("command! LTJump        lua require('litee.ui').jump()")
    vim.cmd("command! LTJumpTab     lua require('litee.ui').jump('tab')")
    vim.cmd("command! LTJumpSplit   lua require('litee.ui').jump('split')")
    vim.cmd("command! LTJumpVSplit  lua require('litee.ui').jump('vsplit')")
    vim.cmd("command! LTHover       lua require('litee.ui').hover()")
    vim.cmd("command! LTDetails     lua require('litee.ui').details()")
    vim.cmd("command! LTClearHL     lua require('litee.ui.jumps').set_jump_hl(false)")
    vim.cmd("command! LTDumpTree    lua require('litee.ui').dump_tree()")
    vim.cmd("command! LTDumpNode    lua require('litee.ui').dump_node()")
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
    Array           = "LTConstant",
    Boolean         = "LTBoolean",
    Class           = "LTType",
    Constant        = "LTConstant",
    Constructor     = "LTFunction",
    Enum            = "LTType",
    EnumMember      = "LTField",
    Event           = "LTType",
    Field           = "LTField",
    File            = "LTURI",
    Folder          = "LTNamespace",
    Function        = "LTFunction",
    Interface       = "LTType",
    Key             = "LTType",
    Keyword         = "LTConstant",
    Method          = "LTFunction",
    Module          = "LTNamespace",
    Namespace       = "LTNamespace",
    Null            = "LTType",
    Number          = "LTNumber",
    Object          = "LTType",
    Operator        = "LTOperator",
    Package         = "LTNamespace",
    Property        = "LTMethod",
    Reference       = "LTType",
    Snippet         = "LTString",
    String          = "LTString",
    Struct          = "LTType",
    Text            = "LTString",
    TypeParameter   = "LTParameter",
    Unit            = "LTType",
    Value           = "LTType",
    Variable        = "LTConstant"
}

M.hls = {
    SymbolDetailHL      = "LTSymbolDetail",
    SymbolHL            = "LTSymbol",
    SymbolJumpHL        = "LTSymbolJump",
    SymbolJumpRefsHL    = "LTSymbolJumpRefs",
    IndentGuideHL       = "LTIndentGuide",
    ExpandedGuideHL     = "LTExpandedGuide",
    CollapsedGuideHL    = "LTCollapsedGuide",
    SelectFiletreeHL    = "LTSelectFiletree"
}

return M
