# Pancake

Toolkit for writing Lua filters in Pandoc.

Only useful for complex filters.

Takes care of loading Pandoc modules in older versions of Pandoc,
but modifies the global environment to do so.

If you set up a custom global environment,
you should `require` pancake before doing so.
