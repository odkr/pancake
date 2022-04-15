package = 'Pancake'
version = 'VERSION-0'
rockspec_format = '3.0'

source = {
    url = 'git://github.com/odkr/pancake',
    branch = 'main',
    tag = 'TAG',
}

description = {
    summary = 'Toolkit to write Lua filters for Pandoc.',
    detailed = [[DESCRIPTION]],
    labels = {'pandoc', 'filter'},
    license = "MIT",
    homepage = "https://github.com/odkr/pancake",
    issues_url = "https://github.com/odkr/pancake/issues"
}

dependencies = {
    'lua >= 5.3, <6'
}

build = {
    type = 'builtin',
    modules = {pancake = 'pancake.lua',},
    copy_directories = {'doc'}
}
