#import "ZebraPrinterIosPlugin.h"
#import "NetworkDiscoverer.h"
#import "DiscoveredPrinter.h"
#import "DiscoveredPrinterNetwork.h"
#import "ZebraPrinterConnection.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterFactory.h"
#import "TcpPrinterConnection.h"
#import "MfiBtPrinterConnection.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

@implementation ZebraPrinterIosPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"zebra_printer"
            binaryMessenger:[registrar messenger]];
  ZebraPrinterIosPlugin* instance = [[ZebraPrinterIosPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"discoverPrinters" isEqualToString:call.method]) {
    [self discoverPrintersWithResult:result];
  } else if ([@"discoverMulticastPrinters" isEqualToString:call.method]) {
    [self discoverMulticastPrinters:call result:result];
  } else if ([@"discoverDirectedBroadcast" isEqualToString:call.method]) {
    [self discoverDirectedBroadcast:call result:result];
  } else if ([@"discoverSubnetSearch" isEqualToString:call.method]) {
    [self discoverSubnetSearch:call result:result];
  } else if ([@"discoverNetworkPrintersAuto" isEqualToString:call.method]) {
    [self discoverNetworkPrintersAuto:call result:result];
  } else if ([@"discoverBluetoothPrinters" isEqualToString:call.method]) {
    [self discoverBluetoothPrintersWithResult:result];
  } else if ([@"discoverUsbPrinters" isEqualToString:call.method]) {
    [self discoverUsbPrintersWithResult:result];
  } else if ([@"connect" isEqualToString:call.method]) {
    [self connect:call result:result];
  } else if ([@"disconnect" isEqualToString:call.method]) {
    [self disconnectWithResult:result];
  } else if ([@"printReceipt" isEqualToString:call.method]) {
    [self printReceipt:call result:result];
  } else if ([@"sendCommands" isEqualToString:call.method]) {
    [self sendCommands:call result:result];
  } else if ([@"getPrinterLanguage" isEqualToString:call.method]) {
    [self getPrinterLanguageWithResult:result];
  } else if ([@"getSgdParameter" isEqualToString:call.method]) {
    [self getSgdParameter:call result:result];
  } else if ([@"setSgdParameter" isEqualToString:call.method]) {
    [self setSgdParameter:call result:result];
  } else if ([@"getStatus" isEqualToString:call.method]) {
    [self getStatusWithResult:result];
  } else if ([@"isConnected" isEqualToString:call.method]) {
    [self isConnectedWithResult:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma mark - Discovery Methods

- (void)discoverPrintersWithResult:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] Starting local broadcast discovery...");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSError *error = nil;
    NSLog(@"[ZebraPrinter] Calling NetworkDiscoverer localBroadcast...");
    NSArray *printers = [NetworkDiscoverer localBroadcast:&error];
    NSLog(@"[ZebraPrinter] Discovery completed. Found %lu printers, error: %@", (unsigned long)[printers count], error);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (error) {
        NSLog(@"[ZebraPrinter] Discovery error: %@", error.localizedDescription);
        result([FlutterError errorWithCode:@"DISCOVERY_ERROR"
                                   message:error.localizedDescription
                                   details:nil]);
      } else {
        NSArray *discoveredPrinters = [self convertDiscoveredPrintersToArray:printers];
        NSLog(@"[ZebraPrinter] Returning %lu converted printers to Flutter", (unsigned long)[discoveredPrinters count]);
        result(discoveredPrinters);
      }
    });
  });
}

- (void)discoverMulticastPrinters:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] Starting multicast discovery...");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDictionary *args = call.arguments;
    NSLog(@"[ZebraPrinter] Multicast args: %@", args);
    
    // Safely extract parameters with proper null checking
    NSInteger hops = 3; // Default value
    NSInteger timeoutMs = -1; // Default timeout (uses SDK default)
    
    if (args && [args isKindOfClass:[NSDictionary class]]) {
      id hopsValue = args[@"hops"];
      if (hopsValue && ![hopsValue isKindOfClass:[NSNull class]]) {
        hops = [hopsValue integerValue];
      }
      
      id timeoutValue = args[@"timeoutMs"];
      if (timeoutValue && ![timeoutValue isKindOfClass:[NSNull class]]) {
        timeoutMs = [timeoutValue integerValue];
      }
    }
    
    NSLog(@"[ZebraPrinter] Using hops: %ld, timeout: %ld", (long)hops, (long)timeoutMs);
    
    NSError *error = nil;
    NSArray *printers;
    
    if (timeoutMs > 0) {
      NSLog(@"[ZebraPrinter] Calling multicastWithHops:andWaitForResponsesTimeout:error:");
      printers = [NetworkDiscoverer multicastWithHops:hops 
                           andWaitForResponsesTimeout:timeoutMs 
                                                error:&error];
    } else {
      NSLog(@"[ZebraPrinter] Calling multicastWithHops:error:");
      printers = [NetworkDiscoverer multicastWithHops:hops error:&error];
    }
    
    NSLog(@"[ZebraPrinter] Multicast discovery completed. Found %lu printers, error: %@", (unsigned long)[printers count], error);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (error) {
        NSLog(@"[ZebraPrinter] Multicast discovery error: %@", error.localizedDescription);
        result([FlutterError errorWithCode:@"DISCOVERY_ERROR"
                                   message:error.localizedDescription
                                   details:nil]);
      } else {
        NSArray *discoveredPrinters = [self convertDiscoveredPrintersToArray:printers];
        NSLog(@"[ZebraPrinter] Returning %lu multicast printers to Flutter", (unsigned long)[discoveredPrinters count]);
        result(discoveredPrinters);
      }
    });
  });
}

- (void)discoverDirectedBroadcast:(FlutterMethodCall*)call result:(FlutterResult)result {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDictionary *args = call.arguments;
    NSString *ipAddress = args[@"ipAddress"];
    NSNumber *timeoutMs = args[@"timeoutMs"];
    
    if (!ipAddress) {
      dispatch_async(dispatch_get_main_queue(), ^{
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                   message:@"IP address is required"
                                   details:nil]);
      });
      return;
    }
    
    NSError *error = nil;
    NSArray *printers;
    
    if (timeoutMs) {
      printers = [NetworkDiscoverer directedBroadcastWithIpAddress:ipAddress 
                                         andWaitForResponsesTimeout:[timeoutMs integerValue] 
                                                               error:&error];
    } else {
      printers = [NetworkDiscoverer directedBroadcastWithIpAddress:ipAddress error:&error];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (error) {
        result([FlutterError errorWithCode:@"DISCOVERY_ERROR"
                                   message:error.localizedDescription
                                   details:nil]);
      } else {
        NSArray *discoveredPrinters = [self convertDiscoveredPrintersToArray:printers];
        result(discoveredPrinters);
      }
    });
  });
}

- (void)discoverSubnetSearch:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] Starting subnet search discovery...");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDictionary *args = call.arguments;
    NSLog(@"[ZebraPrinter] Subnet search args: %@", args);
    
    NSString *subnetRange = nil;
    NSInteger timeoutMs = -1; // Default timeout (uses SDK default)
    
    if (args && [args isKindOfClass:[NSDictionary class]]) {
      id rangeValue = args[@"subnetRange"];
      if (rangeValue && ![rangeValue isKindOfClass:[NSNull class]]) {
        subnetRange = [rangeValue description];
      }
      
      id timeoutValue = args[@"timeoutMs"];
      if (timeoutValue && ![timeoutValue isKindOfClass:[NSNull class]]) {
        timeoutMs = [timeoutValue integerValue];
      }
    }
    
    if (!subnetRange || [subnetRange length] == 0) {
      NSLog(@"[ZebraPrinter] Subnet range is missing or empty");
      dispatch_async(dispatch_get_main_queue(), ^{
        result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                   message:@"Subnet range is required"
                                   details:nil]);
      });
      return;
    }
    
    NSLog(@"[ZebraPrinter] Using subnet range: %@, timeout: %ld", subnetRange, (long)timeoutMs);
    
    NSError *error = nil;
    NSArray *printers;
    
    if (timeoutMs > 0) {
      NSLog(@"[ZebraPrinter] Calling subnetSearchWithRange:andWaitForResponsesTimeout:error:");
      printers = [NetworkDiscoverer subnetSearchWithRange:subnetRange 
                                andWaitForResponsesTimeout:timeoutMs 
                                                     error:&error];
    } else {
      NSLog(@"[ZebraPrinter] Calling subnetSearchWithRange:error:");
      printers = [NetworkDiscoverer subnetSearchWithRange:subnetRange error:&error];
    }
    
    NSLog(@"[ZebraPrinter] Subnet search completed. Found %lu printers, error: %@", (unsigned long)[printers count], error);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (error) {
        NSLog(@"[ZebraPrinter] Subnet search error: %@", error.localizedDescription);
        result([FlutterError errorWithCode:@"DISCOVERY_ERROR"
                                   message:error.localizedDescription
                                   details:nil]);
      } else {
        NSArray *discoveredPrinters = [self convertDiscoveredPrintersToArray:printers];
        NSLog(@"[ZebraPrinter] Returning %lu subnet printers to Flutter", (unsigned long)[discoveredPrinters count]);
        result(discoveredPrinters);
      }
    });
  });
}

- (void)discoverBluetoothPrintersWithResult:(FlutterResult)result {
  // TODO: Implement Bluetooth discovery
  result(@[]);
}

- (void)discoverUsbPrintersWithResult:(FlutterResult)result {
  // TODO: Implement USB discovery  
  result(@[]);
}

#pragma mark - Helper Methods

- (NSArray *)convertDiscoveredPrintersToArray:(NSArray *)printers {
  NSLog(@"[ZebraPrinter] Converting %lu discovered printers to array format", (unsigned long)[printers count]);
  NSMutableArray *result = [[NSMutableArray alloc] init];
  
  for (DiscoveredPrinter *printer in printers) {
    NSMutableDictionary *printerDict = [[NSMutableDictionary alloc] init];
    
    // Basic address from DiscoveredPrinter
    printerDict[@"address"] = printer.address ?: @"";
    printerDict[@"interfaceType"] = @"TCP";
    
    // Additional properties if it's a DiscoveredPrinterNetwork
    if ([printer isKindOfClass:[DiscoveredPrinterNetwork class]]) {
      DiscoveredPrinterNetwork *networkPrinter = (DiscoveredPrinterNetwork *)printer;
      printerDict[@"port"] = @(networkPrinter.port);
      printerDict[@"friendlyName"] = networkPrinter.dnsName ?: @"";
      NSLog(@"[ZebraPrinter] Found network printer: %@ port:%ld name:%@", 
            printer.address, (long)networkPrinter.port, networkPrinter.dnsName);
    } else {
      printerDict[@"port"] = @(9100); // Default Zebra port
      printerDict[@"friendlyName"] = @"";
      NSLog(@"[ZebraPrinter] Found basic printer: %@", printer.address);
    }
    
    [result addObject:printerDict];
  }
  
  NSLog(@"[ZebraPrinter] Conversion complete, returning %lu printer dictionaries", (unsigned long)[result count]);
  return [result copy];
}

#pragma mark - Connection Methods (Stubs)

- (void)connect:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] connect called with args: %@", call.arguments);

  NSDictionary *args = call.arguments;
  if (!args || ![args isKindOfClass:[NSDictionary class]]) {
    result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"Invalid connect arguments" details:nil]);
    return;
  }

  NSString *interfaceType = args[@"interfaceType"];
  NSString *identifier = args[@"identifier"];
  NSNumber *timeout = args[@"timeout"];

  if (!interfaceType || !identifier) {
    result([FlutterError errorWithCode:@"INVALID_ARGUMENT" message:@"interfaceType and identifier are required" details:nil]);
    return;
  }

  // Only implement TCP connect for now
  if ([[interfaceType lowercaseString] isEqualToString:@"tcp"]) {
    // Default port 9100 unless the identifier supplies one (not currently supported)
    NSInteger port = 9100;

    @try {
      TcpPrinterConnection *conn = [[TcpPrinterConnection alloc] initWithAddress:identifier andWithPort:port];

      // If the caller supplied a timeout, use it for open
      if (timeout && ![timeout isKindOfClass:[NSNull class]] && [timeout integerValue] > 0) {
        // TcpPrinterConnection exposes setMaxTimeoutForOpen: (int)
        [conn setMaxTimeoutForOpen:[timeout intValue]];
      }

      BOOL opened = [conn open];
      if (!opened) {
        NSLog(@"[ZebraPrinter] TCP open failed for %@:%ld", identifier, (long)port);
        result([FlutterError errorWithCode:@"CONNECTION_FAILED" message:@"Failed to open TCP connection" details:nil]);
        return;
      }

      // Save active connection
      self.activeConnection = conn;
      NSLog(@"[ZebraPrinter] Connected to %@:%ld successfully", identifier, (long)port);

      // Comment out auto-print on connection - moved to Print Receipt/Label buttons
      /*
      // Send a simple test print to verify the connection works
      NSString *testZpl = @"^XA^FO20,20^A0N,25,25^FDZebra Flutter Test Print^FS^FO20,60^A0N,20,20^FDConnection Success!^FS^XZ";
      NSError *printError = nil;
      NSData *zplData = [testZpl dataUsingEncoding:NSUTF8StringEncoding];
      
      NSInteger bytesWritten = [conn write:zplData error:&printError];
      if (printError || bytesWritten <= 0) {
        NSLog(@"[ZebraPrinter] Test print failed: %@ (bytes written: %ld)", printError.localizedDescription, (long)bytesWritten);
        // Don't fail the connection for print errors, just log them
      } else {
        NSLog(@"[ZebraPrinter] Test print sent successfully (%ld bytes)", (long)bytesWritten);
      }
      */

      // Return success (void)
      result(nil);
      return;
    } @catch (NSException *ex) {
      NSLog(@"[ZebraPrinter] Exception while connecting: %@", ex);
      result([FlutterError errorWithCode:@"CONNECTION_EXCEPTION" message:ex.reason details:nil]);
      return;
    }
  } else {
    // Unsupported interface type at present
    result([FlutterError errorWithCode:@"UNSUPPORTED_INTERFACE" message:@"Only TCP connect is implemented on iOS plugin" details:nil]);
    return;
  }
}

- (void)disconnectWithResult:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] disconnect called");
  if (self.activeConnection) {
    @try {
      [self.activeConnection close];
    } @catch (NSException *ex) {
      NSLog(@"[ZebraPrinter] Exception while closing connection: %@", ex);
    }
    self.activeConnection = nil;
    result(nil);
  } else {
    // Nothing to disconnect
    result(nil);
  }
}

#pragma mark - Printing Methods (Stubs)

- (void)printReceipt:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] printReceipt called");
  
  if (!self.activeConnection || ![self.activeConnection isConnected]) {
    result([FlutterError errorWithCode:@"NOT_CONNECTED"
                             message:@"Printer not connected"
                             details:nil]);
    return;
  }

  @try {
    // Send a test receipt print (ZPL format)
    NSString *receiptZpl = @"^XA^FO20,20^A0N,25,25^FDReceipt Test Print^FS^FO20,60^A0N,20,20^FDItem: Test Product^FS^FO20,90^A0N,20,20^FDPrice: $12.34^FS^FO20,120^A0N,20,20^FD================^FS^FO20,150^A0N,20,20^FDTotal: $12.34^FS^XZ";
    
    NSError *error = nil;
    NSData *zplData = [receiptZpl dataUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger bytesWritten = [self.activeConnection write:zplData error:&error];
    
    if (error || bytesWritten <= 0) {
      NSLog(@"[ZebraPrinter] Receipt print failed: %@ (bytes written: %ld)", error.localizedDescription, (long)bytesWritten);
      result([FlutterError errorWithCode:@"PRINT_ERROR"
                               message:error.localizedDescription ?: @"Failed to send data to printer"
                               details:nil]);
    } else {
      NSLog(@"[ZebraPrinter] Receipt printed successfully (%ld bytes)", (long)bytesWritten);
      result(nil);
    }
  } @catch (NSException *ex) {
    NSLog(@"[ZebraPrinter] Exception while printing receipt: %@", ex);
    result([FlutterError errorWithCode:@"PRINT_EXCEPTION"
                             message:ex.reason
                             details:nil]);
  }
}

- (void)sendCommands:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] sendCommands called");
  
  if (!self.activeConnection || ![self.activeConnection isConnected]) {
    result([FlutterError errorWithCode:@"NOT_CONNECTED"
                             message:@"Printer not connected"
                             details:nil]);
    return;
  }

  NSDictionary *args = call.arguments;
  NSString *commands = args[@"commands"];
  NSString *language = args[@"language"];
  
  // If no commands provided, use a test label
  if (!commands || [commands length] == 0) {
    commands = @"^XA\n^CF0,27\n^FO104,150\n^FD^FS\n^BY3,3,111\n^FO140,226^BCN^FD8884959395020^FS\n^CF0,47\n^FO168,14\n^FDT-Shirt^FS\n^CF0,46\n^FO180,58\n^FD$5.00^FS\n^CF0,30\n^FO138,106\n^FDSmall Turquoise^FS\n^BY2,3,50\n^FO110,144^BCN^FD123456789^FS\n^XZ";
    NSLog(@"[ZebraPrinter] No commands provided, using T-Shirt barcode label");
  }

  @try {
    NSError *error = nil;
    NSData *commandData = [commands dataUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger bytesWritten = [self.activeConnection write:commandData error:&error];
    
    if (error || bytesWritten <= 0) {
      NSLog(@"[ZebraPrinter] Send commands failed: %@ (bytes written: %ld)", error.localizedDescription, (long)bytesWritten);
      result([FlutterError errorWithCode:@"PRINT_ERROR"
                               message:error.localizedDescription ?: @"Failed to send commands to printer"
                               details:nil]);
    } else {
      NSLog(@"[ZebraPrinter] Commands sent successfully (%ld bytes), language: %@", (long)bytesWritten, language ?: @"auto");
      result(nil);
    }
  } @catch (NSException *ex) {
    NSLog(@"[ZebraPrinter] Exception while sending commands: %@", ex);
    result([FlutterError errorWithCode:@"PRINT_EXCEPTION"
                             message:ex.reason
                             details:nil]);
  }
}

#pragma mark - Status Methods (Stubs)

- (void)getPrinterLanguageWithResult:(FlutterResult)result {
  // TODO: Implement get printer language
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"getPrinterLanguage not yet implemented"
                             details:nil]);
}

- (void)getSgdParameter:(FlutterMethodCall*)call result:(FlutterResult)result {
  // TODO: Implement get SGD parameter
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"getSgdParameter not yet implemented"
                             details:nil]);
}

- (void)setSgdParameter:(FlutterMethodCall*)call result:(FlutterResult)result {
  // TODO: Implement set SGD parameter
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"setSgdParameter not yet implemented"
                             details:nil]);
}

- (void)getStatusWithResult:(FlutterResult)result {
  // TODO: Implement get status
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"getStatus not yet implemented"
                             details:nil]);
}

- (void)isConnectedWithResult:(FlutterResult)result {
  BOOL connected = NO;
  if (self.activeConnection) {
    @try {
      connected = [self.activeConnection isConnected];
    } @catch (NSException *ex) {
      connected = NO;
    }
  }
  result(@(connected));
}

- (void)discoverNetworkPrintersAuto:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[ZebraPrinter] Starting automatic network discovery...");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDictionary *args = call.arguments;
    NSInteger timeoutMs = -1; // Default timeout
    
    if (args && [args isKindOfClass:[NSDictionary class]]) {
      id timeoutValue = args[@"timeoutMs"];
      if (timeoutValue && ![timeoutValue isKindOfClass:[NSNull class]]) {
        timeoutMs = [timeoutValue integerValue];
      }
    }
    
    NSLog(@"[ZebraPrinter] Auto discovery timeout: %ld", (long)timeoutMs);
    
    // Get device's current network interfaces
    NSArray *subnets = [self getLocalNetworkSubnets];
    NSLog(@"[ZebraPrinter] Detected %lu local network subnets: %@", (unsigned long)[subnets count], subnets);
    
    NSMutableArray *allPrinters = [NSMutableArray array];
    NSError *lastError = nil;
    
    // Search each detected subnet
    for (NSString *subnet in subnets) {
      NSLog(@"[ZebraPrinter] Searching subnet: %@", subnet);
      NSError *error = nil;
      NSArray *printers;
      
      if (timeoutMs > 0) {
        printers = [NetworkDiscoverer subnetSearchWithRange:subnet 
                                  andWaitForResponsesTimeout:timeoutMs 
                                                       error:&error];
      } else {
        printers = [NetworkDiscoverer subnetSearchWithRange:subnet error:&error];
      }
      
      if (error) {
        NSLog(@"[ZebraPrinter] Error searching subnet %@: %@", subnet, error.localizedDescription);
        lastError = error;
      } else {
        NSLog(@"[ZebraPrinter] Found %lu printers in subnet %@", (unsigned long)[printers count], subnet);
        [allPrinters addObjectsFromArray:printers];
      }
    }
    
    NSLog(@"[ZebraPrinter] Auto discovery completed. Total found: %lu printers", (unsigned long)[allPrinters count]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([allPrinters count] == 0 && lastError) {
        result([FlutterError errorWithCode:@"DISCOVERY_ERROR"
                                   message:lastError.localizedDescription
                                   details:nil]);
      } else {
        NSArray *discoveredPrinters = [self convertDiscoveredPrintersToArray:allPrinters];
        NSLog(@"[ZebraPrinter] Returning %lu auto-discovered printers to Flutter", (unsigned long)[discoveredPrinters count]);
        result(discoveredPrinters);
      }
    });
  });
}

- (NSArray *)getLocalNetworkSubnets {
  NSMutableArray *subnets = [NSMutableArray array];
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  
  // Get list of all network interfaces
  if (getifaddrs(&interfaces) == 0) {
    temp_addr = interfaces;
    
    while(temp_addr != NULL) {
      if(temp_addr->ifa_addr->sa_family == AF_INET) {
        // Check if interface is up and not loopback
        if((temp_addr->ifa_flags & IFF_UP) && !(temp_addr->ifa_flags & IFF_LOOPBACK)) {
          // Get IP address
          struct sockaddr_in* addr = (struct sockaddr_in*)temp_addr->ifa_addr;
          struct sockaddr_in* netmask = (struct sockaddr_in*)temp_addr->ifa_netmask;
          
          if (addr && netmask) {
            uint32_t ip = ntohl(addr->sin_addr.s_addr);
            uint32_t mask = ntohl(netmask->sin_addr.s_addr);
            uint32_t network = ip & mask;
            
            // Common subnet masks for local networks
            if (mask == 0xFFFFFF00) { // 255.255.255.0 (/24)
              NSString *subnet = [NSString stringWithFormat:@"%d.%d.%d.*", 
                                  (int)((network >> 24) & 0xFF),
                                  (int)((network >> 16) & 0xFF), 
                                  (int)((network >> 8) & 0xFF)];
              
              if (![subnets containsObject:subnet]) {
                NSLog(@"[ZebraPrinter] Found local subnet: %@ (interface: %s)", subnet, temp_addr->ifa_name);
                [subnets addObject:subnet];
              }
            }
          }
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }
  
  if (interfaces) freeifaddrs(interfaces);
  
  // If no subnets detected, add common private network ranges
  if ([subnets count] == 0) {
    NSLog(@"[ZebraPrinter] No local subnets detected, using common ranges");
    [subnets addObjectsFromArray:@[@"192.168.1.*", @"192.168.0.*", @"10.0.1.*", @"10.0.0.*"]];
  }
  
  return [subnets copy];
}

@end