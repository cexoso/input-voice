APP_NAME = InputVoice
BUNDLE_ID = com.inputvoice.app
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run install clean sign

## Build a signed .app bundle (release mode)
build:
	@echo "==> Building $(APP_NAME)..."
	swift build -c release 2>&1
	@echo "==> Creating .app bundle..."
	@$(MAKE) _bundle

_bundle:
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(RELEASE_DIR)/InputVoice $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@# Sign the bundle (ad-hoc if no identity specified)
	@if [ -n "$(CODESIGN_IDENTITY)" ]; then \
		echo "==> Signing with identity: $(CODESIGN_IDENTITY)"; \
		codesign --force --deep --sign "$(CODESIGN_IDENTITY)" \
			--entitlements Resources/InputVoice.entitlements \
			--options runtime \
			$(APP_BUNDLE); \
	else \
		echo "==> Ad-hoc signing (set CODESIGN_IDENTITY for distribution)"; \
		codesign --force --deep --sign - \
			--entitlements Resources/InputVoice.entitlements \
			$(APP_BUNDLE); \
	fi
	@echo "==> Built: $(APP_BUNDLE)"

## Run in debug mode (no .app bundle, just the executable)
run:
	@echo "==> Building and running $(APP_NAME)..."
	swift run

## Install .app bundle to /Applications
install: build
	@echo "==> Installing to $(INSTALL_DIR)/$(APP_BUNDLE)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@cp -R $(APP_BUNDLE) "$(INSTALL_DIR)/"
	@echo "==> Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "==> You may need to grant Accessibility permissions in System Settings."

## Package .app into a zip for GitHub Releases
release: build
	@echo "==> Packaging $(APP_BUNDLE) into zip..."
	@rm -f $(APP_NAME).zip
	@ditto -c -k --sequesterRsrc --keepParent $(APP_BUNDLE) $(APP_NAME).zip
	@echo "==> SHA256:"
	@shasum -a 256 $(APP_NAME).zip
	@echo "==> Done: $(APP_NAME).zip"

## Clean build artifacts
clean:
	@echo "==> Cleaning..."
	@swift package clean
	@rm -rf $(APP_BUNDLE)
	@rm -rf $(BUILD_DIR)
	@rm -f $(APP_NAME).zip
	@echo "==> Clean done."
