This is a complete rewrite of the original OmniCpp plugin for Vim. It
aims at providing Omni completion for C/C++ files as would any
full-fledged IDE.

**Warning:** The plugin is still in early alpha state. Although features
are implemented by the day, a lot of functionality is still missing.

Features
========
- Simple and qualified variable name lookup in all contexts made
available at the cursor's position
- Parse includes recursively, resolving names using the &path variable
- Tokenize code, which makes it tolerant to newlines and comments
- Cache file access to speed up subsequent calls
- Test suites for most modules

Caveats
=======
- Although file access is cached, the first call might take quite some
time to complete, especially for includes in large projects
