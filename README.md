<div align="center">
  <a href="https://github.com/Saik0s/Whisperboard">
    <img src="App/Resources/Assets.xcassets/AppIcon.appiconset/ios-marketing.png" width="80">
  </a>

  <h3 align="center">Whisperboard</h3>

  <p align="center">
    An iOS app for recording and transcribing audio on the go, based on OpenAI's Whisper model.
  </p>
</div>
<hr />

<div align="center">
<img src=".github/screenshot1.png" width="200">
<img src=".github/screenshot2.png" width="200">
</div>
<hr />
<p align="center">
    <img src="https://img.shields.io/badge/Platforms-iOS-3876D3.svg" />
    <a href="https://twitter.com/sa1k0s">
        <img src="https://img.shields.io/badge/Contact-@sa1k0s-purple.svg?style=flat" alt="Twitter: @sa1k0s" />
    </a>
    <img src="https://img.shields.io/github/commit-activity/w/Saik0s/Whisperboard?style=flat" alt="Commit Activity">
    <img src="https://img.shields.io/github/license/Saik0s/Whisperboard?style=flat" alt="License">
    <img src="https://img.shields.io/badge/Powered%20by-Tuist-blue" alt="Powered by Tuist">
</p>

## Features

- Easy-to-use voice recording and playback
- Transcription of recorded audio using Whisper from OpenAI
- Import and export audio files
- Select microphone for recording
- Model selection screen with the ability to download any Whisper model

## Future Plans

- [ ] Optimize the transcription process by eliminating silent portions of audio, which can reduce the processing time and improve overall efficiency.
- [x] Implement resumable transcription so that users can continue transcribing after the app has been terminated during the transcription process.
- [ ] Provide an estimated time remaining for the transcription to complete, helping users plan accordingly.
- [ ] Implement real-time transcription using smaller, more efficient models, offering users faster results.

## Installation

1. Clone this repository
2. Run `make`
3. Open the project in Xcode

## License

This project is licensed under the GPL-3.0 license.

The Poppins and Karla fonts used in project are licensed under the SIL Open Font License.

## Links

<a href="https://www.buymeacoffee.com/saik0s" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-green.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [OpenAI Whisper](https://github.com/openai/whisper)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
