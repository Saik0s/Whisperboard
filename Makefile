all:
	tuist fetch
	tuist generate --no-open --no-cache

update:
	tuist fetch --update
	tuist generate --no-open --no-cache

build_debug:
	tuist build --generate --configuration Debug --build-output-path .build/

build_release:
	tuist build --generate --configuration Release --build-output-path .build/

format:
	swiftformat . --config .swiftformat