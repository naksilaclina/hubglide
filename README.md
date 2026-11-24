<img src="docs/hubglide.png" width="96" alt="HubGlide icon" align="right">

# HubGlide

**Magic Mouse and scroll-wheel input for the iPhone simulator in Xcode 27 Device Hub.**

HubGlide is an open-source macOS menu bar utility for cases where a Magic Mouse scrolls normally in Mac apps but an iPhone simulator in Device Hub ignores the same gesture. It turns vertical scrolling over the selected simulator display into a continuous touch-style drag. It's designed for testing scroll-driven CSS and JavaScript animations in **iOS Safari inside the simulator**.

[Releases and downloads](https://github.com/naksilaclina/hubglide/releases) · [Report a problem](https://github.com/naksilaclina/hubglide/issues/new/choose) · [Project facts for coding assistants](llms.txt)

## The problem

Xcode 27 moved iPhone simulation into Device Hub. Apple documents native scroll support for standard UIKit components. In the setup that prompted HubGlide, Magic Mouse scrolling worked in macOS Chrome, but iPhone Safari in Device Hub needed a button-held drag.

Page Up and Page Down move whole sections at once, which makes it hard to spot when a scroll-linked animation starts or reverses. HubGlide keeps the page in iOS Safari and uses the magnitude, direction, and timing of Mac scroll input to move it. The output is a simulated drag, so its motion can differ from a physical iPhone flick.

## Install

Use Xcode 27 with Device Hub and an installed iOS simulator runtime. The downloadable build is for Apple silicon.

### Build from source

Use Xcode or the macOS Command Line Tools with Swift 6 or later.

```sh
git clone https://github.com/naksilaclina/hubglide.git
cd hubglide
swift test
./Scripts/build-app.sh
open dist/HubGlide.app
```

You can move the resulting app to Applications. To rebuild, choose a fresh output directory or move the previous bundle first.

### Download

The [releases page](https://github.com/naksilaclina/hubglide/releases) provides a ZIP and SHA-256 checksum. The bundle is ad-hoc signed and has no Apple notarization. Gatekeeper may block a downloaded copy. If it does, build a local copy from source.

## Set up and scroll

1. Open an iPhone simulator in Device Hub.
2. Launch HubGlide and grant access under **System Settings → Privacy & Security → Accessibility**.
3. Click the up/down arrow in the menu bar and choose **Select simulator screen…**. When the overlay appears, drag a box from one inside corner of the phone display to the opposite corner. Leave out the bezel and Device Hub controls. That box tells HubGlide where it may translate scroll input. You only do this during setup or after a layout change.
4. With Device Hub in front, hover over the phone display and scroll vertically. Choose **Gentle**, **Standard**, or **Fast** under **Sensitivity**. Use **Enable scrolling** to pause or resume.

Reselect the display after resizing, rotating, changing zoom, or toggling a sidebar that shifts the display. Moving an unchanged window on the desktop preserves the selection. To stop, choose **Quit HubGlide** or revoke the Accessibility permission.

## Compatibility

| Item | Scope |
| --- | --- |
| Target | iOS Simulator in Apple Device Hub for Xcode 27 |
| Initial test environment | Apple silicon, macOS 27.2, Xcode 27.2, iPhone 18 Pro on iOS 27.2, Magic Mouse |
| Gesture | Vertical Mac scroll translated to touch-style dragging |
| Other devices | Other mouse models, trackpads, iPad models and physical iPhones are unverified |
| Window layout | One selected display at a time |

At the edge of the selected area, a long continuous gesture can run out of drag space. Lift your finger briefly and scroll again. HubGlide leaves horizontal and Command-, Control-, or Option-modified scrolling to macOS.

## How it works and what it accesses

HubGlide uses Swift, AppKit and Quartz. It checks the foreground application, the window under the pointer and the selected display. When those match, it translates scroll input into an interpolated drag sent to Device Hub. The touch stays down across incoming scroll packets and ends after a brief pause. HubGlide never deliberately repositions the pointer.

Accessibility permission is required for input handling. HubGlide does not record the screen, observe keystrokes, contact a server, or collect telemetry. It stores the selected rectangle, sensitivity and enabled state locally.

## Troubleshooting

- **Scroll works on the Mac but not in iPhone Safari.** Bring Device Hub to the front, check the HubGlide menu status, hover inside the selected display, and pause any other scroll translator.
- **The menu reports missing permission or unavailable input.** Review Accessibility permission. After replacing the app, you may need to re-add it or relaunch it.
- **It stopped after changing the Device Hub layout.** Run **Select simulator screen…** again to match the new layout.
- **Does this change my website?** HubGlide works on the Mac input side, with zero browser extensions or website changes.
- **Do I need it if Device Hub already scrolls?** Use the native behavior if it works for your setup.

[Apple’s Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)

## Contribute

Run `swift test` for motion and display-selection checks. If you report an issue, include macOS, Xcode and simulator versions, the input device, and whether button-held dragging works. See [CONTRIBUTING.md](CONTRIBUTING.md).

HubGlide is an independent project. Apple, Xcode, Device Hub and Magic Mouse are used to identify compatibility. [MIT License](LICENSE).
