local M = {}

-- hls is a map of UI specific highlights used
-- by the litee.nvim library.
M.hls = {
    SymbolDetailHL      = "LTSymbolDetail",
    SymbolHL            = "LTSymbol",
    SymbolJumpHL        = "LTSymbolJump",
    SymbolJumpRefsHL    = "LTSymbolJumpRefs",
    IndentGuideHL       = "LTIndentGuide",
    ExpandedGuideHL     = "LTExpandedGuide",
    CollapsedGuideHL    = "LTCollapsedGuide",
    SelectFiletreeHL    = "LTSelectFiletree",
    NormalSB            = "LTNormalSB"
}

-- setup_default_highlights configures a list of default
-- highlights for the litee.nvim library.
function M.setup_default_highlights()
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
        LTSelectFiletree        = 'hi LTSelectFiletree ctermbg=131  ctermfg=246 cterm=None guibg=#af5f5f guifg=#e4e4e4 gui=None'
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

return M
