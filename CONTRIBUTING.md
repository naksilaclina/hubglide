# Contributing

Use macOS and Swift 6 or later. Run `swift test` and `./Scripts/build-app.sh`.

For input changes, open Settings in an iPhone simulator in Device Hub. Verify slow, fast and reversed vertical scrolling with a physical mouse. Check that ordinary clicks and scrolling elsewhere behave as usual. Move the Device Hub window and test again. Resize it, verify that the old screen selection stops applying, and select the new display bounds.

In bug reports, include your macOS, Xcode and simulator versions, device model, and mouse or trackpad. Describe what happens after pausing HubGlide. Share cropped screenshots with private information removed.

To publish a release, update `VERSION`, run the automated and manual checks, and build into a fresh output directory. Verify the bundle with `codesign --verify --strict`. Archive the app with `ditto -c -k --keepParent`, attach a SHA-256 checksum, and tag the version. Record the tested setup and notarization status in the release notes.
