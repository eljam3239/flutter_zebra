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

## Zebra SDK Integration

### Core Models

#### LabelData
The fundamental model for creating product labels:

```dart
LabelData(
  productName: "T-Shirt",
  colorSize: "Small Turquoise",
  scancode: "123456789",
  price: "\$5.00",
  customFields: {} // Optional additional data
)
```

#### ReceiptData
Container for receipt information with line items:

```dart
ReceiptData(
  storeName: "My Store",
  storeAddress: "123 Main Street",
  storePhone: "(555) 123-4567", // Optional
  receiptNumber: "12345",         // Optional
  transactionDate: DateTime.now(),
  cashierName: "John Doe",        // Optional
  laneNumber: "3",                // Optional
  items: [
    ReceiptLineItem(
      quantity: 2,
      itemName: "Coffee",
      unitPrice: 3.50,
    ),
    ReceiptLineItem(
      quantity: 1,
      itemName: "Muffin",
      unitPrice: 2.75,
    ),
  ],
  thankYouMessage: "Thank you for shopping with us!", // Optional
)
```

#### ConnectedPrinter
Stores printer information with auto-detected dimensions:

```dart
ConnectedPrinter(
  discoveredPrinter: selectedPrinter,
  printWidthInDots: 639,
  labelLengthInDots: 1015,
  dpi: 203,
  connectedAt: DateTime.now(),
)
```

### Basic Printing Workflow

#### 1. Printer Discovery
```dart
Future<void> _discoverPrinters() async {
  try {
    // Auto discovery (recommended)
    final printers = await ZebraPrinter.discoverNetworkPrintersAuto();
    
    // Or specific discovery methods
    final btPrinters = await ZebraPrinter.discoverBluetoothPrinters();
    final usbPrinters = await ZebraPrinter.discoverUsbPrinters(); // Android only
    final subnetPrinters = await ZebraPrinter.discoverSubnetSearch('10.20.30.*');
  } catch (e) {
    print('Discovery failed: $e');
  }
}
```

#### 2. Connection with Auto-Dimension Detection
```dart
Future<void> _connectToPrinter() async {
  final settings = ZebraConnectionSettings(
    interfaceType: ZebraInterfaceType.tcp, // or .bluetooth, .usb
    identifier: "10.20.30.32",             // IP address or MAC address
    timeout: 15000,
  );
  
  await ZebraPrinter.connect(settings);
  
  // Auto-fetch printer dimensions after connection
  final dimensions = await ZebraPrinter.getPrinterDimensions();
  // Returns: {'printWidthInDots': 639, 'labelLengthInDots': 1015, 'dpi': 203, ...}
}
```

#### 3. Dynamic ZPL Generation
```dart
Future<String> _generateLabelZPL(int width, int height, int dpi, LabelData labelData) async {
  // Calculate positions based on actual printer DPI and dimensions
  int getCharWidthInDots(int fontSize, int dpi) {
    if (fontSize <= 25) return 10;
    else if (fontSize <= 38) return 20;
    else return (fontSize * 0.5).round();
  }
  
  // Calculate centered positions
  int productNameCharWidth = getCharWidthInDots(38, dpi);
  int estimatedWidth = labelData.productName.length * productNameCharWidth;
  int centeredX = (width - estimatedWidth) ~/ 2;
  
  return '''
^XA
^CF0,38
^FO$centeredX,14^FD${labelData.productName}^FS
^BY2,3,50
^FO100,124^BCN^FD${labelData.scancode}^FS
^XZ''';
}
```

#### 4. Print Labels
```dart
Future<void> _printLabel() async {
  final labelData = LabelData(
    productName: "T-Shirt",
    colorSize: "Small Turquoise",
    scancode: "123456789",
    price: "\$5.00",
  );
  
  // Use actual printer dimensions for dynamic layout
  final width = connectedPrinter.printWidthInDots ?? 386;
  final height = connectedPrinter.labelLengthInDots ?? 212;
  final dpi = connectedPrinter.dpi ?? 203;
  
  final zpl = await _generateLabelZPL(width, height, dpi, labelData);
  await ZebraPrinter.sendCommands(zpl, language: ZebraPrintLanguage.zpl);
}
```

#### 5. Print Receipts
```dart
Future<void> _printReceipt() async {
  final receiptData = ReceiptData(
    storeName: "Coffee Shop",
    storeAddress: "123 Main St",
    items: [
      ReceiptLineItem(quantity: 2, itemName: "Latte", unitPrice: 4.50),
      ReceiptLineItem(quantity: 1, itemName: "Croissant", unitPrice: 3.25),
    ],
    cashierName: "John",
    transactionDate: DateTime.now(),
  );
  
  // Dynamic receipt generation with auto-sizing
  final receiptZpl = await _generateReceiptZPL(width, height, dpi, receiptData);
  await ZebraPrinter.sendCommands(receiptZpl, language: ZebraPrintLanguage.zpl);
}
```

### Advanced Features

#### Printer Dimension Management
```dart
// Get current dimensions
final dimensions = await ZebraPrinter.getPrinterDimensions();

// Set custom dimensions (inches)
await ZebraPrinter.setSgdParameter('ezpl.print_width', '2.20');
await ZebraPrinter.setLabelLength(212); // dots
```

#### SGD Parameter Access
```dart
// Read printer configuration
final printWidth = await ZebraPrinter.getSgdParameter('ezpl.print_width');
final labelLength = await ZebraPrinter.getSgdParameter('ezpl.label_length_max');

// Set printer configuration  
await ZebraPrinter.setSgdParameter('ezpl.print_width', '386');
```

#### Dynamic Receipt Sizing
```dart
Future<String> _generateReceiptZPL(int width, int height, int dpi, ReceiptData receiptData) async {
  // Calculate dynamic Y positions for line items
  int yPosition = 612;
  for (var item in receiptData.items) {
    // Add item at yPosition
    yPosition += 56; // Move down for next item
  }
  
  // Position footer elements after all items
  int totalY = yPosition + 42;
  int thankYouY = totalY + 54;
  
  // Auto-expand receipt height if needed
  int minRequiredHeight = thankYouY + 60;
  int actualHeight = height > minRequiredHeight ? height : minRequiredHeight;
  
  // Set dynamic label length if needed
  if (actualHeight > height) {
    zpl = '^XA^LL$actualHeight\n' + zpl.substring(4);
  }
  
  return zpl;
}
```

### Text Positioning Utilities
#### Centered Text Positioning
```dart
int calculateCenteredX(String text, int fontSize, int dpi, int printerWidth) {
  final charWidth = getCharWidthInDots(fontSize, dpi);
  final estimatedTextWidth = text.length * charWidth;
  final centeredX = (printerWidth - estimatedTextWidth) ~/ 2;
  return centeredX.clamp(0, printerWidth - estimatedTextWidth);
}
```

#### Connection Interface Detection
```dart
// Handle different connection types
ZebraInterfaceType getInterfaceType(DiscoveredPrinter printer) {
  switch (printer.interfaceType) {
    case 'bluetooth': return ZebraInterfaceType.bluetooth;
    case 'usb': return ZebraInterfaceType.usb;
    default: return ZebraInterfaceType.tcp;
  }
}
```

### Error Handling

#### Connection Recovery
```dart
Future<void> _connectWithRetry() async {
  try {
    // Force cleanup before new connection
    if (isConnected) {
      await ZebraPrinter.disconnect();
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    await ZebraPrinter.connect(settings);
  } catch (e) {
    if (e.toString().contains('socket might closed')) {
      // Handle Bluetooth connection issues
      throw 'Bluetooth connection failed. Try clearing discoveries and reconnecting.';
    }
    rethrow;
  }
}
```

## ZPL
The entire scope of what is possible using ZPL commands is vast. Many things I first thought weren't possible using the SDK's docs were trivial using a single ZPL command. 

To experientially get a feel for the basics, checkout out this [drag-and-drop ZPL generator](https://zplmagic.com).

For a comprehensive list of documentation and examples for ZPL commands and Set-Get-Do commands, checkout the [ZPL II, ZBI 2, Set-Get-Do, Mirror,WML](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/software/zpl-zbi2-pg-en.pdf#page=10) Programmers Guide. Its over 1700 pages...CTRL-F is your friend. 

## Constraints
1. Bluetooth Low Energy is implemented with direct MAC address pairing only. BTLE via the SDKs claimed functionality was not successful, and a direct MAC address workaround was the only way to get discovery and connection to work. 
2. It seems that Zebra products themselves can enter a 'stale' state, where they aren't discoverable, via this repo's discovery methods, iOS/Android setting bluetooth discovery, or the Zebra app's discovery. I've found that turning the printer off and on again, then putting it into Discovery mode by holding down the feed button, is the only way to make it play nice again with all 3 of the aforementioned discovery methods.