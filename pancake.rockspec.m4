define(`concat', `$1$2')dnl
define(`lower', `translit(`$1', `A-Z', `a-z')')dnl
define(PACKAGE, lower(NAME))dnl
define(TAG, concat(`v', VERSION))dnl

package = "NAME"
version = "VERSION-0"
source = {
   url = 'git://github.com/odkr/PACKAGE',
   branch = 'main',
   tag = 'TAG',
}

description = {
   summary = 'Toolkit to write Lua filters for Pandoc.',
   detailed = [[Pancake aides with

* maintaining compatibility accross different versions of Pandoc
* working with complex data structures
* error handling
* string interpolation
* object-oriented programming
* file I/O and filesystem interaction
* metadata parsing]],
   homepage = "https://github.com/odkr/PACKAGE",
   license = "MIT"
}

dependencies = {
   "lua >= 5.3, <6"
}

build = {
   type = "builtin",
   modules = {
      pancake = 'pancake/pancake.lua',
   },
   copy_directories = { 'doc' }
}
