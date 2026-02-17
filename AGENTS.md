# Scamp Agent Guide

## Product Goal

- Build a native macOS music player inspired by Winamp simplicity but not Winamp compatibility.
- Prioritize a vinyl-like playback experience as the defining identity.
- Keep the app focused, fast, and intentionally small in early versions.

## UX

- Show a spinning vinyl record as the primary now-playing visual.
- Tie record motion directly to playback state (play, pause, stop).
- Make loading music explicit through user file or folder selection.
- Avoid hidden background indexing of the full machine library.
- Support local audio file playback.
- Exclude streaming, cloud sync, plugins, and theme systems.

## Technical Defaults

- Use Swift for implementation.
- Use SwiftUI for UI and AppKit only when required.
- Use AVFoundation for audio playback.
- Target the latest stable macOS major version (currently macOS 26.2) unless explicitly changed.
- Strongly prefer native window and control styling.

## Workflow

- Keep changes in thin, testable vertical slices.
- Keep playback engine, queue state, ingestion, and visualization as separate concerns.
- After code changes, run `mise start` and report result.

## Platform Constraints

- Keep App Sandbox enabled and add only the minimum required entitlements.
- Use user-selected file access patterns and avoid broad filesystem permissions.
- Avoid private APIs and nonstandard runtime hacks.

## Collaboration

- Call out incorrect assumptions about macOS, Swift, SwiftUI, or AVFoundation.
- Keep recommendations practical and biased toward momentum.
- Choose options that feel native, simple, and easy to evolve.
