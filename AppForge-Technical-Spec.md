# AppForge Architecture Notes

This document describes the current repository state rather than the original aspirational concept draft.

## Current Product Shape

AppForge is a native macOS SwiftUI application that:

- accepts a prompt for a new app or refinement
- chooses a planning backend
- scaffolds a generated project into `~/AppForge/Projects`
- runs `xcodegen` and `xcodebuild`
- shows project files and build logs in the same UI

## Current AI Backends

Supported routing targets:

- OpenAI API
- Anthropic API
- Ollama local server
- LM Studio local server

The current open-source build does not integrate Xcode coding intelligence.

## Current Generation Model

The generator is still scaffold-first for most prompts. The exception is a built-in Sudoku recipe, which generates a playable macOS Sudoku app with:

- puzzle selection
- clue locking
- hint and clear actions
- mistake highlighting
- completion tracking

## Workspace Model

AppForge keeps generated output in a dedicated user-owned workspace:

```text
~/AppForge/
  Projects/
  Cache/
  Logs/
  Config/
```

## Build Pipeline

Generated apps currently rely on:

- `xcodegen` to turn `project.yml` into `.xcodeproj`
- `xcodebuild` to build the generated macOS app
- `open` to launch the built bundle

## Open-Source Distribution Notes

This repository currently publishes AppForge source only. It does not vendor:

- Xcode
- Apple SDKs
- XcodeGen binaries
- Ollama
- LM Studio
- OpenAI or Anthropic SDKs

Relevant third-party attribution is tracked in `THIRD_PARTY_NOTICES.md`.
