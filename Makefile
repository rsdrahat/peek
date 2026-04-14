APP_NAME      := peek
BUNDLE_ID     := dev.peek.app
CONFIG        := release
BUILD_DIR     := .build
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
BIN_PATH      := $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)

.PHONY: all build run app clean test test-update test-coverage fmt icon og zip

all: app

build:
	swift build -c $(CONFIG)

test:
	swift test

# Regenerate fixture .expected.html files when output changes intentionally.
test-update:
	PEEK_UPDATE_FIXTURES=1 swift test || true
	@echo "Fixtures regenerated. Re-run 'make test' to verify."

test-coverage:
	swift test --enable-code-coverage
	@xcrun llvm-cov report \
		$$(swift build --show-bin-path)/peekPackageTests.xctest/Contents/MacOS/peekPackageTests \
		-instr-profile=$$(swift build --show-bin-path)/codecov/default.profdata \
		-ignore-filename-regex='.build|Tests' || true

run: build
	$(BIN_PATH) $(FILE)

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BIN_PATH) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp scripts/peek-cli.sh $(APP_BUNDLE)/Contents/MacOS/peek-cli
	chmod +x $(APP_BUNDLE)/Contents/MacOS/peek-cli
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp assets/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	# SwiftPM places resources in a .bundle next to the binary; copy it in.
	if [ -d $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)_$(APP_NAME).bundle ]; then \
		cp -R $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)_$(APP_NAME).bundle $(APP_BUNDLE)/Contents/Resources/; \
	fi
	@echo "Built $(APP_BUNDLE)"

icon:
	swift scripts/generate-icon.swift

og:
	swift scripts/generate-og.swift

zip: app
	ditto -c -k --keepParent $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).zip
	shasum -a 256 $(BUILD_DIR)/$(APP_NAME).zip | tee $(BUILD_DIR)/$(APP_NAME).zip.sha256
	@echo "Built $(BUILD_DIR)/$(APP_NAME).zip (unsigned — CI signs + notarizes on tag push)"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)/$(APP_NAME).app $(BUILD_DIR)/$(APP_NAME).zip $(BUILD_DIR)/$(APP_NAME).zip.sha256

fmt:
	swift format --in-place --recursive Sources Tests
