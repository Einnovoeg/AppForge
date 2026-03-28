# AppForge

AppForge is a native macOS SwiftUI application for generating starter Apple-platform apps from a prompt. The current open-source release focuses on a polished macOS shell, pluggable AI planning backends, supported multi-provider routing, and a reliable local build loop for generated macOS projects.

Current release: `v0.2.0`

- Release notes: [v0.2.0](https://github.com/Einnovoeg/AppForge/releases/tag/v0.2.0)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

The app currently supports:

- Native macOS SwiftUI interface for creating and refining generated projects
- Cloud model routing for OpenAI and Anthropic
- Local model routing for Ollama and LM Studio
- `Single` and `Ensemble` routing modes for using one provider or several providers concurrently
- Portable project generation under `~/AppForge`
- Local `xcodegen` + `xcodebuild` build pipeline
- Built-in Sudoku recipe that generates a playable macOS Sudoku app

The app does not yet ship a full autonomous multi-file coding loop for arbitrary product requests. For most prompts, it still generates a runnable project shell. Sudoku is the first built-in end-to-end recipe.

## Screens and Workflow

1. Launch AppForge on macOS.
2. Choose `Single` or `Ensemble` routing in Settings and configure the providers you want active.
3. Describe the app you want to build.
4. AppForge scaffolds a project into `~/AppForge/Projects`.
5. AppForge builds the generated app locally and lets you inspect files, logs, and follow-up refinements.

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

### GitHub Release

The `v0.2.0` release is published on GitHub with versioned notes and source archives:

- [AppForge Releases](https://github.com/Einnovoeg/AppForge/releases)

The packaged `v0.2.0` app assets are local-release builds and are not notarized yet. For the most predictable install path today, build from source on an Apple Silicon Mac with Xcode and XcodeGen available locally.

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

## Versioning

AppForge uses Semantic Versioning for tagged releases and keeps project history in [CHANGELOG.md](CHANGELOG.md). The app bundle version for `v0.2.0` is `0.2.0 (2)`.

## Using Providers

AppForge currently supports four planning backends:

- `OpenAI`
- `Anthropic`
- `Ollama`
- `LM Studio`

Cloud providers use API keys stored in the macOS Keychain. Local providers use HTTP requests to locally running model servers. AppForge can run these backends in `Single` mode or `Ensemble` mode. Ensemble mode uses supported configured providers in parallel and merges their compact blueprint outputs into one scaffold plan. It does not reuse browser sessions or scrape provider web traffic.

AppForge does not currently integrate Xcode coding intelligence.

## Data Handling

- Generated projects are written to `~/AppForge/Projects`
- Cached metadata and logs stay under `~/AppForge`
- Cloud API keys are stored in the macOS Keychain
- No third-party source code is vendored into this repository

## Verification

The current repository has been manually verified with:

- `xcodebuild -project AppForge.xcodeproj -scheme AppForge -showBuildSettings`
- `xcodegen generate`
- `xcodebuild -project AppForge.xcodeproj -scheme AppForge -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- `xcodebuild -project AppForge.xcodeproj -scheme AppForge -configuration Release -destination 'platform=macOS,arch=arm64' build`
- Launch of the built `AppForge.app`
- Launch verification of the `v0.2.0` debug build after the ensemble-routing refactor
- Fresh generation, build, and launch of a built-in Sudoku app

## License and Notices

This project is licensed under the [MIT License](LICENSE).

Third-party notices and attribution are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Support

If you want to support the project, the repository and app both include this link:

- [Buy Me a Coffee](https://buymeacoffee.com/einnovoeg)
