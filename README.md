# Pancake

Toolkit for writing [Lua filters](https://pandoc.org/lua-filters.html)
for [Pandoc](https://pandoc.org). It is lightweight, well-documented,
and well-tested.

*Pancake* aides with

* maintaining compatibility accross different versions of Pandoc
* working with complex data structures
* error handling
* string interpolation
* object-oriented programming
* file I/O and filesystem interaction
* metadata parsing

See its [documentation](https://odkr.github.io/pancake/) for details.


## Requirements

*Pancake* requires [Pandoc](https://www.pandoc.org/) ≥ v2.0.4.
It should work under every operating system supported by Pandoc.

Your version of Pandoc must also support [Lua](https://www.lua.org/) ≥ v5.3.
Pandoc ≥ v2 does so by default. However, the Pandoc package provided by
your operating system vendor may use an older version. Notably, the version
of Pandoc available in the package repository of Debian v10 ("Buster") only
supports Lua v5.1.

That said, *Pancake* has only been tested with Pandoc v2.9–v2.18
and only on Linux and macOS.


## Installation

You use *Pancake* at your own risk.

1. Download the
   [latest release](https://github.com/odkr/pancake/releases/latest).
2. Unpack it.
3. Move `pancake.lua` to a directory from where your filter can load it.

The most recent release is v1.0.0b7.


## Documentation

See the [source code documentation](https://odkr.github.io/pancake/),
and the [source code](pancake) itself for details.


## Contact

If there's something wrong with *Pancake*, please
[open an issue](https://github.com/odkr/pancake/issues).


## Testing

The test suite requires:

1. A POSIX-compliant operating system.
2. [Pandoc](https://www.pandoc.org/) ≥ v2.
3. [LuaUnit](https://github.com/bluebird75/luaunit).
4. [GNU Make](https://www.gnu.org/software/make/).


Simply say:

```sh
    make
```

## License

Copyright 2018–2022 Odin Kroeger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Further Information

GitHub: <https://github.com/odkr/pancake>
