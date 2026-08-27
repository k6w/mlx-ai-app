.PHONY: build test app dmg install clean

ifneq (,$(wildcard /Applications/Xcode-beta.app))
DEVELOPER_DIR ?= /Applications/Xcode-beta.app/Contents/Developer
endif
SWIFT_ENV = CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/module-cache" $(if $(DEVELOPER_DIR),DEVELOPER_DIR="$(DEVELOPER_DIR)",)

build:
	@mkdir -p .build/module-cache
	@$(SWIFT_ENV) xcrun swift build --disable-sandbox

test:
	@mkdir -p .build/module-cache
	@$(SWIFT_ENV) xcrun swift test --disable-sandbox

app:
	@./scripts/build-app.sh

dmg:
	@./scripts/package-dmg.sh

install:
	@./scripts/install.sh

clean:
	@xcrun swift package clean
