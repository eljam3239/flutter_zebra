import 'package:flutter/material.dart';
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
        _discoveredPrinters = printers;
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
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
        _discoveredPrinters = printers;
        _selectedPrinter = _discoveredPrinters.isNotEmpty ? _discoveredPrinters.first : null;
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
        _discoveredPrinters = printers;
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
        _discoveredPrinters = printers;
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

  Future<void> _connectToPrinter() async {
    if (_selectedPrinter == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first.')),
      );
      return;
    }

    try {
      // Create connection settings based on the selected printer
      final settings = ZebraConnectionSettings(
        interfaceType: ZebraInterfaceType.tcp,
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
^FO226,68
^FDTest Store^FS
^CF0,27
^FO156,132
^FD100 LeBron St, Cleveland, OH^FS
^CF0,30
^FO60,586
^FDCashier: Eli^FS
^CF0,30
^FO476,586
^FDLane: 1^FS
^FX GF command parameters:
^FX - format (A/B/C)
^FX - dataBytes (number)
^FX - totalBytes (number)
^FX - rowBytes (number)
^FX - image data (bytes)
^FO33,40^GFA,1860,1860,15,,::X038,X0FE,X0FF,W01C3C,W0781F8,V0FF801E,S0181E6I07,S03838J03,S078FK038,S0FFCK01C,S0EF8002I0F,S0C0030F80078,R01C00FDFC0038,S0C039FFE001C,S0E070C070F8C,S0E06I03FF86,S0F0CI01E1C6,S0FB8L0C7,S0DF8001800C3,R01DDC003C00C3,S0DAJ0C01838,S0F8J0603038,S0FK0207038,S07M03878,S0E1L07C78,S0E38307003E7,S0E3830FC03F7,S0C38607C03F7,R01C30E00C03FE,J08M01C00C00406FE,I03FM01C018J07FE,I063M01C038J037C,I0C1M01C038J07BC,00181M01C038J02B8,00103M018038J0338,00103M01801CK038,00303M01CJ0CI018,00303M01C4I0EI01C,00303M01CE003F8001C,00303M01DFE3E38001C,00303N0DC3E0780038,00103N0EF003D800F8,001838M0E5C0F1807F,00181CM0E07FCI07E,003E0FM0700EJ0E,03FF878L07014I01E,0F03E3CL0383EI03C,1C0071CL03C1CI078,180038EL01CK0FC,180018F8K01EJ01FF8,18001C7F8K0FJ07E3F,18001C7NFCJ0C1FC,1FFE1C7BMFEJ0C19F,0FDFFC78I06001FC0018387C,0C00F87CL038FF870383E,1C00386CL038FF9E0700F8,1C001C4CL0387FF807003C,1CI0ICL0383FF00E001E,1E700CECL01C0F801CI0F,0IFJCL01CJ038I07C,07IFICM0EJ0FJ01E,060078C8M06I01EK0E,06003CC8M06I0F8K07,06001DD8J06006003EL038,07003FBK0600E00FM01C,03C0FB3K0E00E00CN0E,01IF66J03E00E008N07,00FCFECI03E600E018N038,007FFD8007F0600C018N01C,I0MF80600C018O0C,K03FFEI0E01C018O0E,R0E01C018O07,R0E01C018007L038R0E018038003CK038R0E018038I0FK01CR06018038I03EK0CR06018038J0FCJ0CR0601803K07FJ0CR0601803K0E7CI0CR0601803K0E1C0018R0601803K0E180018R0601803K0C3I01,R0601803J01C3I03,R0601803J01C6I03,R0603803J01C6I06,R0703803J01CCI06,R0701803J01CCI0C,R0701803J01D8I0C,R0781803J01980018,R07E1803J03B80018,R07F9803J03BI03,R03BF803J07FI03,R038F803I03FFI06,R0383003803IFI06,R038I03IFC3FI0C,R038J0FF803F801C,R038N03FE018,R038N03CF03,R01CN0387FF,R01CN0383FE,R01CN03803E,R01FN0F807F,R01FCL07F80E3,S0CFCJ07FF80E3,S0C1FF1KFC0DB,S0C03LF1C07B,S0CI0JF00C03F,S0CO0E006,S0EO0F00E,S0EO07FFC,S06O07BFC,S06O038,:S07O01C,:S02P0C,,::::^FS
^CF0,30
^FO188,1064
^FDThank you for coming!^FS
^CF0,30
^FO202,178
^FDTue Nov 11 4:03 PM^FS
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
