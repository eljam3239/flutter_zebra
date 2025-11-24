import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:zebra_printer/zebra_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Zebra Printer Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<DiscoveredPrinter> _discoveredPrinters = [];
  bool _isConnected = false;
  String _printerStatus = 'Unknown';
  DiscoveredPrinter? _selectedPrinter;
  bool _isDiscovering = false;
  int _labelQuantity = 1;

  Future<void> _discoverPrinters() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      // Use actual Zebra printer discovery
      print('[Flutter] Starting printer discovery...');
      final printers = await ZebraPrinter.discoverPrinters();
      print('[Flutter] Discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        // Preserve selected printer reference if it still exists, otherwise select first
        if (_selectedPrinter != null) {
          final matchingPrinter = _discoveredPrinters
              .where((p) => p.address == _selectedPrinter!.address)
              .firstOrNull;
          _selectedPrinter = matchingPrinter ?? (_discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null);
        } else {
          _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        }
        
        _isDiscovering = false;
        _labelQuantity = 1;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] Discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery failed: $e')),
      );
    }
  }

  Future<void> _discoverMulticastPrinters() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting multicast discovery...');
      final printers = await ZebraPrinter.discoverMulticastPrinters(hops: 3);
      print('[Flutter] Multicast discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        // Preserve selected printer reference if it still exists, otherwise select first
        if (_selectedPrinter != null) {
          final matchingPrinter = _discoveredPrinters
              .where((p) => p.address == _selectedPrinter!.address)
              .firstOrNull;
          _selectedPrinter = matchingPrinter ?? (_discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null);
        } else {
          _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        }
        
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Multicast found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] Multicast discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Multicast discovery failed: $e')),
      );
    }
  }

  Future<void> _discoverSubnetPrinters() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting subnet search discovery...');
      // Search common private network ranges
      final printers = await ZebraPrinter.discoverSubnetSearch('10.20.30.*');
      print('[Flutter] Subnet discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subnet search found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] Subnet discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subnet discovery failed: $e')),
      );
    }
  }

  Future<void> _discoverNetworkPrintersAuto() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting automatic network discovery...');
      final printers = await ZebraPrinter.discoverNetworkPrintersAuto();
      print('[Flutter] Auto discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto discovery found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] Auto discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto discovery failed: $e')),
      );
    }
  }

  Future<void> _discoverBluetoothPrinters() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting Bluetooth LE discovery...');
      final printers = await ZebraPrinter.discoverBluetoothPrinters();
      print('[Flutter] Bluetooth discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] Bluetooth discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      
      String errorMessage = 'Bluetooth discovery failed: $e';
      
      // Check if it's a permissions error and provide helpful guidance
      if (e.toString().contains('MISSING_PERMISSIONS') || e.toString().contains('permission')) {
        errorMessage = 'Bluetooth permissions required!\n\n'
            'Please go to Settings > Apps > Flutter Zebra > Permissions '
            'and enable:\n• Nearby devices (Bluetooth)\n• Location\n\n'
            'Then restart the app and try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _discoverBluetoothNative() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting native Bluetooth scan...');
      final printers = await ZebraPrinter.discoverBluetoothNative();
      print('[Flutter] Native Bluetooth scan completed. Found ${printers.length} devices');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Native BT scan found ${_discoveredPrinters.length} devices')),
      );
    } catch (e) {
      print('[Flutter] Native Bluetooth scan failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Native BT scan failed: $e')),
      );
    }
  }

  Future<void> _testDirectBleConnection() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Testing direct BLE connection to ZD421...');
      final printers = await ZebraPrinter.testDirectBleConnection();
      print('[Flutter] Direct BLE test completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Direct BLE test found ${_discoveredPrinters.length} devices')),
      );
    } catch (e) {
      print('[Flutter] Direct BLE connection test failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Direct BLE test failed: $e')),
      );
    }
  }

  Future<void> _discoverUsbPrinters() async {
    // Check if running on iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('iOS doesn\'t support USB discovery or printing'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Android implementation - discover USB printers
    setState(() {
      _isDiscovering = true;
    });

    try {
      print('[Flutter] Starting USB printer discovery...');
      final printers = await ZebraPrinter.discoverUsbPrinters();
      print('[Flutter] USB discovery completed. Found ${printers.length} printers');
      
      setState(() {
        // Clear the list first to avoid duplicates
        _discoveredPrinters.clear();
        
        // Add new printers with deduplication based on address
        final uniquePrinters = <String, DiscoveredPrinter>{};
        for (final printer in printers) {
          uniquePrinters[printer.address] = printer;
        }
        _discoveredPrinters = uniquePrinters.values.toList();
        
        // Preserve selected printer reference if it still exists
        if (_selectedPrinter != null) {
          final matchingPrinter = _discoveredPrinters
              .where((p) => p.address == _selectedPrinter!.address)
              .firstOrNull;
          _selectedPrinter = matchingPrinter;
        }
        
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('USB discovery found ${_discoveredPrinters.length} printers')),
      );
    } catch (e) {
      print('[Flutter] USB discovery failed: $e');
      setState(() {
        _isDiscovering = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('USB discovery failed: $e')),
      );
    }
  }

  Future<void> _requestBluetoothPermissions() async {
    try {
      print('[Flutter] Requesting Bluetooth permissions...');
      final granted = await ZebraPrinter.requestBluetoothPermissions();
      
      if (!mounted) return;
      
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions granted! You can now use Bluetooth discovery.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions denied. Please grant them manually in Settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('[Flutter] Permission request failed: $e');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission request failed: $e')),
      );
    }
  }

  Future<void> _connectToPrinter() async {
    if (_selectedPrinter == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first.')),
      );
      return;
    }

    try {
      // Create connection settings based on the selected printer's interface type
      ZebraInterfaceType interfaceType;
      if (_selectedPrinter!.interfaceType == 'bluetooth') {
        interfaceType = ZebraInterfaceType.bluetooth;
      } else if (_selectedPrinter!.interfaceType == 'usb') {
        interfaceType = ZebraInterfaceType.usb;
      } else {
        interfaceType = ZebraInterfaceType.tcp;
      }
      
      final settings = ZebraConnectionSettings(
        interfaceType: interfaceType,
        identifier: _selectedPrinter!.address,
        timeout: 15000,
      );

      await ZebraPrinter.connect(settings);
      
      setState(() {
        _isConnected = true;
        _printerStatus = 'Connected';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to: ${_selectedPrinter!.friendlyName ?? _selectedPrinter!.address}')),
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _printerStatus = 'Connection Failed';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  Future<void> _disconnectFromPrinter() async {
    try {
      await ZebraPrinter.disconnect();
      setState(() {
        _isConnected = false;
        _printerStatus = 'Disconnected';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from printer')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    }
  }

  Future<void> _printReceipt() async {
    if (!_isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a printer first')),
      );
      return;
    }

    try {
      // Use the receipt ZPL
      const receiptZpl = '''
^XA
^CF0,47
^FO226,64
^FDTest Store^FS
^CF0,27
^FO156,388
^FD100 LeBron St, Cleveland, OH^FS
^CF0,30
^FO470,478
^FDCashier: Eli^FS
^CF0,30
^FO470,526
^FDLane: 1^FS
^CF0,30
^FO188,834
^FDThank you for coming!^FS
^CF0,30
^FO20,478
^FDTue Nov 11 4:03 PM^FS
^FO200,132
^GFA,7200,7200,30,!::::::::::::::::::::::::::::::::::::::::::::::gVF03!gTFCJ0!gTFL0!XFCH0RF8L03!:WFEJ07OFEM01!WFK01OFCN0!VFCL03NFO01!VF8L01MFEP0!UFCN0MFCP07!:UF8N07LF8I01HFJ07!UFO03LFI01IFCI03!UFI03HFJ0LFI07IFK0!TFEI0IFJ07JFCI0IFEK0!TFCH03HFEJ07JFCH03IFEK07!:TFCH0IFEJ03JF8H07IFEH08H07!TFH01IFE02H03JF8H0JFE03CH07!TFH03JF03H01JFI0KF03EH03!TFH03JFCFC01JFH01MFEH03!SFEH07LFC01JFH01MFEH03!:SFEH07LFCH0JFH01NFH01!SFEH07LFEH0IFEH03NFH01!SFEH0MFEH0IFEH03NFH01!:::SFEH0MFEH0HF9EH03NFH01!SFEH0MFEH0FC0EH03NFH01!SFEH0MFEH0FH0EH03NFH01!SFEH07LFEH0EH0EH03NFH01!SFEH07LFC01CH03H01NFH01!:SFEH07LFCK03H01MFEH03!TFH03LFL01I0MFEH03!TFH03LFL01I0MFCH03!TFH01KFEL018H07LFCH07!TFCH0KFCM08H03LF8H07!:TFCH03JF8M0CH03LFI07!TFEI0IFCN04I0LF8H0!UFH03JFN07H03LFE03!UF81KFEM0380NFC3!UF87LFM0381OF7!:gIFN0C3!gIFN07!gHFEN03!gHFCN01!gHFCO0!:gHFCO03!gHF8O01!gHF8P07!gHF8P03!gHF8Q07!:gHF8R0!gHFES0!gHFES03!gIFT07!gIFCS0!:gIFER03!gJFR07!gJFQ01!gJF8P03!gJFCO01!:gKF8N07!gKFCM03!gKFEM0!gLFCK03!gMFJ07!:gNFH0!!:::::::::::::gFH0!XFCK07!:WFCM01!VFEP0!VFR0!UF8R01!TFET01!:TFCU07!SFEW0!SFCW01!SFY03!RFCg0!:RF8g03!RFgH07!QFEgH01!QFCgI03!QFgJ01!:PFEgK07XFC!PFCgL0XF0!PFCgL07VF80!MFgP01UFCH0!LFgR0UFCH0!:KFC03FCgN01UFC0!KF03HFCgO0UFC0!JFE0IF8gO07TFC0!JF81IFgR0SFC0!JF83IFgS03QFC0!:JF0IFEgT01PFC0!IFC1IFCgU03OFC0!IF81IFCgV07NFC0!IF83IFgX0NFC0!IF03IFgX03MFC0!:IF07HFEgX01MFC0!IF07HFEgY03LFC0!HFE07HFEh0LFC0!HFE07HFEh07KFC0!HFE07HFEhG07JFC0!:HFE07HFEhH03IFC0!HFC0IFEhH01IFC0!HFC0JFhI0IFC0!HFC07IFhI07HFC0!HFC07IFChH07HFC0!:HFC07IFEhH07HFC0!HFC07JFU078gK03HFC0!HFC07JF8T07gL03HFC0!HFE07KFQ07E04gM0HFC0!HFE07KFCN01HFE04gM07FC0!:HFE03LFEM0IFEgO03FC0!HFE03NFE07FE0IFEgO01FC0!IF03NFE0HFE0IFEgO01FC0!IF01NFE0HFE0IFEgP0FC0!IF80NFC1HFE0IFEgP03C0!:IF80NFC1HFE0IFEgP01C0!IFC03MF83HFE0IFEgQ0C0!IFC01MF8IFE0IFEgQ0C0!JFH0MF0IFE07HFEgQ040!JF807KFC1IFE07HFEgQ040!:JFC03KF83IFE07HFCgS0!JFEH0KF07JF03HF8gS0!KFH03IFC3KFH0HFgT03!JFCI03FC07KF8gX0!JF8L01LFCI0CgT03HF:JF83CI01NF8078gO03E3!JF1HF8I0QF8gK07!JF3HFEJ03OF8gH07!JF3IFCK0NF8Y07!IFC7JFM0KF8W03!:JF7JFCgL03!PFgJ07!PFCgK0!QFgM0!QFEgN07RFC!:SFK07HF8gG0OFC0!gNFCgJ03!gRFg07!gTF8V0!gVFCQ03!:!:::::::^FS
^FO44,574^GB554,1,2,B,0^FS
^FO44,778^GB554,1,2,B,0^FS
^CF0,30
^FO20,530
^FDReceipt No: 67676769^FS
^CF0,30
^FO56,612
^FD1 x Orange^FS
^CF0,30
^FO54,670
^FD1 x Orange^FS
^CF0,30
^FO56,724
^FD1 x Orange^FS
^CF0,30
^FO470,614
^FD\$5.00^FS
^CF0,30
^FO470,670
^FD\$5.00^FS
^CF0,30
^FO470,724
^FD\$5.00^FS
^XZ''';
      
      await ZebraPrinter.sendCommands(receiptZpl, language: ZebraPrintLanguage.zpl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }

  Future<void> _printLabel() async {
    if (!_isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a printer first')),
      );
      return;
    }
    String productName = "T-Shirt";
    String colorSize = "Small Turquoise";
    String scancode = "123456789";
    String price = "\$5.00";
    double paperWidthMM = 54.1;

    int scancodeLength = scancode.length;
    // Calculate barcode position
    int dpi = 203;
    double paperWidthInches = paperWidthMM / 25.4;
    int paperWidthDots = (paperWidthInches * dpi).round();

    // Estimate barcode width for Code 128
    // Code 128: Each character takes ~11 modules + start/stop characters
    int totalBarcodeCharacters = scancodeLength + 3; // +3 for start, check, and stop characters
    int moduleWidth = 2; // from ^BY2
    int estimatedBarcodeWidth = totalBarcodeCharacters * 11 * moduleWidth;

    // Calculate centered X position for barcode
    int barcodeX = (paperWidthDots - estimatedBarcodeWidth) ~/ 2;

    // Ensure barcode doesn't go off the left edge
    barcodeX = barcodeX.clamp(0, paperWidthDots - estimatedBarcodeWidth);


    try {
      // Use the updated T-Shirt label ZPL
      String tShirtLabelZpl = '''
^XA
^CF0,27
^FO104,150
^FD^FS
^CF0,25
^FO0,90^FB433,1,0,C^FD$colorSize^FS
^BY2,3,50
^FO$barcodeX,124^BCN^FD$scancode^FS
^CF0,38
^FO0,52^FB433,1,0,C^FD$price^FS
^CF0,38
^FO0,14^FB433,1,0,C^FD$productName^FS
^XZ''';
      
      // Print labels based on quantity
      for (int i = 0; i < _labelQuantity; i++) {
        await ZebraPrinter.sendCommands(tShirtLabelZpl, language: ZebraPrintLanguage.zpl);
        
        // Small delay between labels to prevent overwhelming the printer
        if (i < _labelQuantity - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_labelQuantity label(s) sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Label print failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Zebra Printer Controls', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text('Discovered Printers: ${_discoveredPrinters.length}'),
                    if (_discoveredPrinters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Select Printer:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DiscoveredPrinter>(
                            value: _selectedPrinter,
                            hint: const Text('Select a printer'),
                            isExpanded: true,
                            items: _discoveredPrinters.map((printer) {
                              final displayName = printer.friendlyName?.isNotEmpty == true 
                                  ? printer.friendlyName!
                                  : 'Zebra Printer';
                              final displayAddress = printer.address.length > 15 
                                  ? '${printer.address.substring(0, 15)}...'
                                  : printer.address;
                              return DropdownMenuItem<DiscoveredPrinter>(
                                value: printer,
                                child: Text('$displayName ($displayAddress)'),
                              );
                            }).toList(),
                            onChanged: (DiscoveredPrinter? newValue) {
                              setState(() {
                                _selectedPrinter = newValue;
                                _isConnected = false;
                                _printerStatus = 'Unknown';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPrinter != null)
                        Text('Selected: ${_selectedPrinter!.address} (Port: ${_selectedPrinter!.port})', 
                             style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 16),
                    Text('Connection Status: ${_isConnected ? "Connected" : "Disconnected"}'),
                    const SizedBox(height: 8),
                    Text('Printer Status: $_printerStatus'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: _isDiscovering 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Discover Printers (Local)'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverMulticastPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Discover (Multicast)'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverSubnetPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Discover (Subnet)'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverNetworkPrintersAuto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Auto Discover'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverBluetoothPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Discover (Bluetooth)'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverBluetoothNative,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Native BT Scan'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _testDirectBleConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Direct BLE Test'),
                        ),
                        ElevatedButton(
                          onPressed: _isDiscovering ? null : _discoverUsbPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Discover USB'),
                        ),
                        ElevatedButton(
                          onPressed: _requestBluetoothPermissions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Grant BT Permissions'),
                        ),
                        ElevatedButton(
                          onPressed: _selectedPrinter != null && !_isConnected ? _connectToPrinter : null,
                          child: const Text('Connect'),
                        ),
                        ElevatedButton(
                          onPressed: _isConnected ? _disconnectFromPrinter : null,
                          child: const Text('Disconnect'),
                        ),
                        ElevatedButton(
                          onPressed: _isConnected ? _printReceipt : null,
                          child: const Text('Print Receipt'),
                        ),
                        ElevatedButton(
                          onPressed: _isConnected ? _printLabel : null,
                          child: const Text('Print Label'),
                        ),
                        
                      ],
                    ),
                    const SizedBox(height: 16),
                        const Text('Number of Labels to Print:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(text: _labelQuantity.toString()),
                                onChanged: (v) {
                                  final qty = int.tryParse(v) ?? 1;
                                  setState(() => _labelQuantity = qty.clamp(1, 100));
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Slider(
                                value: _labelQuantity.toDouble(),
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: _labelQuantity.toString(),
                                onChanged: (v) => setState(() => _labelQuantity = v.round()),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
