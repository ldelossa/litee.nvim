local M = {}

-- alot of these are yoinked from:
-- https://github.com/onsails/lspkind-nvim/blob/master/lua/lspkind/init.lua
M.nerd = {
    Text = "",
    Method = "",
    Function = "",
    Constructor = "",
    Field = "ﰠ",
    Variable = "",
    Class = "ﴯ",
    Interface = "",
    Module = "",
    Property = "ﰠ",
    Unit = "塞",
    Value = "",
    Enum = "",
    Keyword = "",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "פּ",
    Event = "",
    Operator = "",
    TypeParameter = ""
}

M.codicons = {
    Text = "",
    Method = "",
    Function = "",
    Constructor = "",
    Field = "",
    Variable = "",
    Class = "",
    Interface = "",
    Module = "",
    Property = "",
    Unit = "",
    Value = "",
    Enum = "",
    Keyword = "",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = "",
}

-- config is explained via ":help calltree-config"
M.config = {
    layout = "left",
    layout_size = 30,
    jump_mode = "invoking",
    icons = "none",
    symbol_hl = "Search",
    symbol_refs_hl = "Search"
}

-- the configured icon set after setup() is ran.
M.active_icon_set = {}

function M.setup(user_config)
    -- hijack the normal lsp handlers
    vim.lsp.handlers['callHierarchy/incomingCalls'] = vim.lsp.with(
                require('calltree.lsp.handlers').ch_lsp_handler("from"), {}
    )
    vim.lsp.handlers['callHierarchy/outgoingCalls'] = vim.lsp.with(
                require('calltree.lsp.handlers').ch_lsp_handler("to"), {}
    )

    -- merge config
    if user_config ~= nil then
        for k, v in pairs(user_config) do
            M.config[k] = v
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

   -- setup commands
   vim.cmd("command! CTOpen        lua require('calltree.ui').open_calltree()")
   vim.cmd("command! STOpen        lua require('calltree.ui').open_symboltree()")
   vim.cmd("command! CTClose       lua require('calltree.ui').close()")
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

return M
