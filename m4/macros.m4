define(`concat', `$1$2')dnl
ifdef(`TAG', `', `define(TAG, concat(`v', VERSION))')dnl
define(`DESCRIPTION', `Pancake aides with:

* maintaining compatibility accross different versions of Pandoc
* working with complex data structures
* error handling
* string interpolation
* object-oriented programming
* file I/O and filesystem interaction
* metadata parsing (i.e., configuration)')dnl
