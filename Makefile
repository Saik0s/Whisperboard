all:
	bash ./whispercpp/models/download-ggml-model.sh tiny.en
	cp ./whispercpp/models/ggml-tiny.en.bin Whisperboard/Resources/ggml-tiny.en.bin
