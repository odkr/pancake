project = 'Pancake'
description = 'Toolkit to write Lua filters for Pandoc.'
full_description = [[Provides:

* parsing of document metadata
* error handling
* convenience functions for lists, mappings, strings, paths, and file I/O
* a simple but powerful OO-model
* an API that is stable accross different versions of Pandoc]]

readme = 'README.md'
format = 'discount'
dir = 'docs'

backtick_references = false

new_type('object', 'Prototypes', false)

custom_tags = {
    {'caveats', title = 'Caveats'},
    {'proto', title = 'Prototype'},
    {'require', title = 'Requires'},
    {'side', title = 'Side-effects'},
    {'tip', title = 'Tip'}
}
