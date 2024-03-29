--- print-vers - A fake Pandoc filter that prints Pandoc's version.
--
-- SYNOPSIS
-- --------
--
-- **pandoc** **-L** *print-vers.lua* /dev/null
--
-- DESCRIPTION
-- -----------
--
-- Used in the test suite to tailor tests to different versions of Pandoc.
--
-- AUTHOR
-- ------
--
-- Odin Kroeger
--
-- @script print-pandoc-vers
-- @author Odin Kroeger
-- luacheck: ignore
print(tostring(PANDOC_VERSION))
