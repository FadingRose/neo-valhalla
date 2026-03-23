.PHONY: install uninstall clean

BINARY_NAME := auditscope
INSTALL_DIR := $(HOME)/.local/bin
SOURCE_PATH := $(PWD)/cli/$(BINARY_NAME)

install:
	@mkdir -p $(INSTALL_DIR)
	cd cli && GOPROXY=https://goproxy.cn,direct GOSUMDB=off go build -o $(BINARY_NAME) .
	ln -sf $(SOURCE_PATH) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "✓ Installed $(BINARY_NAME) to $(INSTALL_DIR)"

uninstall:
	rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	rm -f cli/$(BINARY_NAME)
	@echo "✓ Uninstalled $(BINARY_NAME)"

clean:
	rm -f cli/$(BINARY_NAME)