package = "Pancake"
version = "VERSION-0"
source = {
   url = 'git://github.com/odkr/pancake',
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
* metadata parsing (i.e., configuration)]],
   labels = {'pandoc', 'filter'}
   homepage = "https://github.com/odkr/pancake",
   license = "MIT"
}

dependencies = {
   "lua >= 5.3, <6"
}

build = {
   type = "builtin",
   modules = {
      pancake = 'pancake.lua',
   },
   copy_directories = {'doc'}
}
