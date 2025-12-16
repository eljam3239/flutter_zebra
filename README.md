# flutter_zebra

Flutter wrapper for Zebra's iOS and Android link-OS sdks.

## Features
- **Cross-platform printer discovery** (TCP, USB, Bluetooth/BLE)
- **Automatic paper width detection** with manual override
- **Label & Receipt printing** with dynamic formatting based on paper width
- **Label printing** with barcode generation and text styling
- **Multi-label printing** with quantity control
- **Logo/image printing** support

## Installation
1. Clone the repo:
```bash
git clone git@github.com:eljam3239/flutter_zebra.git
cd flutter_zebra
```

## Getting Started
1. Download the iOS and Android Link-OS Multiplatform SDKs [here](https://www.zebra.com/us/en/support-downloads/software/printer-software/link-os-multiplatform-sdk.html)
2. iOS
    1. Create a Frameworks directory in your clone at packages/zebra_printer_ios/ios.
    2. Drag libZSDK_API.a to packages/zebra_printer_ios/ios/Frameworks.
    3. Create a ZSDK_API.xcframework directory within Frameworks.
    4. Drag the ios-arm64 folder, ios-arm64_x86_64_simulator folder and info.plist file into Frameworks/ZSDK_API.xcframework.
3. Android
    1. Copy ZSDK_ANDROID_API.jar to packages/zebra_printer_android/android/libs.
    2. Ensure the following is under the "android" item in packages/zebra_printer_android/android/build.gradle: 
    packagingOptions {
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/NOTICE.txt'
        exclude 'META-INF/NOTICE'
        exclude 'META-INF/LICENSE'
        exclude 'META-INF/DEPENDENCIES'
      }
 
4. Install dependencies:
```zsh
$ flutter clean
```
then 
```zsh
$ flutter pub get
```
5. Run the application:
```bash
$ flutter run
```

## Tested Devices
| Device | ZD421 | ZD410 |
| -------|-------|-------|
| iOS    |   TCP    | TCP, Bluetooth Classic |
| Android|   TCP, BTLE (direct), USB    | TCP, Bluetooth Classic, BTLE (direct) |

## ZPL
https://zplmagic.com/