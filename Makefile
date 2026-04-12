APP_NAME      := rview
BUNDLE_ID     := dev.rview.app
CONFIG        := release
BUILD_DIR     := .build
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
BIN_PATH      := $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)

.PHONY: all build run app clean test fmt

all: app

build:
	swift build -c $(CONFIG)

test:
	swift test

run: build
	$(BIN_PATH) $(FILE)

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BIN_PATH) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	# SwiftPM places resources in a .bundle next to the binary; copy it in.
	if [ -d $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)_$(APP_NAME).bundle ]; then \
		cp -R $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)_$(APP_NAME).bundle $(APP_BUNDLE)/Contents/Resources/; \
	fi
	@echo "Built $(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)/$(APP_NAME).app

fmt:
	swift format --in-place --recursive Sources Tests
