.PHONY: all app extension test clean

all: app extension

# Build macOS .app bundle from Swift backend
app:
	cd backend-swift && swift build -c release
	@rm -rf Terminatab.app
	mkdir -p Terminatab.app/Contents/MacOS
	mkdir -p Terminatab.app/Contents/Resources
	cp backend-swift/.build/release/Terminatab Terminatab.app/Contents/MacOS/Terminatab
	cp backend/resources/Info.plist Terminatab.app/Contents/Info.plist
	cp backend/resources/AppIcon.icns Terminatab.app/Contents/Resources/AppIcon.icns
	@# Update executable name in Info.plist to match SPM product
	@sed -i '' 's|terminatab-server|Terminatab|' Terminatab.app/Contents/Info.plist

# Package Chrome extension into a .zip for Web Store upload
extension:
	@rm -f terminatab-extension.zip
	cd extension && zip -r ../terminatab-extension.zip . -x '*/.*' 'test.*'

# Run Swift tests
test:
	cd backend-swift && swift test

clean:
	cd backend-swift && swift package clean
	rm -rf Terminatab.app terminatab-extension.zip
