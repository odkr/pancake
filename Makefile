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
UNIT_TESTS	?= $(SCPT_DIR)/unit-tests.lua 


# TESTS
# =====

all: lint test

tempdir:
	@$(RM) -rf $(TEMP_DIR)
	@$(MKDIR) -p $(TEMP_DIR)

test: tempdir
	@[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	@"$(PANDOC)" $(PANDOC_ARGS) --from markdown --to plain \
	             --lua-filter=$(UNIT_TESTS) \
	             --metadata=test:"$(TEST)" /dev/null
lint:
	@luacheck --quiet $(UNIT_TESTS) $(SCRIPT) || [ $$? -eq 127 ]

docs: doc/index.html

doc/index.html: $(SCRIPT) README.md doc/config.ld
	ldoc -c doc/config.ld $(SCRIPT)

.PHONY: all docs lint test tempdir
