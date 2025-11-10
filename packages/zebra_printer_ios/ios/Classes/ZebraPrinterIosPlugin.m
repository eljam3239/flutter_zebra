#import "ZebraPrinterIosPlugin.h"
#import "NetworkDiscoverer.h"
#import "DiscoveredPrinter.h"
#import "DiscoveredPrinterNetwork.h"
#import "ZebraPrinterConnection.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterFactory.h"
#import "TcpPrinterConnection.h"
#import "MfiBtPrinterConnection.h"

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
  // TODO: Implement connection
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"connect not yet implemented"
                             details:nil]);
}

- (void)disconnectWithResult:(FlutterResult)result {
  // TODO: Implement disconnect
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"disconnect not yet implemented"
                             details:nil]);
}

#pragma mark - Printing Methods (Stubs)

- (void)printReceipt:(FlutterMethodCall*)call result:(FlutterResult)result {
  // TODO: Implement print receipt
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"printReceipt not yet implemented"
                             details:nil]);
}

- (void)sendCommands:(FlutterMethodCall*)call result:(FlutterResult)result {
  // TODO: Implement send commands
  result([FlutterError errorWithCode:@"UNIMPLEMENTED"
                             message:@"sendCommands not yet implemented"
                             details:nil]);
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
  // TODO: Implement is connected check
  result(@NO);
}

@end