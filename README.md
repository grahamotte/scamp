# Scamp

Minimal native macOS music player prototype.

## Standard macOS App Build

Build the app target:

```bash
./scripts/build-macos.sh
```

Open the app:

```bash
./scripts/open-macos.sh
```

After build, a convenient copy is available at:

```bash
/Users/grahamotte/src/scamp/Scamp.app
```

If `project.yml` changes, regenerate the project:

```bash
brew install xcodegen
xcodegen generate
```

## Tool Versions

Use pinned tool versions from version-controlled files:

```bash
mise trust
mise install
mise run build
mise run open
```
