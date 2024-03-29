--- unit-tests.lua - A fake Pandoc filter that runs unit tests.
--
-- SYNOPSIS
-- ========
--
-- **pandoc** **-L** *unit-tests.lua* -o /dev/null /dev/null
--
-- DESCRIPTION
-- ===========
--
-- A fake Pandoc filter that runs unit tests for Pancake. Which tests are run
-- depends on the `test` metadata field, which is passed as is to
-- `lu.LuaUnit.run`. If it is not set, all tests are run.
--
-- SEE ALSO
-- ========
--
-- <https://luaunit.readthedocs.io/>
--
-- @script unit-tests.lua
-- @author Odin Kroeger
-- @copyright 2022 Odin Kroeger
-- @license MIT

--- Initialisation
-- @section

-- luacheck: allow defined top
-- luacheck: globals PANDOC_SCRIPT_FILE PANDOC_VERSION pandoc
-- luacheck: ignore CHECK_TYPES

--- Enable type-checking.
CHECK_TYPES = true

-- Libraries.

do
    local path_sep = package.config:sub(1, 1)
    local function path_join(...) return table.concat({...}, path_sep) end

    -- The directory of this script.
    local scpt_dir = PANDOC_SCRIPT_FILE:match('(.*)' .. path_sep)

    -- The directory of the test suite.
    local test_dir = path_join(scpt_dir, '..')

    -- The repository directory.
    local repo_dir = path_join(test_dir, '..')

    --- The test suite's data directory.
    DATA_DIR = path_join(test_dir, 'data')

    --- The test suite's tempory directory.
    TMP_DIR = os.getenv 'TMPDIR' or path_join(test_dir, 'tmp')

    do
        package.path = table.concat({package.path,
            path_join(repo_dir, '?.lua'),
            path_join(repo_dir, 'share', 'lua', '5.4', '?.lua')
        }, ';')
    end
end

local lu = require 'luaunit'
local M = require 'pancake'

--- Shorthands.
local concat = table.concat
local pack = table.pack
local unpack = table.unpack

local List = pandoc.List
local Header = pandoc.Header
local MetaInlines = pandoc.MetaInlines
local MetaMap = pandoc.MetaMap
local Null = pandoc.Null
local Pandoc = pandoc.Pandoc
local Para = pandoc.Para
local Str = pandoc.Str
local Strong = pandoc.Strong

local map = List.map
local stringify = pandoc.utils.stringify

local assert_equals = lu.assert_equals
local assert_error = lu.assert_error
local assert_not_equals = lu.assert_not_equals
local assert_error_msg_equals = lu.assert_error_msg_equals
local assert_error_msg_matches = lu.assert_error_msg_matches
local assert_false = lu.assert_false
local assert_items_equals = lu.assert_items_equals
local assert_nil = lu.assert_nil
local assert_not_nil = lu.assert_not_nil
local assert_str_matches = lu.assert_str_matches
local assert_true = lu.assert_true


--- Functions
-- @section

--- Return the given arguments.
--
-- @param ... Arguments.
-- @return The same arguments.
function id (...) return ... end

--- Return `nil`.
--
-- @treturn nil `nil`.
function nilify () return end

--- Read a Markdown file.
--
-- @tparam string fname A filename.
-- @treturn[1] pandoc.Pandoc A Pandoc AST.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number.
-- @raise An error if the file is not valid Markdown.
--  This error can only be caught since Pandoc v2.11.
function read_md_file (fname)
    assert(fname, 'no filename given')
    assert(fname ~= '', 'given filename is the empty string')
    local f, md, ok, err, errno
    f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    md, err, errno = f:read('a')
    if not md then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return pandoc.read(md, 'markdown')
end

--- Generate the list of all partial lists of a list.
--
-- @tab list A list.
-- @treturn tab The list of all partial lists of the list.
function powerset (list)
    local power = {{}}
    for i = 1, #list do
        local size = #power
        for j = 1, size do
            local old = power[j]
            local new = {}
            local osize = #old
            for k = 1, osize do new[k] = old[k] end
            new[osize + 1] = list[i]
            size = size + 1
            power[size] = new
        end
    end
    return power
end


--- Tests
-- @section

-- Type checking.

do
    local err_pattern = '.-%f[%a]expected [%a%s]+, got %a+%.$'
    local values = {
        ['nil'] = {nil},
        ['boolean'] = {true, false},
        ['number'] = {math.huge * -1, 0, 1, math.huge},
        ['string'] = {''},
        ['table'] = {{}},
        ['function'] = {function () end},
        ['thread'] = {coroutine.create(function () end)}
    }
    local type_lists = powerset(M.keys(values))

    function make_type_match_test (func)
        return function ()
            local cycle = {}
            cycle[1] = cycle

            for args, pattern in pairs{
                [{true, true}] =
                    '.-%f[%a]expected string or table, got boolean.',
                [{cycle, cycle}] =
                    '.-%f[%a]cycle in data tree.',
            } do
                local val, td = unpack(args)
                assert_error_msg_matches(pattern, func, val, td, true)
            end

            local ok, err
            for i = 1, #type_lists do
                local type_list = type_lists[i]
                local type_spec = concat(type_list, '|')
                for t, vs in pairs(values) do
                    for j = 1, #vs do
                        local v = vs[j]
                        local opt_type_spec = '?' .. type_spec
                        local star_spec = '*|' .. type_spec
                        if type_spec:match(t) then
                            for _, ts in pairs{
                                type_spec,
                                opt_type_spec,
                                star_spec
                            } do
                                for _, argv in pairs{
                                    {v, ts},
                                    {{foo = v}, {foo = ts}}
                                } do
                                    ok, err = func(unpack(argv))
                                    assert_nil(err)
                                    assert_true(ok)
                                end
                            end
                        elseif type_spec ~= '' then
                            for _, argv in pairs{
                                {v, type_spec},
                                {{foo = v}, {foo = type_spec}}
                            } do
                                ok, err = func(unpack(argv))
                                assert_true(ok == nil or ok == false)
                                assert_str_matches(err, err_pattern)
                                if v == nil then
                                    ok, err = func(unpack(argv))
                                    assert_nil(err)
                                    assert_true(ok)
                                else
                                    ok, err = func(unpack(argv))
                                    assert_true(ok == nil or ok == false)
                                    assert_str_matches(err, err_pattern)
                                end
                            end

                        end
                    end
                end

                local args = {}
                local opt_type_list = {}
                local star_list = {}
                for j = 1, #type_list do
                    args[j] = values[type_list[j]][1]
                    opt_type_list[j] = '?' .. type_list[j]
                    star_list[j] = '*|' .. type_list[j]
                end
                for _, tl in pairs{type_list, opt_type_list, star_list} do
                    ok, err = func(args, tl)
                    assert_nil(err)
                    assert_true(ok)
                end
            end

            for _, vs in pairs(values) do
                for i = 1, #vs do
                    local v = vs[i]
                    for _, argv in pairs{
                        {v, '*'},
                        {{foo = v}, {foo = '*'}}
                    } do
                        if v == nil then
                            ok, err = func(unpack(argv))
                            assert_true(ok == nil or ok == false)
                            assert_str_matches(err, err_pattern)
                        else
                            ok, err = func(unpack(argv))
                            assert_nil(err)
                            assert_true(ok)
                        end
                    end
                    for _, argv in pairs{
                        {v, '?*'},
                        {{foo = v}, {foo = '?*'}}
                    } do
                        ok, err = func(unpack(argv))
                        assert_nil(err)
                        assert_true(ok)
                    end
                end
            end

            for argv, pattern in pairs{
                [{{1, '2'}, {'number', 'number'}}] =
                    '.-%f[%a]index 2: expected number, got string%.$',
                [{{foo = 'bar'}, {foo = '?table'}}] =
                    '.-%f[%a]index foo: expected table or nil, got string%.$',
                [{'foo', {foo = '?table'}}] =
                    '.-%f[%a]expected table or userdata, got string%.$'
            } do
                ok, err = func(unpack(argv))
                assert_true(ok == nil or ok == false)
                assert_str_matches(err, pattern)
            end
        end
    end

    -- luacheck: ignore test_type_match
    test_type_match = make_type_match_test(function(val, td)
        return M.type_match(val, td)
    end)

    -- luacheck: ignore test_type_check
    function test_type_check ()
        local type_check = M.type_check

        make_type_match_test(function (val, td, unprotected)
            local func = type_check(td)(nilify)
            if unprotected then return func(val) end
            return pcall(func, val)
        end)()

        for t, vs in pairs(values) do
            local func = M.type_check(t, '...')(nilify)
            local ok, err
            for i = 1, #vs do
                local v = vs[i]
                for _, args in ipairs{
                    {v, nil, v},
                    {v, v},
                    {v, v, nil},
                    {v, v, v}
                } do
                    ok, err = pcall(func, unpack(args))
                    assert_nil(err)
                    assert_true(ok)
                end
                for at, avs in pairs(values) do
                    if at ~= t then
                        for j = 1, #avs do
                            local av = avs[j]
                            if av ~= nil then
                                for _, args in ipairs{
                                    {v, av},
                                    {v, av, v},
                                    {v, v, av},
                                    {v, av, av},
                                    {v, v, v, av}
                                } do
                                    ok, err = pcall(func, unpack(args))
                                    assert_false(ok)
                                    assert_str_matches(err, err_pattern)
                                end
                            end
                        end
                    end
                end
            end
        end

        local store = type_check('*', 'table', '?number', '...')(
            function (val, tab, ...)
                 local indices = table.pack(...)
                 for i = 1, indices.n do tab[indices[i]] = val end
            end
        )

        local tab = {}
        store(true, tab, 1)
        assert_true(tab[1])

        assert_error_msg_matches('argument 2: expected table, got boolean%.',
            store, false, true, 1)
        assert_error_msg_matches('argument 3: expected number or nil, got string%.',
            store, false, tab, '1')
        assert_error_msg_matches('argument 4: expected number or nil, got string.',
            store, false, tab, 1, '2')
        return true
    end
end


-- Errors.

-- luacheck: ignore test_asserter
function test_asserter ()
    -- luacheck: ignore assert
    local assert = M.asserter()

    assert_true(pcall(assert, true))
    assert_error_msg_matches('^foo$', assert, false, 'foo')

    local function msgh () return 'bar' end
    assert = M.asserter(nil, msgh)
    assert_true(pcall(assert, true))
    assert_error_msg_matches('^bar$', assert, false, 'foo')

    local var = false
    local function fin () var = true end
    assert = M.asserter(fin)
    assert_true(pcall(assert, true))
    assert_error_msg_matches('^foo$', assert, false, 'foo')
    assert_true(var)

    var = false
    assert = M.asserter(fin, msgh)
    assert_true(pcall(assert, true))
    assert_error_msg_matches('^bar$', assert, false, 'foo')
    assert_true(var)

    local assert = M.asserter(nil, M.vars_sub)
    local function foo ()
        -- luacheck: ignore bar
        local bar = 'The bar'
        assert(false, '${bar} is to blame!')
    end

    assert_error_msg_equals('The bar is to blame!', foo)
end

-- luacheck: ignore test_protect
function test_protect ()
    local panic = M.protect(function () error 'foo' end)
    local fail = M.protect(function () return nil, 'foo' end)
    local succ = M.protect(function () return true end)

    local ok, err
    ok, err = panic()
    assert_nil(ok)
    assert_str_matches(err, '.-%f[%a]foo')
    ok, err = fail()
    assert_nil(ok)
    assert_equals(err, 'foo')
    ok, err = succ()
    assert_nil(err)
    assert_true(ok)

    local foo = M.protect(function () return 'foo' end)
    assert_equals(foo(), 'foo')
    local boo = M.protect(function () error 'bar!' end)
    ok, err = boo()
    assert_nil(ok)
    assert_str_matches(err, '.-%f[%a]bar!')
end

-- luacheck: ignore test_unprotect
function test_unprotect ()
    local panic = M.unprotect(function () error 'foo' end)
    local fail = M.unprotect(function () return nil, 'foo' end)
    local succ = M.unprotect(function () return true end)

    assert_error_msg_matches('.-%f[%a]foo$', panic)
    assert_error_msg_matches('.-%f[%a]foo$', fail)
    local ok, err = succ()
    assert_nil(err)
    assert_true(ok)
end


-- Tables.

-- luacheck: ignore test_copy
function test_copy ()
    local tab, cp

    -- Test simple copies.
    for _, val in ipairs{
        nil, false, true, 0, 1, '', 'test', {},
        {1, 2, 3},
        {5, 2, 3, 9},
        {1, 2, 3, 'b', true, false},
        {1, 2, 'x', false, 3, true},
        (function ()
            local t = {}
            for i = 1, 1000 do t[i] = i end
            return t
            end)(),
        {true},
        {false},
        {true, false, true},
        {'a', 'b', 'c'},
        (function ()
            local t = {}
            for i = 33, 126 do t[i-32] = string.char(i) end
            return t
            end)(),
    } do
        -- luacheck: ignore cp
        local cp = M.copy(val)
        assert_items_equals(cp, val)
    end

    -- Test a nested table.
    tab = {1, 2, 3, {1, 2, 3, {4, 5, 6}}}
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a self-referential table.
    tab = {1, 2, 3}
    tab.tab = tab
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a table that has another table as key.
    tab = {1, 2, 3}
    local other_tab = {1, 2, 3, {4, 5, 6}}
    other_tab[tab] = 7
    cp = M.copy(other_tab)
    assert_items_equals(cp, other_tab)

    -- Test a table that overrides `__pairs`.
    local single = {__pairs = function ()
        return function () end
    end}
    tab = setmetatable({1, 2, 3}, single)
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a table that does all of this.
    tab = setmetatable({1, 2, 3, {4, 5}}, single)
    other_tab = {1, 2, 3, {4, 5, 6}}
    tab[other_tab] = {1, 2, 3, {4, 5}}
    tab.tab = tab
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test the example.
    local foo = {1, 2, 3}
    local bar = {foo, 4}
    local baz = M.copy(bar)
    foo[#foo + 1] = 4
    assert_items_equals(baz[1], {1, 2, 3})

end

-- luacheck: ignore test_keys
function test_keys ()
    for input, output in pairs{
        [{}] =        {keys = {},        n = 0},
        [{1, 2, 3}] = {keys = {1, 2, 3}, n = 3},
        [{a = 1, b = 2, c = 3}] = {
            keys = {'a', 'b', 'c'},
            n = 3
        },
        [{a = 1, [{}] = 2}] = {
            keys = {'a', {}},
            n = 2
        },
        [{[{}]='a'}] = {keys = {{}},     n = 1},
        [{[{}]='a', [false]='b'}] = {
            keys = {{}, false},
            n = 2
        }
    } do
        local keys, n = M.keys(input)
        assert_items_equals(keys, output.keys)
        assert_equals(n, output.n)
    end
end

-- luacheck: ignore test_order
function test_order ()
    for input, output in pairs{
        [{order = {3},    data = {1, 2, 3}}] = {3, 1, 2},
        [{order = {},     data = {3, 2, 1}}] = {1, 2, 3},
        [{order = {3, 2}, data = {1, 2, 3}}] = {3, 2, 1},
        [{order = {3, 2}, data = {}}] = {},
        [{order = {},     data = {}}] = {}
    } do
        local func = M.order(input.order)
        table.sort(input.data, func)
        assert_equals(input.data, output)
    end

    local tab = {a = 3, b = 4, c = 2, d = 1}
    local out = {}
    for k, v in M.sorted(tab, M.order{'d', 'c'}) do
        out[#out + 1] = {[k] = v}
    end
    assert_items_equals(out, {{d = 1}, {c = 2}, {a = 3}, {b = 4}})
end

-- luacheck: ignore test_sorted
function test_sorted ()
    local unsorted = {c=3, F=9, another=1}
    local order = {'F', 'another', 'c'}
    local i = 0
    for k, v in M.sorted(unsorted) do
        i = i + 1
        assert_equals(k, order[i])
        assert_equals(v, unsorted[k])
    end

    i = 0
    for k, v in M.sorted(unsorted, M.order(order)) do
        i = i + 1
        assert_equals(k, order[i])
        assert_equals(v, unsorted[k])
    end

    local function rev (a, b) return b < a end
    i = select(2, M.keys(unsorted))
    for k, v in M.sorted(unsorted, rev) do
        assert_equals(k, order[i])
        assert_equals(v, unsorted[k])
        i = i - 1
    end

    local mt = {}
    setmetatable(unsorted, mt)
    mt.__pairs = M.sorted
    i = 0
    for k, v in pairs(unsorted) do
        i = i + 1
        assert_equals(k, order[i])
        assert_equals(v, unsorted[k])
    end

    mt.__pairs = M.sorted
    i = 0
    for k, v in M.sorted(unsorted) do
        i = i + 1
        assert_equals(k, order[i])
        assert_equals(v, unsorted[k])
    end

    mt.__pairs = error
    assert_error(M.sorted, unsorted)
    assert_error(M.sorted, unsorted, false)
    assert_not_nil(M.sorted, unsorted, true)

    local tab = {c = 3, b = 2, a = 1}
    local out = {}
    for k, v in M.sorted(tab) do out[#out + 1] = {[k] = v} end
    assert_items_equals(out, {{a = 1}, {b = 2}, {c = 3}})

    out = {}
    for k, v in M.sorted(tab, M.order{'c', 'b', 'a'}) do
        out[#out + 1] = {[k] = v}
    end
    assert_items_equals(out, {{c = 3}, {b = 2}, {a = 1}})

    mt = {sort = M.order{'c', 'b', 'a'}}
    setmetatable(tab, mt)
    out = {}
    for k, v in M.sorted(tab) do out[#out + 1] = {[k] = v} end
    assert_items_equals(out, {{c = 3}, {b = 2}, {a = 1}})

    mt.__pairs = M.sorted
    out = {}
    for k, v in pairs(tab) do out[#out + 1] = {[k] = v} end
    assert_items_equals(out, {{c = 3}, {b = 2}, {a = 1}})
end

-- luacheck: ignore test_tabulate
function test_tabulate ()
    local function stateless_iter (n)
        local i = 0
        return function ()
            if i >= n then return end
            i = i + 1
            return i
        end
    end

    for input, output in pairs {
        [{stateless_iter(0)}] = {n = 0},
        [{stateless_iter(1)}] = {1, n = 1},
        [{stateless_iter(3)}] = {1, 2, 3, n = 3},
        [{next, {}}] = {n = 0},
        [{next, {a = true}}] = {'a', n = 1},
        [{next, {a = true, b = true, c = true}}] = {'a', 'b', 'c', n = 3},
        [{function () end}] = {n = 0}
    } do
        assert_items_equals(M.tabulate(unpack(input)), output)
    end
end

-- luacheck: ignore test_update
function test_update ()
    local tab = {foo = 'bar'}
    local other_tab = {bar = 'baz', baz = {}}
    M.update(tab, other_tab)
    assert_items_equals(tab, {foo = 'bar', bar = 'baz', baz = {}})
    assert_nil(other_tab.foo)
    table.insert(tab.baz, 'bam!')
    assert_equals(other_tab.baz[1], 'bam!')

    tab = {a = true, b = true, c = true}
    assert_items_equals(M.tabulate(next, tab), {'a', 'b', 'c', n = 3})
end

-- luacheck: ignore test_walk
function test_walk ()
    local cycle = {}
    cycle.cycle = cycle

    for _, val in ipairs{{{}}, 0, false, {[false]=0}, 'string', cycle} do
        assert_equals(M.walk(val, id), val)
        assert_equals(M.walk(val, nilify), val)
    end

    local function inc (v)
        if type(v) ~= 'number' then return v end
        return v + 1
    end

    for input, output in pairs{
        [{{}}] = {{}},
        [1] = 2,
        [false] = false,
        [{['false'] = 1}] = {['false'] = 2},
        [{{{[false] = true}, 0}}] = {{{[false] = true}, 1}},
        ['string'] = 'string',
        [{1}] = {2},
        [{2}] = {3},
        [{1, {2}}] = {2, {3}},
        [{dont = 3, 3}] = {dont = 4, 4}
    } do
        assert_equals(M.walk(input, inc), output)
    end
end


-- Strings.

-- luacheck: ignore test_split
function test_split ()
    for input, message in pairs{
        [{'string', 'pattern', nil, 'x'}] = '.-%f[%a]x: no such option%.$'
    } do
        assert_error_msg_matches(message, M.split, unpack(input))
    end

    for input, output in pairs{
        [{'string', '%s*:%s*'}] = {'string', n = 1},
        [{'key: value:', '%s*:%s*'}] = {'key', 'value', '', n = 3},
        [{'val, val, val', ',%s*'}] = {'val', 'val', 'val', n = 3},
        [{', val , val', '%s*,%s*'}] = {'', 'val', 'val', n = 3},
        [{'key: value', ': '}] = {'key', 'value', n = 2},
        [{'key: value:x', '%s*:%s*', 2}] = {'key', 'value:x', n = 2},
        [{'val, val, val', ',%s*', 2}] = {'val', 'val, val', n = 2},
        [{'CamelCaseTest', '%u', nil, 'l'}] =
            {'Camel', 'Case', 'Test', n = 3},
        [{'CamelCaseTest', '%u', nil, 'r'}] =
            {'C', 'amelC', 'aseT', 'est', n = 4},
        [{'CamelCaseTest', '%u', 2, 'l'}] =
            {'Camel', 'CaseTest', n = 2},
        [{'CamelCaseTest', '%u', 2, 'r'}] =
            {'C', 'amelCaseTest', n = 2},
        [{'foobar', '[fb]', nil, 'l'}] = {'foo', 'bar', n = 2},
        [{'foobar', '[fb]', nil, 'r'}] = {'f', 'oob', 'ar', n = 3},
        [{'foo*bar', '*', nil, 'P'}] = {'foo', 'bar', n = 2},
        [{'foo.*bar', '.*', nil, 'P'}] = {'foo', 'bar', n = 2},
        [{'$a$$b$c', '%f[%$]%$'}] = {'', 'a', '$b', 'c', n = 4},
        [{'foo', ''}] = {'', 'f', 'o', 'o', '', n = 5},
        [{'foo1bar2baz', '%f[%d]'}] = {'foo', '1bar', '2baz', n = 3},
        [{'foobar', '[bo]*'}] = {'', 'f', '', 'a', 'r', '', n = 6},
        [{'abc', 'b*'}] = {'', 'a', '', 'c', '', n = 5},
        [{'foobar', '[bo]*', nil, 'l'}] = {'f', 'ooba', 'r', n = 3},
        [{'foobar', '[bo]*', nil, 'r'}] = {'foob', 'a', 'r', n = 3},
        [{'foobar', '[bo]*', nil, 'Pr'}] = {'foobar', n = 1},
        [{'CamelCase', '%f[%u]'}] = {'', 'Camel', 'Case', n = 3},
        [{'CamelCase', '%f[%u]', nil, 'E'}] = {'Camel', 'Case', n = 2}
    } do
        assert_items_equals(M.tabulate(M.split(unpack(input))), output)
    end
end


-- Variables.

-- luacheck: ignore test_vars_get
function test_vars_get ()
    for level, message in pairs{
        [-1] = '.-%f[%a]level is not a positive number%.',
        [1048576] = '.-%f[%a]stack is not that high%.$',
    } do
        assert_error_msg_matches(message, M.vars_get, level)
    end

    local function bar ()
        assert_equals(M.vars_get(3).foo, 'foo')
    end
    local function foo ()
        -- luacheck: ignore foo
        local foo = 'foo'
        bar()
    end
    foo()

    local function bar_rw ()
        -- luacheck: ignore foo
        local foo = M.vars_get(3).foo
        assert_equals(foo.bar, 'bar')
        foo.bar = 'bam!'
    end
    local function foo_rw ()
        -- luacheck: ignore foo
        local foo = {bar = 'bar'}
        bar_rw()
        assert_equals(foo.bar, 'bar')
    end
    foo_rw()
end

-- luacheck: ignore test_vars_sub
function test_vars_sub ()
    for input, message in pairs{
        [{'${a}', {a = '${b}', b = '${a}'}}] =
            '.-%f[%$]${a}: ${b}: ${a}: cycle in lookup%.',
        [{'${}', {}}] =
            '.-%f[%$]${}: name is the empty string%.',
        [{'${foo|}', {foo = true}}] =
            '.-%f[%$]${foo|}: name is the empty string%.',
        [{'${.foo}', {}}] =
            '.-%f[%$]${.foo}: name starts with a dot%.',
        [{'${foo|.bar}', {foo = true}}] =
            '.-%f[%$]${foo|.bar}: name starts with a dot%.',
        [{'${foo.}', {}}] =
            '.-%f[%$]${foo.}: name ends with a dot%.',
        [{'${foo|bar.}', {foo = true}}] =
            '.-%f[%$]${foo|bar.}: name ends with a dot%.',
        [{'${foo..bar}', {foo = {}}}] =
            '.-%f[%$]${foo..bar}: foo.: consecutive dots%.',
        [{'${foo bar}', {}}] =
            '.-%f[%$]${foo bar}: foo bar: illegal name%.',
        [{'${foo}', {}}] =
            '.-%f[%$]${foo}: foo: is undefined%.',
        [{'${foo|bar}', {foo = ''}}] =
            '.-%f[%$]${foo|bar}: bar: is undefined%.',
        [{'${foo.bar}', {}}] =
            '.-%f[%$]${foo.bar}: foo: expected table, got nil%.',
        [{'${foo.bar.baz}', {foo = {}}}] =
        '.-%f[%$]${foo.bar.baz}: foo.bar: expected table, got nil%.',
        [{'${foo.bar}', {foo = 'string'}}] =
            '.-%f[%$]${foo.bar}: foo: expected table, got string%.',
        [{'${foo|bar}', {foo = 'bar', bar = 'bar'}}] =
            '${foo|bar}: bar: not a function.',
        [{'${foo|bar.baz}', {foo = 'bar'}}] =
            '${foo|bar.baz}: bar: expected table, got nil%.',
        [{'${foo}', {foo = true}}] =
            '${foo}: expected number or string, got boolean%.'
    } do
        local ok, err = M.vars_sub(unpack(input))
        assert_nil(ok)
        assert_str_matches(err, message)
    end

    for input, output in pairs{
        [{'$${test}$', {test = 'nok'}}] = '${test}$',
        [{'${test}$', {test = 'ok'}}] = 'ok$',
        [{'$${test|func}', {
            test = 'nok',
            func = function ()
                return 'NOK'
            end }}] = '${test|func}',
        [{'${test|func}', {
            test = 'nok',
            func = function (s)
                return s:gsub('nok', 'ok')
            end }}] = 'ok',
        [{'${test.test}', {
            test = { test = 'ok' }
        }}] = 'ok',
        [{'${test.test.test.test}', {
            test = { test = { test = { test ='ok' } } }
        }}] = 'ok',
        [{'${test|func}', {
            test = 'nok',
            func = function (s)
                return s:gsub('nok', '${v2|f2}')
            end,
            v2 = 'nok2',
            f2 = function (s)
                return s:gsub('nok2', 'ok')
            end
        }}] = '{v2|f2}',
        [{'${test.test.test|test.func}', {
            test = {
                test = {test = 'nok'},
                func = function (s)
                    return s:gsub('nok', '${v2|f2}')
                end
            },
            v2 = 'nok2',
            f2 = function (s)
                return s:gsub('nok2', 'ok')
            end
        }}] = '{v2|f2}',
        [{'${foo|bar|baz}', {
            foo = 'foo',
            bar = function (s) return s:gsub('foo', 'bar') end,
            baz = function (s) return s:gsub('bar', 'baz') end,
        }}] = 'baz',
        [{'${foo}${bar}', function (s)
            return s .. '!'
        end}] = 'foo!bar!'
    } do
        assert_equals(M.vars_sub(unpack(input)), output)
    end

    assert_equals(M.vars_sub(
        '${v1} is ${v2}.',
        {v1 = 'foo', v2 = 'bar'}
    ), 'foo is bar.')

    assert_equals(M.vars_sub(
        '$${var} costs $1.',
        {var = 'foo'}
    ), '${var} costs $1.')

    assert_equals(M.vars_sub(
        '${foo.bar} is baz.', {
            foo = { bar = 'baz' }
        }
    ), 'baz is baz.')

    assert_equals(M.vars_sub(
        '${var|barify} is bar!', {
            var = 'foo',
            barify = function (s)
                return s:gsub('foo', 'bar')
            end
        }
    ), 'bar is bar!')

    assert_equals(M.vars_sub(
        '${foo|barify} is bar.', {
            foo = '${bar}',
            bar = 'baz',
            barify = function (s) return s:gsub('baz', 'bar') end
        }
    ), 'bar is bar.')

    assert_equals(M.vars_sub(
        '${foo} is bar.',
        function (key)
            if key == 'foo' then return 'bar' end
        end
    ), 'bar is bar.')
end

-- luacheck: ignore test_env_sub
function test_env_sub ()
    for input, message in pairs{
        ['${}'] = '.-%f[%$]${}: variable name is the empty string%.',
        ['${.foo}'] = '.-%f[%$]${.foo}: illegal variable name%.',
        ['${foo.}'] = '.-%f[%$]${foo.}: illegal variable name%.',
        ['${foo..bar}'] = '.-%f[%$]${foo..bar}: illegal variable name%.',
        ['${foo bar}'] =  '.-%f[%$]${foo bar}: illegal variable name%.',
        ['${foo}'] = '.-%f[%$]${foo}: is undefined%.',
    } do
        local ok, err = M.env_sub(input)
        assert_nil(ok)
        assert_str_matches(err, message)
    end

    for input, output in pairs{
        ['${HOME}'] = os.getenv('HOME'),
        ['${TMPDIR}'] = os.getenv('TMPDIR'),
    } do
        assert_equals(M.env_sub(input), output)
    end
end

-- Metatables.

-- luacheck: ignore test_no_case
function test_no_case ()
    local tab = setmetatable({}, M.no_case)

    local str = 'mIxEd'
    for i, new_index in ipairs{
        str,
        str:lower(),
        str:upper()
    } do
        tab[new_index] = i
        for _, index in ipairs{
            new_index,
            new_index:lower(),
            new_index:upper()
        } do
            assert_equals(tab[index], i)
        end
    end

    for i, non_str in ipairs{
        true, false,
        -math.huge, -1, 0, 1, math.huge,
        {}, {{}},
        function () end,
        coroutine.create(function () end)
    } do
        tab[non_str] = i
        assert_equals(tab[non_str], i)
    end

    tab = setmetatable({}, M.no_case)
    tab.FOO = 'bar'
    assert_equals(tab.foo, 'bar')
end

-- Prototypes.

-- luacheck: ignore test_object_clone
function test_object_clone ()
    local tab = {foo = 'yo'}
    local obj_mt = {foo = true, bar = {baz = true}}
    local Foo = M.Object:clone(tab, obj_mt)
    local mt = getmetatable(Foo)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, true)
    obj_mt.baz = true
    assert_nil(mt.baz)
    obj_mt.bar.baz = false
    assert_equals(mt.bar.baz, false)
    assert_equals(tab.foo, 'yo')
    assert_equals(Foo, tab)

    local Bar = Foo:clone()
    mt = getmetatable(Bar)
    assert_equals(mt.__index, Foo)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)

    local baz = Bar:clone({}, {__index = M.Object})
    mt = getmetatable(baz)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)

    local obj_mt2 = {baz = true}
    local Baz = M.Object:clone({}, obj_mt, obj_mt2)
    mt = getmetatable(Baz)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)
    assert_equals(mt.baz, true)

    Foo = M.Object:clone({}, {__tostring = function (t) return t.bar end})
    Foo.bar = 'bar'
    assert_equals(tostring(Foo), 'bar')
    local bar = Foo:clone()
    assert_equals(tostring(bar), 'bar')
    bar.bar = 'baz'
    assert_equals(tostring(bar), 'baz')
end

-- luacheck: ignore test_object_new
function test_object_new ()
    local args = {{foo = true}, {bar = false}}
    local a = M.Object:new(unpack(args))
    local b = M.update(M.Object:clone(), unpack(args))
    assert_items_equals(a, b)
    assert_items_equals(getmetatable(a), getmetatable(b))

    local foo = M.Object:new{foo = 'foo'}
    assert_equals(foo.foo, 'foo')
    local bar = foo:new{bar = 'bar'}
    assert_equals(bar.foo, 'foo')
    assert_equals(bar.bar, 'bar')
end

-- luacheck: ignore test_getterify
function test_getterify ()
    local tab = {}
    local mt = {getters = {bar = function () return true end}}
    setmetatable(tab, mt)
    assert_nil(tab.bar)
    local tab2 = M.getterify(tab)
    assert_equals(tab, tab2)
    assert_true(tab.bar)
    assert_true(tab2.bar)
    tab.bar = false
    assert_false(tab.bar)
    assert_false(tab2.bar)

    local Foo = M.getterify(M.Object:clone())
    Foo.foo = 'bar'
    mt = getmetatable(Foo)
    mt.getters = {}
    function mt.getters.bar (obj) return obj.foo end
    assert_equals(Foo.bar, 'bar')
    local baz = Foo()
    baz.foo = 'bam!'
    assert_equals(baz.bar, 'bar')
    Foo.clone = function (...) return M.getterify(M.Object.clone(...)) end
    baz = Foo()
    baz.foo = 'bam!'
    assert_equals(baz.bar, 'bam!')
    local bam = baz()
    bam.foo = 'BAM!'
    assert_equals(bam.bar, 'BAM!')
end


-- File I/O.

-- luacheck: ignore test_file_exists
function test_file_exists ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_exists, '')
    assert_true(M.file_exists(PANDOC_SCRIPT_FILE))
    local ok, _, errno = M.file_exists('<no such file>')
    assert_equals(errno, 2)
    assert_nil(ok)
end

-- luacheck: ignore test_file_locate
function test_file_locate ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_locate, '')

    local ok, err = M.file_locate('<no such file>')
    assert_nil(ok)
    assert_equals(err, '<no such file>: not found in resource path.')

    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        -- luacheck: ignore err
        local cwd = pandoc.system.get_working_directory()
        local path = PANDOC_SCRIPT_FILE:gsub('^' .. cwd .. M.PATH_SEP, '')
        local fname, err = M.file_locate(path)
        assert_nil(err)
        assert_equals(fname, PANDOC_SCRIPT_FILE)
    end
end

-- luacheck: ignore test_file_read
function test_file_read ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_read, '')

    local str, err, errno = M.file_read('<no such file>')
    assert_nil(str)
    assert_equals(err, '<no such file>: No such file or directory')
    assert_equals(errno,  2)

    local fname = M.path_join(DATA_DIR, 'foo.md')
    str, err, errno = M.file_read(fname)
    assert_nil(err)
    assert_nil(errno)
    assert_not_nil(str)
    assert_equals(str, 'This is a simple file.')
end

-- luacheck: ignore test_file_write
function test_file_write ()
    local funcs = {[M.__file_write_legacy] = true, [M.file_write] = true}
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        funcs[M.__file_write_modern] = true
    end

    math.randomseed(os.time())
    local max = 2 ^ 32

    for func in pairs(funcs) do
        assert_error_msg_matches('.-%f[%a]filename is the empty string.',
            M.file_write, '')

        -- pandoc.system.with_temporary_directory raises an uncatchable
        -- error if it cannot create the temporary directory.
        if func == M.__file_write_legacy then
            local ok, err, errno = func('<no such directory>/file', 'foo')
            assert_nil(ok)
            assert_str_matches(err, '.-No such file or directory.-')
            if errno ~= nil then assert_equals(errno, 2) end
        end

        local remove = os.remove
        local tmp_fname
        local _ = setmetatable({}, {__gc = function () remove(tmp_fname) end})

        tmp_fname = M.tmp_fname(TMP_DIR)
        local ok, err, errno = remove(tmp_fname)
        assert(ok or errno == 2, err)

        local wdata = string.pack('d', math.random(1, max))
        ok, err, errno = func(tmp_fname, wdata)
        assert_nil(err)
        assert_nil(errno)
        assert_true(ok)

        local rdata
        rdata, err, errno = M.file_read(tmp_fname)
        assert_nil(err)
        assert_nil(errno)
        assert_equals(rdata, wdata)
    end
end

-- luacheck: ignore test_tmp_fname
function test_tmp_fname ()
    for input, msg in pairs {
        [{'', nil}] =
            '.-%f[%a]directory is the empty string.',
        [{'', 'tmp'}] =
            '.-%f[%a]directory is the empty string.',
    } do
        assert_error_msg_matches(msg, M.tmp_fname, unpack(input))
    end

    for input, output in pairs{
        [{nil, nil}] = '^tmp%-%w%w%w%w%w%w$',
        [{nil, 'test_XXXXXXXXX'}] = '^test_%w%w%w%w%w%w%w%w%w$',
        [{'/tmp', nil}] = '^/tmp' .. M.PATH_SEP .. 'tmp%-%w%w%w%w%w%w$',
        [{'/tmp', 'XXXXXXX'}] = '^/tmp' .. M.PATH_SEP .. '%w%w%w%w%w%w%w$'
    } do
        local fname = assert(M.tmp_fname(unpack(input)))
        assert_str_matches(fname, output)
    end

    local fnames = {}
    for i = 1, 4 do
        fnames[i] = assert(M.tmp_fname())
        for j = 2, i do
            if i ~= j then assert_not_equals(fnames[i], fnames[j]) end
        end
    end
end

-- luacheck: ignore test_with_tmp_file
function test_with_tmp_file ()
    local remove = os.remove
    local tmp_fname
    local _ = setmetatable({}, {__gc = function () remove(tmp_fname) end})

    for input, msg in pairs {
        [{'', nil}] =
            '.-%f[%a]directory is the empty string.',
        [{'', 'tmp'}] =
            '.-%f[%a]directory is the empty string.',
    } do
        assert_error_msg_matches(msg, M.with_tmp_file, nilify, unpack(input))
    end

    local function wrap (func)
        return function (fname)
            tmp_fname = fname
            local file, ok, err, errno
            ok, err, errno = remove(tmp_fname)
            assert(ok or errno == 2, err)
            file = assert(io.open(fname, 'w'))
            assert(file:write('foo'))
            assert(file:flush())
            assert(file:close())
            assert(M.file_exists(fname))
            return func()
        end
    end

    for i, func in ipairs(map({
        function () return true end,
        function () return end,
        function () error() end
    }, wrap)) do
        tmp_fname = nil
        local res = M.with_tmp_file(func)
        assert_not_nil(tmp_fname)
        assert_not_equals(tmp_fname, '')
        if i == 1 then
            assert_equals(res, true)
            assert_true(remove(tmp_fname))
        else
            assert_nil(res)
            assert_nil(M.file_exists(tmp_fname))
        end
    end
end


-- Paths.

-- luacheck: ignore test_path_is_abs
function test_path_is_abs ()
    for input, output in pairs{
        [M.PATH_SEP]                  = true,
        [M.PATH_SEP .. 'test']        = true,
        ['test']                      = false,
        [M.path_join('test', 'test')] = false,
    } do
        assert_equals(M.path_is_abs(input), output)
    end

    if pandoc.types and PANDOC_VERSION >= {2, 12} then
        assert_equals(M.path_is_abs(M.path_make_abs('foo')), true)
    end
end

-- luacheck: ignore test_path_join
function test_path_join ()
    for input, output in pairs{
        [{'a', 'b'}] = 'a' .. M.PATH_SEP .. 'b',
        [{'a', 'b', 'c'}] = 'a' .. M.PATH_SEP .. 'b' .. M.PATH_SEP .. 'c',
        [{'a', M.PATH_SEP .. 'b'}]  = 'a' .. M.PATH_SEP .. 'b',
        [{'a' .. M.PATH_SEP, 'b'}]  = 'a' .. M.PATH_SEP .. 'b'
    } do
        assert_equals(M.path_join(unpack(input)), output)
    end

    assert_equals(M.path_join('foo', 'bar'), 'foo' .. M.PATH_SEP .. 'bar')
end

-- luacheck: ignore test_path_make_abs
if pandoc.types and PANDOC_VERSION >= {2, 12} then
    function test_path_make_abs ()
        assert_error_msg_matches('.-%f[%a]path is the empty string.',
            M.path_make_abs, '')

        for input, output in ipairs{
            foo = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. 'foo'] = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. M.PATH_SEP .. 'foo'] = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. 'foo' .. M.PATH_SEP] = M.PATH_SEP .. 'foo',
        } do
            assert_equals(M.path_make_abs(input), output)
        end
    end
end

-- luacheck: ignore test_path_normalise
function test_path_normalise ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_normalise, '')

    for input, output in pairs{
        ['.']                   = '.',
        ['..']                  = '..',
        ['/']                   = '/',
        ['//']                  = '/',
        ['/////////']           = '/',
        ['/.//////']            = '/',
        ['/.////.//']           = '/',
        ['/.//..//.//']         = '/..',
        ['/.//..//.//../']      = '/../..',
        ['a']                   = 'a',
        ['./a']                 = 'a',
        ['../a']                = '../a',
        ['/a']                  = '/a',
        ['//a']                 = '/a',
        ['//////////a']         = '/a',
        ['/.//////a']           = '/a',
        ['/.////.//a']          = '/a',
        ['/.//..//.//a']        = '/../a',
        ['/.//..//.//../a']     = '/../../a',
        ['a/b']                 = 'a/b',
        ['./a/b']               = 'a/b',
        ['../a/b']              = '../a/b',
        ['/a/b']                = '/a/b',
        ['//a/b']               = '/a/b',
        ['///////a/b']          = '/a/b',
        ['/.//////a/b']         = '/a/b',
        ['/.////.//a/b']        = '/a/b',
        ['/.//..//.//a/b']      = '/../a/b',
        ['/.//..//.//../a/b']   = '/../../a/b',
        ['/a/b/c/d']            = '/a/b/c/d',
        ['a/b/c/d']             = 'a/b/c/d',
        ['a/../.././c/d']       = 'a/../../c/d'
    } do
        assert_equals(M.path_normalise(input), output)
    end

    assert_equals(M.path_normalise './foo/./bar//', 'foo/bar')
end

-- luacheck: ignore test_path_prettify
function test_path_prettify ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_prettify, '')

    local tests = {}
    local home = os.getenv('HOME')

    if M.PATH_SEP == '/' then
        tests[home] = home
        tests[home .. 'foo'] = home .. 'foo'
        tests[M.path_join(home, 'foo')] = '~/foo'
    end

    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        local cwd = pandoc.system.get_working_directory()
        local rwd
        if M.PATH_SEP == '/'
            then rwd = cwd:gsub('^' .. home .. M.PATH_SEP, '~' .. M.PATH_SEP)
            else rwd = cwd
        end
        tests[cwd] = rwd
        tests[cwd .. 'foo'] = rwd .. 'foo'
        tests[M.path_join(cwd, 'foo')] = 'foo'
    end

    for input, output in pairs(tests) do
        assert_equals(M.path_prettify(input), output)
    end

    assert_equals(M.path_prettify(M.env_sub '${HOME}/foo/./bar//'), '~/foo/bar')
end

-- luacheck: ignore test_path_split
function test_path_split ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_split, '')

    for input, output in pairs{
        ['.']                   = {'.',         '.' },
        ['..']                  = {'.',         '..'},
        ['/']                   = {'/',         '.' },
        ['//']                  = {'/',         '.' },
        ['/////////']           = {'/',         '.' },
        ['/.//////']            = {'/',         '.' },
        ['/.////.//']           = {'/',         '.' },
        ['/.//..//.//']         = {'/..',       '.' },
        ['/.//..//.//../']      = {'/../..',    '.' },
        ['a']                   = {'.',         'a' },
        ['./a']                 = {'.',         'a' },
        ['../a']                = {'..',        'a' },
        ['/a']                  = {'/',         'a' },
        ['//a']                 = {'/',         'a' },
        ['//////////a']         = {'/',         'a' },
        ['/.//////a']           = {'/',         'a' },
        ['/.////.//a']          = {'/',         'a' },
        ['/.//..//.//a']        = {'/..',       'a' },
        ['/.//..//.//../a']     = {'/../..',    'a' },
        ['a/b']                 = {'a',         'b' },
        ['./a/b']               = {'a',         'b' },
        ['../a/b']              = {'../a',      'b' },
        ['/a/b']                = {'/a',        'b' },
        ['//a/b']               = {'/a',        'b' },
        ['///////a/b']          = {'/a',        'b' },
        ['/.//////a/b']         = {'/a',        'b' },
        ['/.////.//a/b']        = {'/a',        'b' },
        ['/.//..//.//a/b']      = {'/../a',     'b' },
        ['/.//..//.//../a/b']   = {'/../../a',  'b' },
        ['/a/b/c/d']            = {'/a/b/c',    'd' },
        ['a/b/c/d']             = {'a/b/c',     'd' },
        ['a/../.././c/d']       = {'a/../../c', 'd' }
    } do
        local dir, fname = M.path_split(input)
        assert_equals(dir, output[1])
        assert_equals(fname, output[2])
    end

    assert_equals(
        pack(M.path_split('foo' .. M.PATH_SEP .. 'bar')),
        {'foo', 'bar', n = 2}
    )
end

-- luacheck: ignore test_project_dir
function test_project_dir ()
    assert_equals(M.project_dir(), '/dev')
end


-- Elements.

-- luacheck: ignore test_elem_clone
function test_elem_clone ()
    assert_error_msg_matches(
        '.-%f[%a]expected a Pandoc document%.',
        M.elem_clone, {}
    )

    local str = Str 'foo'
    local inlines = List{str}
    local block = Para(inlines)
    local doc = Pandoc(List{block})

    for _, elem in ipairs{str, inlines, block, doc} do
        assert_true(pandoc.utils.equals(M.elem_clone(elem), elem))
    end
end

-- luacheck: ignore test_elem_type
function test_elem_type ()
    for _, val in ipairs{true, 1, 'string', {}, function () end} do
        local ok, err = M.elem_type(val)
        assert_nil(ok)
        assert_str_matches(err, '.-%f[%a]not a Pandoc AST element.')
    end

    local tests = {
        [Str 'test'] = {'Str', 'Inline', 'AstElement', n = 3},
        [Para{Str ''}] = {'Para', 'Block', 'AstElement', n = 3},
        [read_md_file(M.path_join(DATA_DIR, 'foo.md'))] = {'Pandoc', n = 1},
        [List{Str ''}] = {'Inlines', n = 1},
        [{Para{Str ''}}] = {'Blocks', n = 1},
        [List{Para{Str ''}, Header(1, {Str 'x'})}] = {'Blocks', n = 1}
    }

    if pandoc.types and PANDOC_VERSION >= {2, 17} then -- ?
        tests[pandoc.MetaInlines{Str ''}] = {'Inlines', n = 1}
    else
        tests[pandoc.MetaInlines{Str ''}] =
            {'MetaInlines', 'Meta', 'AstElement', n = 3}
    end

    for input, output in pairs(tests) do
        assert_items_equals(pack(M.elem_type(input)), output)
    end
end

-- luacheck: ignore test_elem_walk
function test_elem_walk ()
    local md = [[
# Foo

This is a paragraph.

1. One word (not really)
2. Two words (true this time, oh wait)
3. Three words (not even going to try)

# Bar

Quoting a list:

> (a) A B C
> (b) One two three
> (c) Err, alpha, beta, gamma?

# Baz

| * Star
| * *Star*
| * **Star**
]]
    local doc = pandoc.read(md)
    -- It is hard to deep-copy a Pandoc AST in a way
    -- that works in *all* versions of Pandoc.
    local cp = pandoc.read(md)

    -- Test erroneous arguments.
    assert_error_msg_matches(
        '.-%f[%a]the AST can only be traversed "bottomup" or "topdown".',
        M.elem_walk, doc, {
            AstElement = id,
            traverse = true
        }
    )

    -- Test whether elements are of the requested type.
    for _, et in ipairs{
        'Str',
        'Inline',
        'Para',
        'Header',
        'BulletList',
        'OrderedList',
        'Block',
        'Blocks',
        'Meta',
        'MetaInline',
        'MetaValue',
        'Pandoc'
    } do
        M.elem_walk(doc, {[et] = function (el)
            local ets = {M.elem_type(el)}
            for i = 1, #ets do
                if ets[i] == et then return end
            end
            error(string.format('expected %s, got %s.', et, concat(ets, ', ')))
        end})
    end

    -- Test identity transformations.
    for _, et in ipairs {
        'Str',
        'Inline',
        'Para',
        'Header',
        'BulletList',
        'OrderedList',
        'Block',
        'Blocks',
        'Meta',
        'MetaInline',
        'MetaValue',
        'Pandoc'
    } do
        for _, f in ipairs{id, nilify} do
            assert_items_equals(M.elem_walk(doc, {[et] = f}), cp)
        end
    end

    -- Actual transformations.
    for _, et in ipairs{
        'Str',
        'Inline',
        'Block',
        'Blocks',
        'Pandoc'
    } do
        -- luacheck: ignore doc
        local doc = pandoc.read(md)
        local walked = M.elem_walk(M.elem_clone(doc), {[et] = function (el)
            local t, st = M.elem_type(el)
            if     t:match 's$'   then return pandoc.List:new()
            elseif st == 'Inline' then return Str ''
            elseif st == 'Block'  then return Null()
            end
            return Pandoc({})
        end})
        assert_str_matches(stringify(walked), '^%s*$')
    end

    local function barify_inline (str)
        return Str(str.text:gsub('foo', 'bar'))
    end
    local function barify_block (blk)
        return Para(List{Str(stringify(blk):gsub('foo', 'bar'))})
    end

    for _, filter in ipairs {
        {Str = barify_inline},
        {Inline = barify_inline},
        {Inlines = function (inlines)
            return List.map(inlines, barify_inline)
        end},
        {Para = barify_block},
        {Block = barify_block},
        {Blocks = function (blocks)
            return List.map(blocks, barify_block)
        end}
    } do
        -- luacheck: ignore doc
        local doc = pandoc.read 'foo'
        assert_equals(stringify(M.elem_walk(doc, filter)), 'bar')
    end

    doc = pandoc.read '> Foo'
    assert_equals(M.elem_walk(doc, {
        BlockQuote = function (b) return Para{Strong(stringify(b))} end,
        Str = function (s) return Str(s.text:gsub('Foo', 'Bar')) end
    }), pandoc.read '**Bar**')

    doc = pandoc.read '> # Foo'
    local match = false
    M.elem_walk(doc, {
        BlockQuote = function () return Para{Str 'No header here.'} end,
        Header = function () match = true end
    })
    assert_false(match)

    doc = pandoc.read '> # Foo'
    match = false
    M.elem_walk(doc, {
        BlockQuote = function () return Para{Str 'No header here.'} end,
        Header = function () match = true end,
        traverse = 'bottomup'
    })
    assert_true(match)

    doc = pandoc.read [[
---
foo: foo
...
]]
    local function barify_metas (metas)
        return List.map(metas, barify_inline)
    end
    local barified = M.elem_walk(doc, {
        MetaInlines = barify_metas,
        Inlines = barify_metas
    })
    assert_equals(stringify(barified.meta.foo), 'bar')
end


-- Options.

-- luacheck: ignore test_options_add
function test_options_add ()
    local opts = M.Options()

    for pattern, input in pairs {
        ['foo@bar!: cannot parse option type.'] =
            {name = 'err_type_syntax', type = 'foo@bar!'},
        ['int: no such option type.'] =
            {name = 'err_type_syntax', type = 'int'},
    } do
        assert_error_msg_matches(pattern, opts.add, opts, input)
    end

    opts:add{name = 'test'}
    assert_equals(opts[1].name, 'test')

    opts = M.Options()
    opts:add{
        name = 'bar',
        type = 'number',
        parse = function (x)
            if x < 1 then return nil, 'not a positive number.' end
            return x
        end
    }
end

do
    local meta = MetaMap{
        ['err-nab'] = 'foo',
        ['err-type-syntax'] = 'foo',
        ['err-type-semantics'] = 'foo',
        ['err-nan'] = MetaInlines{Str 'NaN'},
        ['err-list-nan-1'] = List:new{MetaInlines{Str 'NaN'}},
        ['err-list-nan-2'] = List:new{0, MetaInlines{Str 'NaN'}},
        ['err-list-nan-3'] = MetaInlines{Str 'NaN'},
        ['pre-err-nan'] = MetaInlines{Str 'NaN'},
        ['pre-err-list-nan-1'] = List:new{MetaInlines{Str 'NaN'}},
        ['pre-err-list-nan-2'] = List:new{0, MetaInlines{Str 'NaN'}},
        ['pre-err-list-nan-3'] = MetaInlines{Str 'NaN'},
        ['err-alt-1'] = true,
        ['err-alt-2'] = {'a'},
        ['err-alt-3'] = {{{1}}},
        ['bool-1'] = true,
        ['bool-2'] = false,
        ['bool-3'] = 'true',
        ['bool-4'] = 'false',
        ['bool-5'] = 'TRUE',
        ['bool-6'] = 'F',
        ['bool-7'] = 'T',
        ['bool-8'] = 'No',
        ['bool-9'] = 'yeS',
        ['bool-10'] = 'N',
        ['bool-11'] = 'Y',
        ['num'] = 3,
        ['add'] = '0',
        ['num-str-1'] = '3',
        ['pre-num-str-2'] = '3',
        ['list-bool-1'] = List:new{false, true, 'f', 'yEs'},
        ['list-bool-2'] = List:new{},
        ['list-num-1'] = List:new{MetaInlines{Str '1'}, MetaInlines{Str '2'}},
        ['list-num-2'] = MetaInlines{Str '1'},
        ['list-num-3'] = List:new{},
        ['str'] =  MetaInlines{Str '1'},
        ['list-str-1'] =  List:new{MetaInlines{Str '1'}, MetaInlines{Str '2'}},
        ['list-str-2'] =  MetaInlines{Str '1'},
        ['list-list-1'] = List:new{List:new{MetaInlines{Str '1'}}},
        ['list-list-2'] = List:new{MetaInlines{Str '1'}},
        ['list-list-3'] = MetaInlines{Str '1'},
        ['alt-1'] = 'foo',
        ['alt-2'] = 1,
        ['alt-3'] = {1},
        ['alt-4'] = {{1}},
    }

    local function make_options_parse_test (func)
        return function ()
            for pattern, input in pairs {
                ['foo@bar!: cannot parse option type.'] =
                    {name = 'err_type_syntax', type = 'foo@bar!'},
                ['int: no such option type.'] =
                    {name = 'err_type_syntax', type = 'int'},
            } do
                assert_error_msg_matches(pattern, func, {input}, meta)
            end

            for msg, input in pairs {
                ['err-nab: not a boolean value.'] =
                    {name = 'err_nab', type = 'boolean'},
                ['err-nan: not a number.'] =
                    {name = 'err_nan', type = 'number'},
                ['err-list-nan-1: item no. 1: not a number.'] =
                    {name = 'err_list_nan-1', type = 'array<number>'},
                ['err-list-nan-2: item no. 2: not a number.'] =
                    {name = 'err_list_nan-2', type = 'array<number>'},
                ['err-list-nan-3: not a number.'] =
                    {name = 'err-list-nan-3', type = 'number'},
                ['pre-err-nan: not a number.'] =
                    {prefix = 'pre', name = 'err_nan', type = 'number'},
                ['pre-err-list-nan-3: not a number.'] =
                    {prefix = 'pre', name = 'err-list-nan-3', type = 'number'},
                ['num: foo'] = {
                    name = 'num', type = 'number', parse = function ()
                        return nil, 'foo'
                    end
                },
                ['err-alt-1: expected array of arrays of numbers or string.'] =
                    {name = 'err_alt_1', type = 'array<array<number>>|string'},
                ['err-alt-2: expected array of arrays of numbers or string.'] =
                    {name = 'err_alt_2', type = 'array<array<number>>|string'},
                ['err-alt-3: expected array of arrays of numbers or string.'] =
                    {name = 'err_alt_3', type = 'array<array<number>>|string'}
            } do
                local ok, err = func({input}, meta)
                assert_nil(ok)
                assert_equals(err, msg)
            end

            local opts = M.Options(
                {name = 'num', type = 'number'},
                {name = 'bool-1', type = 'boolean'},
                {name = 'bool-2', type = 'boolean'},
                {name = 'bool-3', type = 'boolean'},
                {name = 'bool-4', type = 'boolean'},
                {name = 'bool-5', type = 'boolean'},
                {name = 'bool-6', type = 'boolean'},
                {name = 'bool-7', type = 'boolean'},
                {name = 'bool-8', type = 'boolean'},
                {name = 'bool-9', type = 'boolean'},
                {name = 'bool-10', type = 'boolean'},
                {name = 'bool-11', type = 'boolean'},
                {name = 'num_str_1', type = 'number'},
                {prefix = 'pre', name = 'num_str_2', type = 'number'},
                {name = 'list_bool_1', type = 'array<boolean>'},
                {name = 'list_bool_2', type = 'array<boolean>'},
                {name = 'list_num_1', type = 'array<number>'},
                {name = 'list_num_2', type = 'array<number>'},
                {name = 'list_num_3', type = 'array<number>'},
                {name = 'str'},
                {name = 'list_str_1', type = 'array<string>'},
                {name = 'list_str_2', type = 'array'},
                {name = 'list_list_1', type = 'array<array<number>>'},
                {name = 'list_list_2', type = 'array<array<number>>'},
                {name = 'list_list_3', type = 'array<array<number>>'},
                {name = 'add', type = 'number', parse = function (n)
                    return n + 1
                end},
                {name = 'alt-1', type = 'array<array<number>>|array<number>|string'},
                {name = 'alt-2', type = 'array<array<number>>|array<number>|string'},
                {name = 'alt-3', type = 'array<array<number>>|array<number>|string'},
                {name = 'alt-4', type = 'array<array<number>>|array<number>|string'}
            )

            assert_items_equals(func(opts, meta), {
                num = 3,
                bool_1 = true,
                bool_2 = false,
                bool_3 = true,
                bool_4 = false,
                bool_5 = true,
                bool_6 = false,
                bool_7 = true,
                bool_8 = false,
                bool_9 = true,
                bool_10 = false,
                bool_11 = true,
                num_str_1 = 3,
                num_str_2 = 3,
                list_bool_1 = {false, true, false, true},
                list_bool_2 = {},
                list_num_1 = {1, 2},
                list_num_2 = {1},
                list_num_3 = {},
                str = '1',
                list_str_1 = {'1', '2'},
                list_str_2 = {'1'},
                list_list_1 = {{1}},
                list_list_2 = {{1}},
                list_list_3 = {{1}},
                add = 1,
                alt_1 = 'foo',
                alt_2 = {{1}},
                alt_3 = {{1}},
                alt_4 = {{1}},
            })
        end
    end

    -- luacheck: ignore test_options_parse
    test_options_parse = make_options_parse_test(M.Options.parse)

    -- luacheck: ignore test_opts_parse
    test_opts_parse = make_options_parse_test(
        -- luacheck: ignore meta
        function (opts, meta)
            return M.opts_parse(meta, unpack(opts))
        end
    )
end


--- Boilerplate
-- @section

--- Runs the tests
--
-- Looks up the `tests` metadata field in the current Pandoc document
-- and passes it to `lu.LuaUnit.run`, as is. Also configures tests.
--
-- @tparam pandoc.Pandoc A Pandoc document.
function run (doc)
    local test
    if doc.meta and doc.meta.test then
        test = stringify(doc.meta.test)
        if test == '' then test = nil end
    end
    os.exit(lu.LuaUnit.run(test), true)
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}
