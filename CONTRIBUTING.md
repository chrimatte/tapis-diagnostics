# Contributing to Tapis Scan

The default branch is `main`. Use short-lived `feat/<topic>`, `fix/<topic>` or
`chore/<topic>` branches and pull requests when collaborating.

Use Conventional Commits: `<type>(<optional scope>): <description>`.
Keep documentation, UI copy and comments in English. Do not include real BLE
logs, credentials or personal information in test fixtures or public issues.

## Checks

- `swift test`: core XCTest suite; requires a compatible Swift compiler and SDK.
  All 12 tests pass with Xcode 26.6.
- `git diff --cached --check`: added whitespace errors and conflict markers.
- Gitleaks 8.30.1: `gitleaks git --pre-commit --staged --redact=100 --no-banner .`.

The versioned `.githooks/pre-commit` runs the last two checks without modifying
the index. Enable it with `git config --local core.hooksPath .githooks` after
checking that this will not replace existing hooks. Gitleaks must be on PATH.
Run the Swift suite explicitly; it is not part of the commit hook.

Open `Tapis.xcodeproj`; see the README for installation instructions.
`project.yml` is the XcodeGen source. Regenerate the project with
`xcodegen generate` after changing target settings or adding source files.

## Screenshots

The README screenshots are unedited captures of the running iOS Simulator.
The telemetry screenshot uses the app's explicitly labelled simulation mode,
not a real treadmill. To reproduce it, install a simulator build and launch:

```sh
xcrun simctl launch booted com.chrimatte.tapis --demo
# Scroll down to the live readings in the simulator first.
xcrun simctl io booted screenshot docs/images/telemetry-simulation.png
```

For the initial scanning screen, relaunch without `--demo`. Keep screenshots
free of real device identifiers and personal data. The app icon is referenced
directly from its asset catalog rather than duplicated in the documentation.
