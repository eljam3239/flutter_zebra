package com.zebra.zebra_printer_android;

import android.app.Activity;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

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
import com.zebra.sdk.printer.discovery.DiscoveredPrinter;
import com.zebra.sdk.printer.discovery.DiscoveredPrinterNetwork;
import com.zebra.sdk.printer.discovery.DiscoveryHandler;
import com.zebra.sdk.printer.discovery.DiscoveryException;
import com.zebra.sdk.printer.discovery.NetworkDiscoverer;
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

        // Only implement TCP connect for now (matching iOS implementation)
        if (!"tcp".equalsIgnoreCase(interfaceType)) {
            result.error("UNSUPPORTED_INTERFACE", "Only TCP interface is currently supported", null);
            return;
        }

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

        // Make final copies for lambda
        final String finalIpAddress = ipAddress;
        final int finalPort = port;

        executor.execute(() -> {
            try {
                Log.d(TAG, "Connecting to printer at " + finalIpAddress + ":" + finalPort);
                
                // Close existing connection if any
                if (activeConnection != null && activeConnection.isConnected()) {
                    activeConnection.close();
                }

                // Create new TCP connection
                activeConnection = new TcpConnection(finalIpAddress, finalPort);
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