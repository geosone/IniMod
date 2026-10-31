FPC ?= fpc
LAZUTILS ?= $(firstword $(wildcard /usr/lib/lazarus/*/components/lazutils))
BUILD_DIR ?= build

.PHONY: all clean test
all:
	mkdir -p $(BUILD_DIR)/units
	$(FPC) -MObjFPC -Scghi -O2 -g- -dINI_NO_GRAPHICS -Fithird_party/JPLib -Futhird_party/JPLib/Base -Fu$(LAZUTILS) -FU$(BUILD_DIR)/units -FE$(BUILD_DIR) -oinimod src/IniMod.lpr

test: all
	python3 tests/test_cli.py $(BUILD_DIR)/inimod

clean:
	rm -rf $(BUILD_DIR)
