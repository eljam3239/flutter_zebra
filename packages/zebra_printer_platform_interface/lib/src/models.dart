/// Data models for zebra printer platform interface

/// Represents a discovered Zebra printer
class DiscoveredPrinter {
  final String address;
  final int port;
  final String? friendlyName;
  final String? serialNumber;
  final String interfaceType; // TCP, BT, USB
  final Map<String, dynamic>? additionalInfo;

  const DiscoveredPrinter({
    required this.address,
    required this.port,
    this.friendlyName,
    this.serialNumber,
    required this.interfaceType,
    this.additionalInfo,
  });

  factory DiscoveredPrinter.fromMap(Map<String, dynamic> map) {
    return DiscoveredPrinter(
      address: map['address'] ?? '',
      port: map['port'] ?? 9100,
      friendlyName: map['friendlyName'],
      serialNumber: map['serialNumber'],
      interfaceType: map['interfaceType'] ?? 'TCP',
      additionalInfo: map['additionalInfo']?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'port': port,
      'friendlyName': friendlyName,
      'serialNumber': serialNumber,
      'interfaceType': interfaceType,
      'additionalInfo': additionalInfo,
    };
  }

  @override
  String toString() {
    return 'DiscoveredPrinter(address: $address, port: $port, name: $friendlyName, type: $interfaceType)';
  }
}

/// Data models for zebra printer platform interface
class PrinterStatus {
  final bool isOnline;
  final String status;
  final String? errorMessage;
  final bool? paperPresent;  // Whether paper is present in the printer (for label printers with paper hold)

  const PrinterStatus({
    required this.isOnline,
    required this.status,
    this.errorMessage,
    this.paperPresent,
  });

  factory PrinterStatus.fromMap(Map<String, dynamic> map) {
    return PrinterStatus(
      isOnline: map['isOnline'] ?? false,
      status: map['status'] ?? 'unknown',
      errorMessage: map['errorMessage'],
      paperPresent: map['paperPresent'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOnline': isOnline,
      'status': status,
      'errorMessage': errorMessage,
      'paperPresent': paperPresent,
    };
  }
}

/// Connection settings for Zebra printers
class ZebraConnectionSettings {
  final ZebraInterfaceType interfaceType;
  final String identifier;
  final int? timeout;

  const ZebraConnectionSettings({
    required this.interfaceType,
    required this.identifier,
    this.timeout,
  });

  Map<String, dynamic> toMap() {
    return {
      'interfaceType': interfaceType.name,
      'identifier': identifier,
      'timeout': timeout,
    };
  }
}

/// Interface types supported by Zebra printers
enum ZebraInterfaceType {
  tcp,
  bluetooth,
  bluetoothLE,
  usb,
}

/// Print language enum for Zebra printers
enum ZebraPrintLanguage {
  zpl,  // Zebra Programming Language
  cpcl, // Common Printing Command Language
}

/// Print job configuration for Zebra printers
class PrintJob {
  final String content; // Raw ZPL or CPCL commands
  final ZebraPrintLanguage? language; // Language hint (auto-detected if null)
  final Map<String, dynamic>? settings;

  const PrintJob({
    required this.content,
    this.language,
    this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'language': language?.name,
      'settings': settings,
    };
  }
}
