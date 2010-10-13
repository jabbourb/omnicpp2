" Author: Bassam JABBOUR
" Description: A basic implementation of a cache object
" Every entry in the cache represents a parsed file, and stores the
" parsing results as well as the last modification time of that file.

" Add a parsed file to the cache (deep copy the data); silently
" overwrite any previously existing entry.
func! omnicpp#cache#Put(path, parse) dict
    let self.entries[a:path] = {'parse': deepcopy(a:parse), 'ftime': getftime(a:path)}
endfunc

" Retrieve a parsing result from the cache (deep copy); non-existing
" entries will throw an error.
func! omnicpp#cache#Get(path) dict
    return deepcopy(self.entries[a:path].parse)
endfunc

" Check if a file isn't in the cache, or otherwise needs to be reparsed
func! omnicpp#cache#Has(path) dict
    return has_key(self.entries, a:path) && self.entries[a:path].ftime == getftime(a:path)
endfunc

" Cache constructor. A cache object has the following methods:
" - put(path,parse): add an entry to the cache
" - get(path): retrieve an entry from the cache
" - has(path): check if an entry is present in the cache and up-to-date
func! omnicpp#cache#Create()
    return {'entries': {},
                \ 'put': function('omnicpp#cache#Put'),
                \ 'get': function('omnicpp#cache#Get'),
                \ 'has': function('omnicpp#cache#Has')}
endfunc
