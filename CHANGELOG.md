# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-28

Focused release for supported multi-provider orchestration and a cleaner configuration workflow.

### Added

- `Single` and `Ensemble` AI routing modes so AppForge can plan through one provider or several configured providers in parallel.
- Deterministic ensemble blueprint merging that keeps a lead provider for tie-breaking while unioning useful features from contributing models.
- Expanded settings UI for ensemble configuration, lead-provider selection, per-provider readiness, and per-provider local-model discovery.
- Hover tooltips across the main workspace controls and the new routing/settings surfaces.

### Changed

- Replaced the old single-provider status model with routing-aware status surfaces in the header, sidebar, conversation view, and settings sheet.
- Kept local and cloud provider security hardening intact while reusing it across concurrent planning requests.
- Enlarged the settings sheet and reorganized it into clearer sections for appearance, routing, provider configuration, tooling, and privacy.

### Fixed

- Removed the product ambiguity where AppForge looked like it supported only one provider at a time even when several providers were configured.
- Normalized provider settings so the selected lead provider and active-provider set remain internally consistent.
- Preserved build stability after the routing refactor by verifying the full macOS app build and launch path.

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
