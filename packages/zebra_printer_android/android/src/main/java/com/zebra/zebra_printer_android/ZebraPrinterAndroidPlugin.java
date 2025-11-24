package com.zebra.zebra_printer_android;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.zebra.sdk.comm.Connection;
import com.zebra.sdk.comm.TcpConnection;
import com.zebra.sdk.btleComm.BluetoothLeConnection;
import com.zebra.sdk.btleComm.BluetoothLeDiscoverer;
import com.zebra.sdk.btleComm.DiscoveredPrinterBluetoothLe;
import com.zebra.sdk.printer.discovery.DiscoveredPrinter;
import com.zebra.sdk.printer.discovery.DiscoveredPrinterNetwork;
import com.zebra.sdk.printer.discovery.DiscoveryHandler;
import com.zebra.sdk.printer.discovery.DiscoveryException;
import com.zebra.sdk.printer.discovery.NetworkDiscoverer;
import com.zebra.sdk.printer.discovery.UsbDiscoverer;
import com.zebra.sdk.printer.discovery.DiscoveredPrinterUsb;
import com.zebra.sdk.printer.ZebraPrinter;
import com.zebra.sdk.printer.ZebraPrinterFactory;
import com.zebra.sdk.printer.ZebraPrinterLanguageUnknownException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** ZebraPrinterAndroidPlugin */
public class ZebraPrinterAndroidPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static final String TAG = "ZebraPrinterAndroid";
    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private Connection activeConnection;
    private ZebraPrinter zebraPrinter;
    private ExecutorService executor = Executors.newCachedThreadPool();
    private Handler mainHandler = new Handler(Looper.getMainLooper());

    // Helper method to get printer address based on type
    private String getPrinterAddress(DiscoveredPrinter printer) {
        if (printer instanceof DiscoveredPrinterNetwork) {
            return ((DiscoveredPrinterNetwork) printer).address;
        } else {
            return printer.toString();
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "zebra_printer");
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "discoverPrinters":
                discoverPrinters(call, result);
                break;
            case "discoverNetworkPrintersAuto":
                discoverNetworkPrintersAuto(call, result);
                break;
            case "discoverMulticastPrinters":
                discoverMulticastPrinters(call, result);
                break;
            case "discoverSubnetSearch":
                discoverSubnetSearch(call, result);
                break;
            case "discoverBluetoothPrinters":
                discoverBluetoothPrinters(call, result);
                break;
            case "discoverBluetoothNative":
                discoverBluetoothNative(call, result);
                break;
            case "testDirectBleConnection":
                testDirectBleConnection(call, result);
                break;
            case "discoverUsbPrinters":
                discoverUsbPrinters(call, result);
                break;
            case "requestBluetoothPermissions":
                requestBluetoothPermissions(result);
                break;
            case "connect":
                connect(call, result);
                break;
            case "disconnect":
                disconnect(result);
                break;
            case "sendCommands":
                sendCommands(call, result);
                break;
            case "isConnected":
                isConnected(result);
                break;
            case "getActiveConnection":
                getActiveConnection(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void discoverNetworkPrintersAuto(MethodCall call, Result result) {
        executor.execute(() -> {
            try {
                Log.d(TAG, "Starting auto network discovery using findPrinters");
                
                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
                final Object discoveryLock = new Object();
                final boolean[] discoveryComplete = {false};
                
                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter printer) {
                        synchronized (discoveredPrinters) {
                            // Check for duplicates based on address
                            boolean duplicate = false;
                            for (DiscoveredPrinter existing : discoveredPrinters) {
                                if (getPrinterAddress(existing).equals(getPrinterAddress(printer))) {
                                    duplicate = true;
                                    break;
                                }
                            }
                            if (!duplicate) {
                                discoveredPrinters.add(printer);
                                Log.d(TAG, "Found printer: " + getPrinterAddress(printer));
                            }
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "Auto discovery finished");
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }

                    @Override
                    public void discoveryError(String error) {
                        Log.e(TAG, "Auto discovery error: " + error);
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }
                };
                
                // Use findPrinters which combines multiple discovery methods
                WifiManager wifi = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
                WifiManager.MulticastLock lock = wifi.createMulticastLock("zebra_discovery_lock");
                lock.setReferenceCounted(true);
                lock.acquire();
                
                try {
                    NetworkDiscoverer.findPrinters(discoveryHandler);
                    
                    // Wait for discovery to complete
                    synchronized (discoveryLock) {
                        while (!discoveryComplete[0]) {
                            discoveryLock.wait(15000); // 15 second timeout for comprehensive search
                            break; // Exit if timeout
                        }
                    }
                } finally {
                    lock.release();
                }

                List<Map<String, Object>> printers = new ArrayList<>();
                synchronized (discoveredPrinters) {
                    for (DiscoveredPrinter printer : discoveredPrinters) {
                        Map<String, Object> printerMap = new HashMap<>();
                        printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                        printerMap.put("address", getPrinterAddress(printer));
                        printerMap.put("port", 9100);
                        printerMap.put("interfaceType", "TCP");
                        printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                        printerMap.put("additionalInfo", printer.getDiscoveryDataMap());
                        printers.add(printerMap);
                    }
                }

                mainHandler.post(() -> {
                    Log.d(TAG, "Auto network discovery completed. Found " + printers.size() + " printers");
                    result.success(printers);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Auto network discovery failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void connect(MethodCall call, Result result) {
        @SuppressWarnings("unchecked")
        Map<String, Object> settings = (Map<String, Object>) call.arguments;
        if (settings == null) {
            result.error("MISSING_ARGUMENT", "Connection settings are required", null);
            return;
        }

        String interfaceType = (String) settings.get("interfaceType");
        String identifier = (String) settings.get("identifier");
        Integer timeout = (Integer) settings.get("timeout");
        
        if (interfaceType == null || identifier == null) {
            result.error("MISSING_ARGUMENT", "interfaceType and identifier are required", null);
            return;
        }

        // Support both TCP and Bluetooth connections
        if (!"tcp".equalsIgnoreCase(interfaceType) && !"bluetooth".equalsIgnoreCase(interfaceType)) {
            result.error("UNSUPPORTED_INTERFACE", "Only TCP and Bluetooth interfaces are currently supported", null);
            return;
        }

        executor.execute(() -> {
            try {
                Log.d(TAG, "Connecting to " + interfaceType + " printer at " + identifier);
                
                // Close existing connection if any
                if (activeConnection != null && activeConnection.isConnected()) {
                    activeConnection.close();
                }

                // Create connection based on interface type
                if ("tcp".equalsIgnoreCase(interfaceType)) {
                    // Parse IP address and port from identifier
                    String ipAddress;
                    int port = 9100; // Default Zebra port
                    
                    if (identifier.contains(":")) {
                        String[] parts = identifier.split(":");
                        ipAddress = parts[0];
                        try {
                            port = Integer.parseInt(parts[1]);
                        } catch (NumberFormatException e) {
                            // Keep default port if parsing fails
                        }
                    } else {
                        ipAddress = identifier;
                    }
                    
                    activeConnection = new TcpConnection(ipAddress, port);
                } else if ("bluetooth".equalsIgnoreCase(interfaceType)) {
                    // Create Bluetooth LE connection using MAC address
                    activeConnection = new BluetoothLeConnection(identifier);
                    
                    // Set context for BLE connection (required by Zebra SDK)
                    if (activeConnection instanceof BluetoothLeConnection) {
                        ((BluetoothLeConnection) activeConnection).setContext(activity);
                    }
                }
                
                if (activeConnection == null) {
                    throw new Exception("Failed to create connection for interface type: " + interfaceType);
                }
                
                activeConnection.open();
                
                // Create ZebraPrinter instance
                zebraPrinter = ZebraPrinterFactory.getInstance(activeConnection);

                mainHandler.post(() -> {
                    Log.d(TAG, "Successfully connected to printer");
                    result.success(true);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Connection failed", e);
                mainHandler.post(() -> {
                    result.error("CONNECTION_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void disconnect(Result result) {
        executor.execute(() -> {
            try {
                if (activeConnection != null && activeConnection.isConnected()) {
                    activeConnection.close();
                    Log.d(TAG, "Disconnected from printer");
                }
                activeConnection = null;
                zebraPrinter = null;

                mainHandler.post(() -> {
                    result.success(true);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Disconnect failed", e);
                mainHandler.post(() -> {
                    result.error("DISCONNECT_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void sendCommands(MethodCall call, Result result) {
        String commands = call.argument("commands");
        if (commands == null) {
            result.error("MISSING_ARGUMENT", "Commands are required", null);
            return;
        }

        if (activeConnection == null || !activeConnection.isConnected()) {
            result.error("NOT_CONNECTED", "No active printer connection", null);
            return;
        }

        executor.execute(() -> {
            try {
                Log.d(TAG, "Sending commands to printer: " + commands);
                
                // Send raw ZPL commands
                activeConnection.write(commands.getBytes());

                mainHandler.post(() -> {
                    Log.d(TAG, "Commands sent successfully");
                    result.success(true);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Failed to send commands", e);
                mainHandler.post(() -> {
                    result.error("SEND_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void getActiveConnection(Result result) {
        if (activeConnection != null && activeConnection.isConnected()) {
            Map<String, Object> connectionInfo = new HashMap<>();
            connectionInfo.put("isConnected", true);
            connectionInfo.put("type", "TCP");
            result.success(connectionInfo);
        } else {
            result.success(null);
        }
    }

    private void discoverBluetoothPrinters(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity context is required for Bluetooth discovery", null);
            return;
        }

        // Check for required permissions
        if (!hasBluetoothPermissions()) {
            result.error("MISSING_PERMISSIONS", 
                "Bluetooth permissions are required. Please grant BLUETOOTH_SCAN and location permissions.", 
                null);
            return;
        }

        executor.execute(() -> {
            // Only prepare looper if one doesn't already exist
            final boolean looperPrepared;
            if (Looper.myLooper() == null) {
                Looper.prepare();
                looperPrepared = true;
            } else {
                looperPrepared = false;
            }
            
            try {
                Log.d(TAG, "Starting Bluetooth LE discovery...");
                
                // Increase SDK discovery timeout to 30 seconds to give slow-advertising devices time to appear
                try {
                    BluetoothLeDiscoverer.setDiscoveryTimeoutInterval(30000);
                } catch (Exception e) {
                    Log.w(TAG, "Failed to set BTLE discovery timeout: " + e.getMessage());
                }

                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();

                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter discoveredPrinter) {
                        Map<String, String> discoveryData = discoveredPrinter.getDiscoveryDataMap();
                        Log.d(TAG, "Found Bluetooth printer!");
                        Log.d(TAG, "  Printer type: " + discoveredPrinter.getClass().getSimpleName());
                        
                        // Check if this is specifically a BLE printer
                        if (discoveredPrinter instanceof DiscoveredPrinterBluetoothLe) {
                            DiscoveredPrinterBluetoothLe blePrinter = (DiscoveredPrinterBluetoothLe) discoveredPrinter;
                            Log.d(TAG, "  BLE Address: " + blePrinter.address);
                            Log.d(TAG, "  BLE Friendly Name: " + blePrinter.friendlyName);
                        }
                        
                        Log.d(TAG, "  FRIENDLY_NAME: " + discoveryData.get("FRIENDLY_NAME"));
                        Log.d(TAG, "  ADDRESS: " + discoveryData.get("ADDRESS"));
                        Log.d(TAG, "  MODEL: " + discoveryData.get("MODEL"));
                        Log.d(TAG, "  SERIAL_NUMBER: " + discoveryData.get("SERIAL_NUMBER"));
                        Log.d(TAG, "  All discovery data: " + discoveryData.toString());

                        synchronized (discoveredPrinters) {
                            discoveredPrinters.add(discoveredPrinter);
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "Bluetooth discovery finished callback received");

                        List<Map<String, Object>> printers = new ArrayList<>();
                        synchronized (discoveredPrinters) {
                            for (DiscoveredPrinter printer : discoveredPrinters) {
                                Map<String, Object> printerMap = new HashMap<>();
                                
                                // Handle BLE printers specifically
                                if (printer instanceof DiscoveredPrinterBluetoothLe) {
                                    DiscoveredPrinterBluetoothLe blePrinter = (DiscoveredPrinterBluetoothLe) printer;
                                    printerMap.put("friendlyName", blePrinter.friendlyName);
                                    printerMap.put("address", blePrinter.address);
                                    printerMap.put("interfaceType", "bluetooth_le");
                                } else {
                                    // Fallback to discovery data
                                    printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                                    String btAddress = printer.getDiscoveryDataMap().get("ADDRESS");
                                    printerMap.put("address", btAddress != null ? btAddress : "Unknown");
                                    printerMap.put("interfaceType", "bluetooth");
                                }
                                
                                printerMap.put("port", "0");
                                printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                                printers.add(printerMap);
                            }
                        }

                        mainHandler.post(() -> {
                            Log.d(TAG, "Bluetooth discovery completed. Found " + printers.size() + " printers");
                            result.success(printers);
                        });
                    }

                    @Override
                    public void discoveryError(String message) {
                        Log.e(TAG, "Bluetooth discovery error callback: " + message);
                        mainHandler.post(() -> {
                            result.error("DISCOVERY_FAILED", message, null);
                        });
                    }
                };

                Log.d(TAG, "Starting BluetoothLeDiscoverer.findPrinters with context only (demo pattern)...");
                // Use 2-parameter method like in the demo - context and handler only
                BluetoothLeDiscoverer.findPrinters(activity, discoveryHandler);
                
            } catch (Exception e) {
                Log.e(TAG, "Bluetooth discovery failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            } finally {
                // Only quit looper if we prepared it
                if (looperPrepared) {
                    try {
                        Looper.myLooper().quit(); // Clean up looper
                    } catch (Exception e) {
                        Log.w(TAG, "Error quitting looper", e);
                    }
                }
            }
        });
    }

    private void discoverBluetoothNative(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity context is required for Bluetooth discovery", null);
            return;
        }

        // Check for required permissions
        if (!hasBluetoothPermissions()) {
            result.error("MISSING_PERMISSIONS", 
                "Bluetooth permissions are required. Please grant BLUETOOTH_SCAN and location permissions.", 
                null);
            return;
        }

        BluetoothManager bluetoothManager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager == null) {
            result.error("NO_BLUETOOTH", "Bluetooth is not available on this device", null);
            return;
        }

        BluetoothAdapter bluetoothAdapter = bluetoothManager.getAdapter();
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled()) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null);
            return;
        }

        BluetoothLeScanner scanner = bluetoothAdapter.getBluetoothLeScanner();
        if (scanner == null) {
            result.error("NO_LE_SCANNER", "Bluetooth LE scanner not available", null);
            return;
        }
        
        Log.d(TAG, "Bluetooth adapter state: " + bluetoothAdapter.getState());
        Log.d(TAG, "Bluetooth adapter name: " + bluetoothAdapter.getName());
        Log.d(TAG, "BLE scanner available: " + (scanner != null));

        final List<Map<String, Object>> foundDevices = new ArrayList<>();
        final Handler timeoutHandler = new Handler(Looper.getMainLooper());

        ScanCallback scanCallback = new ScanCallback() {
            @Override
            public void onScanResult(int callbackType, ScanResult scanResult) {
                BluetoothDevice device = scanResult.getDevice();
                String deviceName = device.getName();
                String deviceAddress = device.getAddress();
                int rssi = scanResult.getRssi();
                
                // Log ALL devices for debugging
                Log.d(TAG, "Native BLE scan found device:");
                Log.d(TAG, "  Name: " + (deviceName != null ? deviceName : "Unknown"));
                Log.d(TAG, "  Address: " + deviceAddress);
                Log.d(TAG, "  RSSI: " + rssi);
                Log.d(TAG, "  Type: " + device.getType());
                Log.d(TAG, "  Bond State: " + device.getBondState());

                // Look for Zebra devices or devices with "ZD" in the name
                boolean isZebraDevice = (deviceName != null && 
                    (deviceName.toLowerCase().contains("zebra") || 
                     deviceName.toLowerCase().contains("zd") ||
                     deviceName.toLowerCase().contains("zq") ||
                     deviceName.toLowerCase().contains("zt")));

                // ADD ALL DEVICES for debugging - don't filter anything yet
                Map<String, Object> deviceMap = new HashMap<>();
                deviceMap.put("friendlyName", deviceName != null ? deviceName : "Unknown Device");
                deviceMap.put("address", deviceAddress);
                deviceMap.put("rssi", rssi);
                deviceMap.put("port", "0");
                deviceMap.put("interfaceType", "bluetooth");
                deviceMap.put("isZebra", isZebraDevice);
                deviceMap.put("serialNumber", "Unknown");
                deviceMap.put("deviceType", device.getType());
                deviceMap.put("bondState", device.getBondState());
                
                synchronized (foundDevices) {
                    // Avoid duplicates
                    boolean isDuplicate = false;
                        for (Map<String, Object> existing : foundDevices) {
                            if (deviceAddress.equals(existing.get("address"))) {
                                isDuplicate = true;
                                break;
                            }
                        }
                        if (!isDuplicate) {
                            foundDevices.add(deviceMap);
                            Log.d(TAG, "Added device to list: " + deviceName + " (Zebra: " + isZebraDevice + ")");
                        }
                    }
            }

            @Override
            public void onScanFailed(int errorCode) {
                Log.e(TAG, "Native BLE scan failed with error code: " + errorCode);
                mainHandler.post(() -> {
                    result.error("SCAN_FAILED", "Native BLE scan failed with error code: " + errorCode, null);
                });
            }
        };

        Log.d(TAG, "Starting native Android BLE scan for 15 seconds...");
        
        try {
            // Use aggressive scan settings
            ScanSettings.Builder settingsBuilder = new ScanSettings.Builder();
            settingsBuilder.setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY); // Most aggressive
            settingsBuilder.setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES);
            
            // Use empty filter list to scan for ALL devices
            List<ScanFilter> filters = new ArrayList<>();
            
            scanner.startScan(filters, settingsBuilder.build(), scanCallback);
            
            // Stop scanning after 15 seconds and return results
            timeoutHandler.postDelayed(() -> {
                try {
                    scanner.stopScan(scanCallback);
                } catch (Exception e) {
                    Log.w(TAG, "Error stopping native BLE scan", e);
                }
                
                synchronized (foundDevices) {
                    Log.d(TAG, "Native BLE scan completed. Found " + foundDevices.size() + " devices");
                    result.success(new ArrayList<>(foundDevices));
                }
            }, 15000);
            
        } catch (SecurityException e) {
            Log.e(TAG, "SecurityException during native BLE scan", e);
            result.error("PERMISSION_DENIED", "Permission denied for BLE scan: " + e.getMessage(), null);
        } catch (Exception e) {
            Log.e(TAG, "Exception during native BLE scan", e);
            result.error("SCAN_ERROR", "Error during BLE scan: " + e.getMessage(), null);
        }
    }

    private void testDirectBleConnection(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity context is required for BLE connection", null);
            return;
        }

        // Check for required permissions
        if (!hasBluetoothPermissions()) {
            result.error("MISSING_PERMISSIONS", 
                "Bluetooth permissions are required. Please grant BLUETOOTH_SCAN and location permissions.", 
                null);
            return;
        }

        // Get MAC address from call parameters or use ZD421 default
        String macAddress = call.hasArgument("macAddress") ? 
            (String) call.argument("macAddress") : "B0:B1:13:79:2A:6A";
        
        Log.d(TAG, "Testing direct BLE connection to: " + macAddress);

        executor.execute(() -> {
            BluetoothLeConnection bleConnection = null;
            ZebraPrinter printer = null;
            
            try {
                Log.d(TAG, "Creating BluetoothLeConnection for MAC: " + macAddress);
                bleConnection = new BluetoothLeConnection(macAddress);
                
                Log.d(TAG, "Setting context for BLE connection...");
                bleConnection.setContext(activity);
                
                Log.d(TAG, "Attempting to open BLE connection...");
                bleConnection.open();
                
                if (bleConnection.isConnected()) {
                    Log.d(TAG, "BLE connection successful! Testing printer communication...");
                    
                    // Try to create a printer instance
                    printer = ZebraPrinterFactory.getInstance(bleConnection);
                    
                    if (printer != null) {
                        Log.d(TAG, "Successfully created ZebraPrinter instance via BLE!");
                        
                        // Try to get printer status
                        try {
                            String status = printer.getCurrentStatus().toString();
                            Log.d(TAG, "Printer status via BLE: " + status);
                            
                            // Create success result with printer info
                            Map<String, Object> printerInfo = new HashMap<>();
                            printerInfo.put("friendlyName", "ZD421 (Direct BLE)");
                            printerInfo.put("address", macAddress);
                            printerInfo.put("port", 0); // Use integer 0, not string "0"
                            printerInfo.put("interfaceType", "bluetooth"); // Use "bluetooth" to match connect() method
                            printerInfo.put("status", status);
                            printerInfo.put("serialNumber", "Unknown");
                            
                            List<Map<String, Object>> printers = new ArrayList<>();
                            printers.add(printerInfo);
                            
                            mainHandler.post(() -> {
                                result.success(printers);
                            });
                            
                        } catch (Exception statusEx) {
                            Log.w(TAG, "Could not get printer status via BLE", statusEx);
                            
                            // Still report success since connection worked
                            Map<String, Object> printerInfo = new HashMap<>();
                            printerInfo.put("friendlyName", "ZD421 (Direct BLE - Limited)");
                            printerInfo.put("address", macAddress);
                            printerInfo.put("port", 0); // Use integer 0, not string "0"
                            printerInfo.put("interfaceType", "bluetooth"); // Use "bluetooth" to match connect() method
                            printerInfo.put("status", "Connected but status unavailable");
                            printerInfo.put("serialNumber", "Unknown");
                            
                            List<Map<String, Object>> printers = new ArrayList<>();
                            printers.add(printerInfo);
                            
                            mainHandler.post(() -> {
                                result.success(printers);
                            });
                        }
                    } else {
                        Log.w(TAG, "BLE connection successful but could not create printer instance");
                        mainHandler.post(() -> {
                            result.error("PRINTER_CREATION_FAILED", 
                                "Connected via BLE but could not create printer instance", null);
                        });
                    }
                } else {
                    Log.w(TAG, "BLE connection failed - not connected after open()");
                    mainHandler.post(() -> {
                        result.error("CONNECTION_FAILED", 
                            "Could not establish BLE connection to " + macAddress, null);
                    });
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Exception during direct BLE connection test", e);
                mainHandler.post(() -> {
                    result.error("BLE_CONNECTION_ERROR", 
                        "BLE connection failed: " + e.getMessage(), null);
                });
            } finally {
                // Clean up connections
                try {
                    if (bleConnection != null && bleConnection.isConnected()) {
                        bleConnection.close();
                        Log.d(TAG, "Closed BLE connection");
                    }
                } catch (Exception closeEx) {
                    Log.w(TAG, "Error closing BLE connection", closeEx);
                }
            }
        });
    }

    private void discoverUsbPrinters(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity context is required for USB discovery", null);
            return;
        }

        Log.d(TAG, "Starting USB printer discovery...");

        executor.execute(() -> {
            try {
                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();

                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter discoveredPrinter) {
                        Log.d(TAG, "Found USB printer!");
                        
                        // Check if this is specifically a USB printer
                        if (discoveredPrinter instanceof DiscoveredPrinterUsb) {
                            DiscoveredPrinterUsb usbPrinter = (DiscoveredPrinterUsb) discoveredPrinter;
                            Log.d(TAG, "  USB Device: " + usbPrinter.device.getDeviceName());
                            Log.d(TAG, "  USB Product ID: " + usbPrinter.device.getProductId());
                            Log.d(TAG, "  USB Vendor ID: " + usbPrinter.device.getVendorId());
                        }
                        
                        Map<String, String> discoveryData = discoveredPrinter.getDiscoveryDataMap();
                        Log.d(TAG, "  FRIENDLY_NAME: " + discoveryData.get("FRIENDLY_NAME"));
                        Log.d(TAG, "  All discovery data: " + discoveryData.toString());

                        synchronized (discoveredPrinters) {
                            discoveredPrinters.add(discoveredPrinter);
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "USB discovery finished callback received");

                        List<Map<String, Object>> printers = new ArrayList<>();
                        synchronized (discoveredPrinters) {
                            for (DiscoveredPrinter printer : discoveredPrinters) {
                                Map<String, Object> printerMap = new HashMap<>();
                                
                                // Handle USB printers specifically
                                if (printer instanceof DiscoveredPrinterUsb) {
                                    DiscoveredPrinterUsb usbPrinter = (DiscoveredPrinterUsb) printer;
                                    printerMap.put("friendlyName", "USB Printer (" + usbPrinter.device.getProductId() + ")");
                                    printerMap.put("address", usbPrinter.device.getDeviceName());
                                    printerMap.put("interfaceType", "usb");
                                    printerMap.put("productId", usbPrinter.device.getProductId());
                                    printerMap.put("vendorId", usbPrinter.device.getVendorId());
                                } else {
                                    // Fallback to discovery data
                                    printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                                    printerMap.put("address", "Unknown USB Device");
                                    printerMap.put("interfaceType", "usb");
                                }
                                
                                printerMap.put("port", 0);
                                printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                                printers.add(printerMap);
                            }
                        }

                        mainHandler.post(() -> {
                            Log.d(TAG, "USB discovery completed. Found " + printers.size() + " printers");
                            result.success(printers);
                        });
                    }

                    @Override
                    public void discoveryError(String message) {
                        Log.e(TAG, "USB discovery error callback: " + message);
                        mainHandler.post(() -> {
                            result.error("DISCOVERY_FAILED", message, null);
                        });
                    }
                };

                Log.d(TAG, "Starting UsbDiscoverer.findPrinters...");
                // Use the application context for USB discovery
                UsbDiscoverer.findPrinters(activity.getApplicationContext(), discoveryHandler);
                
            } catch (Exception e) {
                Log.e(TAG, "USB discovery failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private boolean hasBluetoothPermissions() {
        if (activity == null) {
            return false;
        }
        
        // Check basic location permissions (required for all Android versions)
        boolean hasLocationPermission = 
            ContextCompat.checkSelfPermission(activity, android.Manifest.permission.ACCESS_COARSE_LOCATION) 
                == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(activity, android.Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;

        // For Android 12+ (API 31+), also check BLUETOOTH_SCAN permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            boolean hasBluetoothScan = 
                ContextCompat.checkSelfPermission(activity, android.Manifest.permission.BLUETOOTH_SCAN) 
                    == PackageManager.PERMISSION_GRANTED;
            return hasLocationPermission && hasBluetoothScan;
        }
        
        // For older Android versions, check legacy Bluetooth permissions
        boolean hasBluetoothPermission = 
            ContextCompat.checkSelfPermission(activity, android.Manifest.permission.BLUETOOTH) 
                == PackageManager.PERMISSION_GRANTED;
        boolean hasBluetoothAdmin = 
            ContextCompat.checkSelfPermission(activity, android.Manifest.permission.BLUETOOTH_ADMIN) 
                == PackageManager.PERMISSION_GRANTED;
                
        return hasLocationPermission && hasBluetoothPermission && hasBluetoothAdmin;
    }

    private void requestBluetoothPermissions(Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity context is required for permission requests", null);
            return;
        }

        // Check if permissions are already granted
        if (hasBluetoothPermissions()) {
            result.success(true);
            return;
        }

        // For now, just return a message asking user to grant permissions manually
        // A full implementation would use ActivityCompat.requestPermissions()
        result.error("PERMISSION_DENIED", 
            "Please grant Bluetooth and location permissions in system settings", null);
    }

    private void discoverPrinters(MethodCall call, Result result) {
        executor.execute(() -> {
            try {
                Log.d(TAG, "Starting local broadcast discovery");
                
                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
                final Object discoveryLock = new Object();
                final boolean[] discoveryComplete = {false};
                
                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter printer) {
                        synchronized (discoveredPrinters) {
                            discoveredPrinters.add(printer);
                            Log.d(TAG, "Found printer: " + getPrinterAddress(printer));
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "Discovery finished");
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }

                    @Override
                    public void discoveryError(String error) {
                        Log.e(TAG, "Discovery error: " + error);
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }
                };

                // Perform local broadcast discovery
                NetworkDiscoverer.localBroadcast(discoveryHandler);
                
                // Wait for discovery to complete
                synchronized (discoveryLock) {
                    while (!discoveryComplete[0]) {
                        discoveryLock.wait(10000); // 10 second timeout
                        break; // Exit if timeout
                    }
                }

                List<Map<String, Object>> printers = new ArrayList<>();
                synchronized (discoveredPrinters) {
                    for (DiscoveredPrinter printer : discoveredPrinters) {
                        Map<String, Object> printerMap = new HashMap<>();
                        printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                        printerMap.put("address", getPrinterAddress(printer));
                        printerMap.put("port", "9100");
                        printerMap.put("interfaceType", "tcp");
                        printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                        printers.add(printerMap);
                    }
                }

                mainHandler.post(() -> {
                    Log.d(TAG, "Local broadcast discovery completed. Found " + printers.size() + " printers");
                    result.success(printers);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Local broadcast discovery failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void discoverSubnetSearch(MethodCall call, Result result) {
        String subnetRange = call.argument("subnetRange");
        if (subnetRange == null) {
            result.error("MISSING_ARGUMENT", "Subnet range is required", null);
            return;
        }

        executor.execute(() -> {
            try {
                Log.d(TAG, "Starting subnet search for range: " + subnetRange);
                
                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
                final Object discoveryLock = new Object();
                final boolean[] discoveryComplete = {false};
                
                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter printer) {
                        synchronized (discoveredPrinters) {
                            discoveredPrinters.add(printer);
                            Log.d(TAG, "Found printer: " + getPrinterAddress(printer));
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "Subnet discovery finished");
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }

                    @Override
                    public void discoveryError(String error) {
                        Log.e(TAG, "Subnet discovery error: " + error);
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }
                };

                NetworkDiscoverer.subnetSearch(discoveryHandler, subnetRange);
                
                // Wait for discovery to complete
                synchronized (discoveryLock) {
                    while (!discoveryComplete[0]) {
                        discoveryLock.wait(20000); // 20 second timeout for subnet search
                        break; // Exit if timeout
                    }
                }

                List<Map<String, Object>> printers = new ArrayList<>();
                synchronized (discoveredPrinters) {
                    for (DiscoveredPrinter printer : discoveredPrinters) {
                        Map<String, Object> printerMap = new HashMap<>();
                        printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                        printerMap.put("address", getPrinterAddress(printer));
                        printerMap.put("port", "9100");
                        printerMap.put("interfaceType", "tcp");
                        printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                        printers.add(printerMap);
                    }
                }

                mainHandler.post(() -> {
                    Log.d(TAG, "Subnet search completed. Found " + printers.size() + " printers");
                    result.success(printers);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Subnet search failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    private void isConnected(Result result) {
        boolean connected = activeConnection != null && activeConnection.isConnected();
        result.success(connected);
    }

    private void discoverMulticastPrinters(MethodCall call, Result result) {
        Integer hops = call.argument("hops");
        if (hops == null) {
            hops = 3; // Default hops
        }

        final int finalHops = hops;
        
        executor.execute(() -> {
            try {
                Log.d(TAG, "Starting multicast discovery with " + finalHops + " hops");
                
                final List<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
                final Object discoveryLock = new Object();
                final boolean[] discoveryComplete = {false};
                
                DiscoveryHandler discoveryHandler = new DiscoveryHandler() {
                    @Override
                    public void foundPrinter(DiscoveredPrinter printer) {
                        synchronized (discoveredPrinters) {
                            discoveredPrinters.add(printer);
                            Log.d(TAG, "Found printer: " + getPrinterAddress(printer));
                        }
                    }

                    @Override
                    public void discoveryFinished() {
                        Log.d(TAG, "Multicast discovery finished");
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }

                    @Override
                    public void discoveryError(String error) {
                        Log.e(TAG, "Multicast discovery error: " + error);
                        synchronized (discoveryLock) {
                            discoveryComplete[0] = true;
                            discoveryLock.notify();
                        }
                    }
                };

                // Use multicast discovery with multicast lock
                WifiManager wifi = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
                WifiManager.MulticastLock lock = wifi.createMulticastLock("zebra_multicast_discovery_lock");
                lock.setReferenceCounted(true);
                lock.acquire();
                
                try {
                    NetworkDiscoverer.multicast(discoveryHandler, finalHops);
                    
                    // Wait for discovery to complete
                    synchronized (discoveryLock) {
                        while (!discoveryComplete[0]) {
                            discoveryLock.wait(10000); // 10 second timeout for multicast
                            break; // Exit if timeout
                        }
                    }
                } finally {
                    lock.release();
                }

                List<Map<String, Object>> printers = new ArrayList<>();
                synchronized (discoveredPrinters) {
                    for (DiscoveredPrinter printer : discoveredPrinters) {
                        Map<String, Object> printerMap = new HashMap<>();
                        printerMap.put("friendlyName", printer.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                        printerMap.put("address", getPrinterAddress(printer));
                        printerMap.put("port", "9100");
                        printerMap.put("interfaceType", "tcp");
                        printerMap.put("serialNumber", printer.getDiscoveryDataMap().get("SERIAL_NUMBER"));
                        printers.add(printerMap);
                    }
                }

                mainHandler.post(() -> {
                    Log.d(TAG, "Multicast discovery completed. Found " + printers.size() + " printers");
                    result.success(printers);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Multicast discovery failed", e);
                mainHandler.post(() -> {
                    result.error("DISCOVERY_FAILED", e.getMessage(), null);
                });
            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        
        // Clean up connections
        if (activeConnection != null && activeConnection.isConnected()) {
            try {
                activeConnection.close();
            } catch (Exception e) {
                Log.e(TAG, "Error closing connection during cleanup", e);
            }
        }
        
        executor.shutdown();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
}