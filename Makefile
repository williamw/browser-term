.PHONY: all app extension clean

all: app extension

# Build macOS .app bundle
app:
	cd backend && zig build app
	@rm -rf Terminatab.app
	cp -R backend/zig-out/Terminatab.app .

# Package Chrome extension into a .zip for Web Store upload
extension:
	@rm -f terminatab-extension.zip
	cd extension && zip -r ../terminatab-extension.zip . -x '*/.*' 'test.*'

clean:
	cd backend && rm -rf zig-out .zig-cache
	rm -rf Terminatab.app terminatab-extension.zip
