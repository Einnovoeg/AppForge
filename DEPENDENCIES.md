# Dependencies

This repository intentionally keeps runtime dependencies light. No third-party source packages are vendored into the repo at the time of publication.

## Required to build and run AppForge from source

- `macOS 15+`
  - AppForge targets modern macOS APIs and is configured for macOS 15.0 deployment.
- `Apple Silicon`
  - The app is currently verified on Apple Silicon.
- `Xcode`
  - Required for `xcodebuild`, Apple SDKs, and local macOS app builds.
- `Xcode Command Line Tools`
  - Needed for the toolchain and shell-based build helpers.
- `XcodeGen 2.38.0+`
  - Used to generate `AppForge.xcodeproj` from `project.yml`.

## Optional AI backends

- `OpenAI API key`
  - Needed only if you choose OpenAI in Settings.
- `Anthropic API key`
  - Needed only if you choose Anthropic in Settings.
- `Ollama`
  - Needed only if you choose Ollama as a local model backend.
- `LM Studio`
  - Needed only if you choose LM Studio as a local model backend.

## Apple frameworks used by the app

- `SwiftUI`
- `Foundation`
- `AppKit`
- `Security`

## Install notes

Example setup:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project AppForge.xcodeproj -scheme AppForge -configuration Debug -destination 'platform=macOS,arch=arm64' build
```
