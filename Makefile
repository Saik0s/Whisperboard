
TUIST=PATH="${PWD}/.tuist-bin:${PATH}" tuist

all: project_file

project_file: secrets
	$(TUIST) fetch
	$(TUIST) generate --no-open

update: secrets
	$(TUIST) fetch --update
	$(TUIST) generate --no-open

hot: secrets
	TUIST_IS_HOT_RELOADING_ENABLED=1 $(TUIST) fetch
	TUIST_IS_HOT_RELOADING_ENABLED=1 $(TUIST) generate --no-open

appstore: secrets
	TUIST_IS_APP_STORE=1 $(TUIST) fetch
	TUIST_IS_APP_STORE=1 $(TUIST) generate --no-open

hot_appstore: secrets
	TUIST_IS_APP_STORE=1 TUIST_IS_HOT_RELOADING_ENABLED=1 $(TUIST) fetch
	TUIST_IS_APP_STORE=1 TUIST_IS_HOT_RELOADING_ENABLED=1 $(TUIST) generate --no-open

build_debug:
	$(TUIST) build --generate --configuration Debug --build-output-path .build/

build_release:
	$(TUIST) build --generate --configuration Release --build-output-path .build/

format:
	swiftformat . --config .swiftformat

secrets:
	sh ./ci_scripts/secrets.sh

analyze:
	sh ./ci_scripts/cpd_run.sh && echo "CPD done"
	periphery scan > periphery.log && echo "Periphery done"
	xcodebuild -workspace WhisperBoard.xcworkspace -scheme WhisperBoard -configuration Debug build CODE_SIGNING_ALLOWED="NO" ENABLE_BITCODE="NO" > xcodebuild.log && echo "Xcodebuild done"
	swiftlint analyze --compiler-log-path xcodebuild.log > swiftlint_analyze.log && echo "Swiftlint done"

clear_analyze:
	rm periphery.log
	rm xcodebuild.log
	rm swiftlint_analyze.log
	rm cpd-output.xml
	
clean: clear_analyze
	rm -rf build
	$(TUIST) clean

.SILENT: all project_file update hot appstore hot_appstore build_debug build_release format secrets
