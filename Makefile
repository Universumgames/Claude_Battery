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

ICTOOL := /Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool
ICON_SRC := Sources/ClaudeBattery/AppIcon.icon
ICONSET := $(BUILD_DIR)/FolderIcon.iconset

.PHONY: all app build install run xcodeproj clean uninstall foldericon dist

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
