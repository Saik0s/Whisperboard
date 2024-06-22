
MISE=$(HOME)/.local/bin/mise
TUIST=$(MISE) x tuist -- tuist

all: bootstrap project_file

bootstrap:
	command -v $(MISE) >/dev/null 2>&1 || curl https://mise.jdx.dev/install.sh | sh
	$(MISE) install

project_file: secrets
	$(TUIST) install
	$(TUIST) generate --no-open

update: secrets
	$(TUIST) install --update
	$(TUIST) generate --no-open

appstore: secrets
	TUIST_IS_APP_STORE=1 $(TUIST) install
	TUIST_IS_APP_STORE=1 $(TUIST) generate --no-open

project_cache_warmup:
	$(TUIST) cache Common AudioProcessing WhisperBoardKit --external-only
	$(TUIST) generate -n

build_dev_debug:
	$(TUIST) build --configuration Debug --build-output-path .build/ WhisperBoardDev

build_dev_release:
	$(TUIST) build --configuration Release --build-output-path .build/ WhisperBoardDev

format:
	$(MISE) x swiftlint -- swiftlint lint --force-exclude --fix .
	$(MISE) x swiftformat -- swiftformat . --config .swiftformat

secrets:
	sh ./ci_scripts/secrets.sh

build_dev_server:
	xcode-build-server config -workspace WhisperBoard.xcworkspace -scheme WhisperBoardDev || echo "consult https://github.com/SolaWing/xcode-build-server for vscode support"

build_server:
	xcode-build-server config -workspace WhisperBoard.xcworkspace -scheme WhisperBoard || echo "consult https://github.com/SolaWing/xcode-build-server for vscode support"

analyze:
	sh ./ci_scripts/cpd_run.sh && echo "CPD done"
	periphery scan > periphery.log && echo "Periphery done"
	xcodebuild -workspace WhisperBoard.xcworkspace -scheme WhisperBoardDev -configuration Debug build CODE_SIGNING_ALLOWED="NO" ENABLE_BITCODE="NO" > xcodebuild.log && echo "Xcodebuild done"
	swiftlint analyze --compiler-log-path xcodebuild.log > swiftlint_analyze.log && echo "Swiftlint done"

clear_analyze:
	rm -f periphery.log
	rm -f xcodebuild.log
	rm -f swiftlint_analyze.log
	rm -f cpd-output.xml
	
clean: clear_analyze
	rm -rf build
	$(TUIST) clean

.SILENT: all project_file update hot appstore hot_appstore build_debug build_release format secrets
