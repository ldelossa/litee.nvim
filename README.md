```
    /_____/\ /_______/\ /_/\     /_/\   /________/\/_____/\  /_____/\ /_____/\     
    \:::__\/ \::: _  \ \\:\ \    \:\ \  \__.::.__\/\:::_ \ \ \::::_\/_\::::_\/_    
     \:\ \  __\::(_)  \ \\:\ \    \:\ \    \::\ \   \:(_) ) )_\:\/___/\\:\/___/\   
      \:\ \/_/\\:: __  \ \\:\ \____\:\ \____\::\ \   \: __ `\ \\::___\/_\::___\/_  
       \:\_\ \ \\:.\ \  \ \\:\/___/\\:\/___/\\::\ \   \ \ `\ \ \\:\____/\\:\____/\ 
        \_____\/ \__\/\__\/ \_____\/ \_____\/ \__\/    \_\/ \_\/ \_____\/ \_____\/ 
                                                                                   
    ==============================================================================
                          Neovim's missing call-hierarchy UI
```

# Calltree

Calltree implements the missing "call-hierarchy" tree UI seen in other popular IDE's
such as Pycharm and VSCode.

Calltree allows you to start at a root symbol and discover the callers or callees of it.

Subsequently, you can drill down the tree futher to discover the "callers-of-caller" or 
the "callees-of-callee". 

This relationship forms a tree and this is exactly how Calltree works, keeping an in
memory representation of the call tree and writing the tree out to an outline form when
requested.

# Usage

## Get it

Plug:
```
 Plug 'ldelossa/calltree.nvim'
```

## Set it

Call the setup function from anywhere you configure your plugins from.

Configuration dictionary is explained in ./doc/calltree.txt (:h calltree-config)
```
require('calltree').setup({})
```

## Use it

The setup function hooks directly into the "textDocument/incomingCalls" and "textDocument/outgoingCalls" 
LSP handlers. 

To start a call tree use the LSP client just like you're used to:

```
:lua vim.lsp.buf.incoming_calls
:lua vim.lsp.buf.outgoing_calls
```

You most likely have key mappings set for this if you're using the lsp-config.

Once the calltree is open you can expand and collapse symbols to discover a total call
hierarchy in an intuitative way.

Use ":CTExpand" and ":CTCollapse" to achieve this.

Check out (:h calltree) for all the details.

# Features

This plugin aims to be super simple and do one thing very well. 

There are a few features which add a bit more to the basic calltree usage. 

## Switching Directions

The ":CTSwitch" command will focus and inverse the call tree (move from outgoing to incoming for example) for the symbol under the curosor. 

## Focusing

The ":CTFocus" command will re-parent the symbol under the cursor, making it root. 

From there you can continue down the call tree.

## Hover

The ":CTHover" will show hover info for the given symbol.

## Jump

Calltree supports jumping to the symbol. 

The ":CTJump" command will do this. 

How jumping occurs is controlled by the config, see (h: calltree-config)

## Icons

Nerd font icons along with codicons are currently supported. 

You'll need a patched font for them to work correctly. see (h: calltree-config)

## Demo

[![Calltree Demonstration]()](https://user-images.githubusercontent.com/5642902/142293639-aa0d97a1-e3b0-4fc4-942e-108bfaa18793.mp4)
