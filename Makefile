
TUIST=PATH="${PWD}/.tuist-bin:${PATH}" tuist

all: secrets
	$(TUIST) fetch
	$(TUIST) generate --no-open --no-cache

update: secrets
	$(TUIST) fetch --update
	$(TUIST) generate --no-open --no-cache

hot:
	TUIST_IS_HOT_RELOADING_ENABLED=1  $(TUIST) fetch
	TUIST_IS_HOT_RELOADING_ENABLED=1  $(TUIST) generate --no-open --no-cache

build_debug:
	$(TUIST) build --generate --configuration Debug --build-output-path .build/

build_release:
	$(TUIST) build --generate --configuration Release --build-output-path .build/

format:
	swiftformat . --config .swiftformat

secrets:
	sh ./ci_scripts/secrets.sh

.SILENT: all update hot build_debug build_release format secrets
