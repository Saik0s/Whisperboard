TUIST=PATH="${PWD}/.tuist-bin:${PATH}" tuist

all:
	$(TUIST) fetch
	$(TUIST) generate --no-open --no-cache

update:
	$(TUIST) fetch --update
	$(TUIST) generate --no-open --no-cache

build_debug:
	$(TUIST) build --generate --configuration Debug --build-output-path .build/

build_release:
	$(TUIST) build --generate --configuration Release --build-output-path .build/

format:
	swiftformat . --config .swiftformat

.SILENT: all update build_debug build_release
