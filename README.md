# AppForge

AppForge is a native macOS SwiftUI application for generating starter Apple-platform apps from a prompt. It provides a polished macOS workspace, pluggable AI planning backends, multi-provider routing, and a reliable local build loop for generated macOS projects.

Current release: `v1.0.0`

- Changelog: [CHANGELOG.md](CHANGELOG.md)
- License: [MIT License](LICENSE)
- Third-Party Notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

## Features

- Native macOS SwiftUI interface for creating and refining generated projects.
- Cloud model routing for OpenAI and Anthropic.
- Local model routing for Ollama and LM Studio.
- `Single` and `Ensemble` routing modes for using one provider or several providers concurrently.
- Portable project generation under `~/AppForge`.
- Local `xcodegen` + `xcodebuild` build pipeline.
- Built-in Sudoku recipe that generates a fully playable macOS Sudoku app.

## Requirements

Required:
- Apple Silicon Mac
- macOS 15 or later
- Xcode with command line tools installed
- XcodeGen 2.38.0 or later available on `PATH`

Optional:
- OpenAI API key
- Anthropic API key
- Ollama running locally
- LM Studio local server running

The complete dependency list is in [DEPENDENCIES.md](DEPENDENCIES.md).

## Installation

### Run from Source

1. Install Xcode and open it once so the toolchain and license are configured.
2. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Build the app:
   ```bash
   xcodebuild -project AppForge.xcodeproj -scheme AppForge -configuration Debug -destination 'platform=macOS,arch=arm64' build
   ```
5. Launch the built app:
   ```bash
   open ~/Library/Developer/Xcode/DerivedData/AppForge-*/Build/Products/Debug/AppForge.app
   ```

## Known Limitations & Roadmap

AppForge is a powerful starter, but there are several areas still under development:

- **Arbitrary Logic Generation**: For most prompts, AppForge currently generates a runnable project shell. While built-in recipes like Sudoku produce full logic, a general-purpose multi-file coding loop is still in progress.
- **Platform Support**: Currently, only macOS SwiftUI apps are scaffolded. Support for iPhone, iPad, and watch targets is planned.
- **IDE Integration**: Xcode coding intelligence and session reuse are not yet integrated.
- **Notarization**: Distributed app bundles are not yet notarized. Building from source is the recommended path.

### Help Wanted! 🚀

AppForge is an open-source project and we would love your help! If you encounter any bugs, have ideas for new features, or want to contribute to the coding loop, please open an issue or submit a pull request. Your contributions make AppForge better for everyone.

## Using Providers

AppForge supports four planning backends: OpenAI, Anthropic, Ollama, and LM Studio.

Cloud providers use API keys stored securely in the macOS Keychain. Local providers use HTTP requests to locally running model servers. You can use `Single` mode to rely on one model, or `Ensemble` mode to query multiple providers in parallel and merge their outputs into one deterministic scaffold plan.

## Data Handling

- Generated projects are written to `~/AppForge/Projects`
- Cached metadata and logs stay under `~/AppForge`
- Cloud API keys are stored in the macOS Keychain
- No third-party source code is vendored into this repository

## Support

If you find AppForge useful, consider supporting the project:

- [Buy Me a Coffee](https://buymeacoffee.com/einnovoeg)
