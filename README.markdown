This is a complete rewrite of the original OmniCpp plugin for Vim; it
aims at providing Omni completion for C/C++ files as would any
full-fledged IDE.

The issue tracker for this project can be found at:
http://jabbourb.lighthouseapp.com/projects/61672-omnicpp/overview


**Warning:** The plugin is still in early alpha state. Although features
are implemented by the day, a lot of functionality is still missing.

Features
========
- Simple and qualified variable name lookup in all contexts made
  available at the cursor's position
- Parse includes recursively, resolving names using the *path* variable
- Tokenize code, which makes it tolerant to newlines and comments
- Cache file access to speed up subsequent calls
- Resolve using-instructions and filter ambiguous contexts
- Test suites for most modules

Caveats
=======
- Although file access is cached, the first call in a recursive access
  might take quite some time to complete, especially for includes in
  large projects.
- Tags should be generated with the "+n" field to improve accuracy (it
  will still work otherwise, not as well though); on the other hand, we
  passed on the '--extra=+q' option since profiling has shown it didn't
  speed up tag searches.
- Current buffer code is tokenized, but file greps are not, and are
  still unable to match instructions spanning multiple lines or detect
  comments/strings.

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
  in insert mode, or use the *SuperTab* plugin
