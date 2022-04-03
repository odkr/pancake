# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
SCPT_DIR	:= $(BASE_DIR)/scripts
TEMP_DIR	:= $(BASE_DIR)/tmp


# PROGRAMMES
# ==========

MKDIR		?= mkdir
PANDOC		?= pandoc
RM		?= rm
SHELL		?= sh


# PANDOC
# ======

PANDOC_ARGS	?= --quiet


# SCRIPT
# ======

SCRIPT		?= pancake.lua


# TESTS
# =====

all: lint test

tempdir:
	@$(RM) -rf $(TEMP_DIR)
	@$(MKDIR) -p $(TEMP_DIR)

test: tempdir
	@[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	@"$(PANDOC)" $(PANDOC_ARGS) --from markdown --to plain \
	             --lua-filter="$(SCPT_DIR)/unit-tests.lua" \
		     --metadata test="$(TEST)" /dev/null
lint:
	@luacheck --quiet $(SCRIPT) || [ $$? -eq 127 ]

docs: docs/index.html

docs/index.html: $(SCRIPT)
	ldoc -c docs/config.ld $(SCRIPT)

.PHONY: all docs lint test tempdir
