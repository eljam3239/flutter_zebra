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

/// Interface types supported by Star printers
enum ZebraInterfaceType {
  bluetooth,
  bluetoothLE,
  lan,
  usb,
}

/// Print job configuration
class PrintJob {
  final String content;
  final Map<String, dynamic>? settings;

  const PrintJob({
    required this.content,
    this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'settings': settings,
    };
  }
}
