.PHONY: all init update build clean install install-clobber watch
.DEFAULT_TARGET: build

CONFIG_DIR = $(XDG_CONFIG_HOME)/alacritty

init:
	git submodule update --init --recursive --no-fetch

update: init
	git submodule update --recursive

build/themes:
	./scripts/gen-themes.sh

build/configs: build/themes
	./scripts/build.sh

build: init build/themes
	./scripts/build.sh

clean:
	rm -rf ./build

install: build/configs
	mkdir -p $(CONFIG_DIR)
	cp --no-clobber --interactive ./build/configs/*.yml $(CONFIG_DIR)

install-clobber: build/configs
	mkdir -p $(CONFIG_DIR)
	cp ./build/configs/*.yml $(CONFIG_DIR)

watch: init
	./scripts/watch.sh

watch-install: init
	./scripts/watch.sh make install-clobber
