```
██╗     ██╗████████╗███████╗███████╗   ███╗   ██╗██╗   ██╗██╗███╗   ███╗
██║     ██║╚══██╔══╝██╔════╝██╔════╝   ████╗  ██║██║   ██║██║████╗ ████║ Lightweight
██║     ██║   ██║   █████╗  █████╗     ██╔██╗ ██║██║   ██║██║██╔████╔██║ Integrated
██║     ██║   ██║   ██╔══╝  ██╔══╝     ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║ Text
███████╗██║   ██║   ███████╗███████╗██╗██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ Editing
╚══════╝╚═╝   ╚═╝   ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝ Environment
====================================================================================
```

![litee screenshot](./contrib/litee-screenshot.png)

# litee.nvim

Litee.nvim (pronounced lite) is a library for building "IDE-lite" experience in Neovim. 

By utilizing the "litee" library plugin authors can achieve a consistent experience
across separate plugins.

There are several official litee plugins which can act as a reference for implementing
additional.

## Calltree
https://github.com/ldelossa/litee-calltree

Analogous to VSCode's "Call Hierarchy" tool, this feature exposes an explorable tree
of incoming or outgoing calls for a given symbol. 

Unlike other Neovim plugins, the tree can be expanded and collapsed to discover 
"callers-of-callers" and "callees-of-callees" until you hit a leaf.

## Symboltree
https://github.com/ldelossa/litee-symboltree

Analogous to VSCode's "Outline" tool, this feature exposes a live tree of document
symbols for the current file. 

The tree is updated as you move around and change files.

## Filetree
https://github.com/ldelossa/litee-filetree

Analogous to VSCode's "Explorer", this feature exposes a full feature file explorer 
which supports recursive copies, recursive moves, and proper renaming of a file 
(more on this in the appropriate section).

# Usage

litee.nvim is a library which other plugins can important and use. 

The library has it's own configuration and setup function which can be
viewed in the `doc.txt`.

An example of configuring the library is below:

```
require('litee.lib').setup({
    tree = {
        icon_set = "codicons"
    },
    panel = {
        orientation = "left",
        panel_size  = 30
    }
})
```
