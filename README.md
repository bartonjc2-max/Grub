# GrubIOS

## Build

This project uses [XcodeGen](https://github.com/yonsm/XcodeGen). The `.xcodeproj` is generated from `project.yml`.

```bash
xcodegen generate
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Tests:
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use whatever simulator your machine has installed (`xcrun simctl list devices`);
this machine has iPhone 17 / 17 Pro / Air on iOS 26.0. Verified building **and
testing** on the `descent` branch (base commit 76eb3c3). The GoogleMobileAds SPM
dependency is resolved automatically.
