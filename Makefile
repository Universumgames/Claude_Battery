APP_NAME := ClaudeBattery
BUILD_DIR := .build
APP_PATH := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME).app

PROJECT := ClaudeBattery.xcodeproj
SCHEME := ClaudeBattery
CONFIGURATION := Release
DERIVED_DATA := $(BUILD_DIR)/DerivedData
ARCHIVE_PATH := $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH := $(BUILD_DIR)/Export
EXPORT_OPTIONS := ExportOptions.plist
DIST_ZIP := $(BUILD_DIR)/$(APP_NAME).app.zip
DMG_PATH := $(BUILD_DIR)/$(APP_NAME).dmg
DMG_STAGING := $(BUILD_DIR)/dmg-staging

ICTOOL := /Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool
ICON_SRC := Sources/ClaudeBattery/AppIcon.icon
ICONSET := $(BUILD_DIR)/FolderIcon.iconset

# Notarizing requires uploading to Apple via Xcode Organizer (xcodebuild's own
# archive/export can't do this), so releases are cut from an archive Xcode
# produced and you dragged into Versions/<version>/ after notarization
# succeeded there — not from `make app`'s local, unnotarized build.
VERSIONS_DIR := Versions
LATEST_ARCHIVE := $(shell find "$(VERSIONS_DIR)" -mindepth 2 -maxdepth 2 -iname '*.xcarchive' -type d -exec stat -f '%m %N' {} \; 2>/dev/null | sort -rn | head -n1 | sed 's/^[0-9]* //')
RELEASE_VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$(LATEST_ARCHIVE)/Info.plist" 2>/dev/null)
GH_REMOTE := github
GH_REPO := Universumgames/Claude_Battery

.PHONY: all app build install run xcodeproj clean uninstall foldericon dist dmg release

all: install

# Archive the app (via xcodebuild archive), then sign and export it out of the
# archive (via xcodebuild -exportArchive), same as Xcode's Organizer would.
# Regenerates the Xcode project first so newly added source files are always picked up.
app: xcodeproj
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIGURATION)" \
	  -derivedDataPath "$(DERIVED_DATA)" \
	  -archivePath "$(ARCHIVE_PATH)" \
	  -allowProvisioningUpdates \
	  archive
	rm -rf "$(EXPORT_PATH)"
	xcodebuild -exportArchive \
	  -archivePath "$(ARCHIVE_PATH)" \
	  -exportPath "$(EXPORT_PATH)" \
	  -exportOptionsPlist "$(EXPORT_OPTIONS)" \
	  -allowProvisioningUpdates
	mkdir -p "$(BUILD_DIR)"
	rm -rf "$(APP_PATH)"
	cp -R "$(EXPORT_PATH)/$(APP_NAME).app" "$(APP_PATH)"
	@echo "Built: $(APP_PATH)"
	@echo "Run:   open \"$(APP_PATH)\""

build: app

# Zip the exported app for distribution (e.g. attaching to a GitHub release),
# same as the manual `ditto` step in the Homebrew release process.
dist: app
	rm -f "$(DIST_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_PATH)" "$(DIST_ZIP)"
	@echo "Exported: $(DIST_ZIP)"
	@shasum -a 256 "$(DIST_ZIP)"

# Package the latest notarized archive under Versions/<version>/*.xcarchive into
# a drag-to-Applications .dmg for distribution (e.g. the Homebrew cask). Prefers
# the stapled copy Xcode Organizer leaves under Submissions/ once notarization
# succeeds; falls back to the plain archive product (with a warning) if none is
# stapled yet.
dmg:
	@if [ -z "$(LATEST_ARCHIVE)" ]; then \
	  echo "error: no .xcarchive found under $(VERSIONS_DIR)/<version>/ — archive and notarize in Xcode Organizer, then drag it into $(VERSIONS_DIR)/<version>/" >&2; \
	  exit 1; \
	fi
	@echo "Using archive: $(LATEST_ARCHIVE)"
	@notarized_app=$$(find "$(LATEST_ARCHIVE)/Submissions" -mindepth 2 -maxdepth 2 -iname "$(APP_NAME).app" -type d 2>/dev/null | head -n1); \
	if [ -n "$$notarized_app" ] && xcrun stapler validate "$$notarized_app" >/dev/null 2>&1; then \
	  src_app="$$notarized_app"; \
	  echo "Using notarized, stapled app: $$src_app"; \
	else \
	  src_app="$(LATEST_ARCHIVE)/Products/Applications/$(APP_NAME).app"; \
	  echo "warning: no stapled notarization ticket found; using unnotarized archive product: $$src_app" >&2; \
	fi; \
	rm -f "$(DMG_PATH)"; \
	rm -rf "$(DMG_STAGING)"; \
	mkdir -p "$(DMG_STAGING)"; \
	cp -R "$$src_app" "$(DMG_STAGING)/"; \
	ln -s /Applications "$(DMG_STAGING)/Applications"; \
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"; \
	rm -rf "$(DMG_STAGING)"; \
	echo "Exported: $(DMG_PATH)"; \
	shasum -a 256 "$(DMG_PATH)"

# Tag, push, and cut a GitHub release from the .dmg built above, using the
# version embedded in the notarized archive (Versions/<version>/ is just where
# you dropped it — this is what actually shipped). Override release notes with
# `make release NOTES="..."`.
release: dmg
	@if [ -z "$(RELEASE_VERSION)" ]; then \
	  echo "error: couldn't read CFBundleShortVersionString from $(LATEST_ARCHIVE)/Info.plist" >&2; \
	  exit 1; \
	fi
	@git diff --quiet && git diff --cached --quiet || { echo "error: uncommitted changes in tracked files — commit first" >&2; exit 1; }
	@tag="v$(RELEASE_VERSION)"; \
	echo "Releasing $$tag from $(DMG_PATH)"; \
	git tag -a "$$tag" -m "$(APP_NAME) $$tag" && \
	git push $(GH_REMOTE) "$$tag" && \
	gh release create "$$tag" "$(DMG_PATH)" -R $(GH_REPO) --title "$$tag" --notes "$${NOTES:-$(APP_NAME) $$tag}"

# Build and copy into /Applications, restarting the app if it's running.
install: app
	@pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	rm -rf "$(INSTALLED_APP)"
	cp -R "$(APP_PATH)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALLED_APP)"

run: install
	open "$(INSTALLED_APP)"

# Regenerate the Xcode project from project.yml (needed after adding/removing source files).
xcodeproj:
	xcodegen generate

# Render the app's Icon Composer document into a flat .icns/.png you can set as this
# project folder's custom Finder icon (Get Info -> paste onto the icon well).
foldericon:
	@test -x "$(ICTOOL)" || { echo "error: ictool not found at $(ICTOOL) (requires Xcode's Icon Composer)" >&2; exit 1; }
	mkdir -p "$(BUILD_DIR)"
	rm -rf "$(ICONSET)"
	mkdir -p "$(ICONSET)"
	"$(ICTOOL)" "$(ICON_SRC)" --export-image --output-file "$(BUILD_DIR)/FolderIcon.png" \
	  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1
	for size in 16 32 64 128 256 512 1024; do \
	  sips -z $$size $$size "$(BUILD_DIR)/FolderIcon.png" --out "$(ICONSET)/icon_$${size}x$${size}.png" >/dev/null; \
	done
	cp "$(ICONSET)/icon_32x32.png" "$(ICONSET)/icon_16x16@2x.png"
	cp "$(ICONSET)/icon_64x64.png" "$(ICONSET)/icon_32x32@2x.png"
	cp "$(ICONSET)/icon_256x256.png" "$(ICONSET)/icon_128x128@2x.png"
	cp "$(ICONSET)/icon_512x512.png" "$(ICONSET)/icon_256x256@2x.png"
	cp "$(ICONSET)/icon_1024x1024.png" "$(ICONSET)/icon_512x512@2x.png"
	rm -f "$(ICONSET)/icon_64x64.png" "$(ICONSET)/icon_1024x1024.png"
	iconutil -c icns "$(ICONSET)" -o "$(BUILD_DIR)/FolderIcon.icns"
	rm -rf "$(ICONSET)"
	@echo "Rendered: $(BUILD_DIR)/FolderIcon.icns"
	@echo "Rendered: $(BUILD_DIR)/FolderIcon.png"
	@echo "To use as this folder's icon: open FolderIcon.icns in Preview, Cmd+A Cmd+C," \
	     "then select this project folder in Finder, Cmd+I, click the icon in the top-left, Cmd+V."

clean:
	rm -rf $(BUILD_DIR)

uninstall:
	pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	rm -rf "$(INSTALLED_APP)"
