# Window Gaffer assets

`WindowGafferAssets.xcassets` contains the resources consumed by the application
build:

- `AppIcon.appiconset` provides the required macOS app icon sizes.
- `MenuBarIcon.imageset` provides the monochrome template image used in the
  menu bar. macOS supplies the correct color for the current appearance.

`WindowGaffer.icns` is available for manually assembled application bundles.
Rebuild it after changing the app icon set:

```sh
python3 Scripts/build_icns.py
```

`WindowGaffer-Logo-Horizontal.svg` is the horizontal brand lockup displayed in
the project README.

The deployable website assets live under `website/dist/assets`.
