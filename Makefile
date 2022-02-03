.PHONY: init update build clean install install-clobber watch
.DEFAULT_TARGET: build

INSTALL_DIR = $(XDG_CONFIG_HOME)/alacritty

src/themes/base16-alacritty:
	git submodule update --init --recursive --no-fetch src/themes/base16-alacritty

init: src/themes/base16-alacritty

update: init
	git submodule update --recursive

build: init
	./scripts/build.sh

clean:
	rm -rf ./build

install: build
	mkdir -p $(INSTALL_DIR)
	cp --no-clobber --interactive ./build/*.yml $(INSTALL_DIR)

install-clobber: build
	mkdir -p $(INSTALL_DIR)
	cp ./build/*.yml $(INSTALL_DIR)

watch: build
	./scripts/watch.sh
