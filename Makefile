
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

build_debug:
	$(TUIST) build --generate --configuration Debug --build-output-path .build/

build_release:
	$(TUIST) build --generate --configuration Release --build-output-path .build/

format:
	$(MISE) x swiftlint -- swiftlint lint --force-exclude --fix .
	$(MISE) x swiftformat -- swiftformat . --config .swiftformat

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
