# Development

## Repository layout

- `Package.swift` defines the Swift package, executable, core library, and test
  target.
- `Sources/WindowGaffer` contains the macOS application and UI.
- `Sources/WindowGafferCore` contains platform-independent behavior that can be
  tested without launching the app.
- `Tests/WindowGafferCoreTests` contains the automated test suite.
- `Configuration/Info.plist` contains the application bundle metadata.
- `Assets/WindowGafferAssets.xcassets` contains the resources consumed by the
  application build.
- `Assets/WindowGaffer.icns` is the standalone icon for manually assembled app
  bundles.
- `Scripts` contains reproducible build and asset utilities.
- `website/dist` is the deployable static website, including its production
  images, styles, and scripts.

## Generated and local-only files

Swift build directories, Finder metadata, packaged applications, and local
release archives are intentionally excluded by `.gitignore`. Publish signed or
notarized application archives through GitHub Releases instead of committing
them to the source tree.

All website download links point to the latest GitHub release:

`https://github.com/Fatal1ty/WindowGaffer/releases/latest`

Publish at least one release that GitHub recognizes as the latest before
deploying the website. Attach the distributable application archive to that
release; do not add it to `website/dist` or commit it to the repository.

## Verify a change

Run the unit tests:

```sh
swift test
```

Build the application bundle:

```sh
./Scripts/build-app.sh
```

Rebuild the standalone icon after changing the app icon set:

```sh
python3 Scripts/build_icns.py
```
