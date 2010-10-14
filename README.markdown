This is a complete rewrite of the original OmniCpp plugin for Vim. It
aims at providing Omni completion for C/C++ files as would any
full-fledged IDE.

**Warning:** The plugin is still in early alpha state. Although features
are implemented by the day, a lot of functionality is still missing.

Features
========
- Simple and qualified variable name lookup in all contexts made
  available at the cursor's position
- Parse includes recursively, resolving names using the *path* variable
- Tokenize code, which makes it tolerant to newlines and comments
- Cache file access to speed up subsequent calls
- Test suites for most modules

Caveats
=======
- Although file access is cached, the first call might take quite some
  time to complete, especially for includes in large projects

Installation notes
==================
- To install system-wide, copy the whole folder hierarchy into
  */usr/share/vim/vimfiles*
- To install on a per-user basis, copy the *ftplugin* folder into
  *~/.vim/after*, and the other folders into *~/.vim*
- Update your *path* variable to include directories that will be
  searched for headers, ex:

        setl path+=/usr/include/c++/4.5.1/

- Update the *tag* variable to point to your project's tag files, ex:

        setl tag+=~/.vim/tags/ogre

You might want to consider using a project management plugin to set
these variables on a project basis

- Now you can use the omni completion feature by hitting *C-X C-O* while
  in insert mode, or use the *SuperTab* plugin.
