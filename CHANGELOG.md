# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-13

Initial public release.

### Added

- Native macOS SwiftUI shell for prompting, inspecting, building, and launching generated projects.
- Provider routing for OpenAI, Anthropic, Ollama, and LM Studio with explicit in-app configuration.
- Keychain-backed storage for cloud API keys and portable workspace generation under `~/AppForge`.
- Built-in Sudoku recipe that generates a playable macOS Sudoku application.
- Palette switching, local tooling diagnostics, dependency documentation, third-party notices, and repository hygiene files.

### Changed

- Reworked the shell into a cleaner three-column layout with clearer status surfaces and settings flows.
- Made provider state, local tooling state, and release metadata visible in the UI.
- Documented installation, dependency, support, and license details for public distribution.

### Fixed

- Removed the old heuristic-only fallback path from the main product direction in favor of explicit provider configuration.
- Fixed the settings sheet so users can reliably dismiss and save configuration changes.
- Corrected the built-in Sudoku generator so a fresh Sudoku app builds and launches successfully.
- Hardened build and provider error reporting so missing local tools and HTTP failures surface actionable messages.
