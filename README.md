# Scamp

Minimal native macOS music player prototype.

## Standard macOS App Build

Build and publish `Scamp.app` at the repo root:

```bash
mise build
```

Build fresh and launch:

```bash
mise start
```

After build, a convenient copy is available at:

```bash
./Scamp.app
```

`mise start` will:
- stop any running `Scamp` process
- remove root app bundles (`Scamp.app` and legacy `Sampt.app`)
- clear derived build output
- build fresh and publish to `/Users/grahamotte/src/scamp/Scamp.app`
- launch the app

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
mise build
mise start
```
