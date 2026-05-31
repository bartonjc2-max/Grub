# GrubIOS

## Build

This project uses [XcodeGen](https://github.com/yonsm/XcodeGen). The `.xcodeproj` is generated from `project.yml`.

```bash
xcodegen generate
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Verified building on the `descent` branch (base commit 76eb3c3). The GoogleMobileAds
SPM dependency is resolved automatically.
