import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

class PrinterService extends Notifier<PrinterState> {
  BlueThermalPrinter? _bluetooth;

  @override
  PrinterState build() {
    if (!kIsWeb && Platform.isAndroid) {
      _bluetooth = BlueThermalPrinter.instance;
    }
    init(); // Async init
    return PrinterState();
  }
  
  Future<void> init() async {
    if (!kIsWeb && Platform.isAndroid) {
      bool? isConnected = await _bluetooth?.isConnected;
      if (isConnected == true) {
        state = state.copyWith(isConnected: true);
      }
      getDevices();
    }
  }

  Future<void> getDevices() async {
    if (kIsWeb || !Platform.isAndroid) return;
    
    try {
      final devices = await _bluetooth?.getBondedDevices() ?? [];
      state = state.copyWith(devices: devices);
    } catch (e) {
      debugPrint("Error getting devices: $e");
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _bluetooth?.connect(device);
      state = state.copyWith(selectedDevice: device, isConnected: true);
    } catch (e) {
      debugPrint("Error connecting: $e");
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _bluetooth?.disconnect();
      state = state.copyWith(isConnected: false, selectedDevice: null);
    } catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }

  Future<void> printKOT(Map<String, dynamic> orderData) async {
    await _printUnified(orderData, isKOT: true);
  }

  Future<void> printBill(Map<String, dynamic> orderData) async {
    await _printUnified(orderData, isKOT: false);
  }

  Future<void> _printUnified(Map<String, dynamic> orderData, {required bool isKOT}) async {
    // MOCK PRINT for Web/Mac
    if (kIsWeb || !Platform.isAndroid) {
       debugPrint("------- MOCK ${isKOT ? 'KOT' : 'BILL'} -------");
       debugPrint("FUKREY CAFE");
       debugPrint("Type: ${isKOT ? 'KITCHEN COPY' : 'CUSTOMER BILL'}");
       debugPrint("Order ID: ${orderData['id']}");
       List items = orderData['items'];
       for (var item in items) {
          debugPrint("${item['name']} x ${item['quantity']}${isKOT ? '' : ' - ₹${item['price']}'}");
       }
       if (!isKOT) {
         debugPrint("Discount: ₹${orderData['discount_amount'] ?? 0}");
         debugPrint("Tax: ₹${orderData['tax_amount'] ?? 0}");
         debugPrint("TOTAL: ₹${orderData['total']}");
       }
       debugPrint("-------------------------------");
       return;
    }

    if (!state.isConnected) {
      debugPrint("Not connected to printer");
      return;
    }

    try {
      final isConnected = await _bluetooth?.isConnected;
      if (isConnected == true) {
        final bluetooth = _bluetooth!;
        
        // Header
        bluetooth.printNewLine();
        bluetooth.printCustom("FUKREY CAFE", 3, 1);
        if (isKOT) {
          bluetooth.printCustom("*** KOT ***", 2, 1);
        } else {
          bluetooth.printCustom("Customer Bill", 1, 1);
        }
        bluetooth.printNewLine();

        // Info
        bluetooth.printLeftRight("Order:", orderData['id'].toString().substring(0, 8), 1);
        bluetooth.printLeftRight("Date:", DateTime.now().toString().substring(0, 16), 1);
        bluetooth.printCustom("--------------------------------", 1, 1);

        // Items Header
        if (isKOT) {
          bluetooth.printLeftRight("Item", "Qty", 1);
        } else {
          bluetooth.printLeftRight("Item (Qty)", "Price", 1);
        }

        // Items
        List items = orderData['items'];
        for (var item in items) {
          if (isKOT) {
            bluetooth.printLeftRight(item['name'], "x${item['quantity']}", 1);
          } else {
            bluetooth.printLeftRight("${item['name']} (x${item['quantity']})", "₹${item['price'] * item['quantity']}", 1);
          }
        }
        bluetooth.printCustom("--------------------------------", 1, 1);

        // Footer / Totalling
        if (!isKOT) {
          if (orderData['discount_amount'] != null && orderData['discount_amount'] > 0) {
            bluetooth.printLeftRight("Discount:", "-₹${orderData['discount_amount']}", 1);
          }
          if (orderData['tax_amount'] != null && orderData['tax_amount'] > 0) {
            bluetooth.printLeftRight("Tax (5%):", "₹${orderData['tax_amount']}", 1);
          }
          bluetooth.printCustom("TOTAL: ₹${orderData['total']}", 2, 1);
          bluetooth.printNewLine();
          bluetooth.printCustom("Thank you! Visit Again.", 1, 1);
        } else {
          bluetooth.printCustom("Sent to Kitchen", 1, 1);
        }

        bluetooth.printNewLine();
        bluetooth.printNewLine();
        bluetooth.paperCut();
      } else {
        state = state.copyWith(isConnected: false);
      }
    } catch (e) {
      debugPrint("Print Error: $e");
    }
  }
}

class PrinterState {
  final List<BluetoothDevice> devices;
  final BluetoothDevice? selectedDevice;
  final bool isConnected;

  PrinterState({
    this.devices = const [],
    this.selectedDevice,
    this.isConnected = false,
  });

  PrinterState copyWith({
    List<BluetoothDevice>? devices,
    BluetoothDevice? selectedDevice,
    bool? isConnected,
  }) {
    return PrinterState(
      devices: devices ?? this.devices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

final printerServiceProvider = NotifierProvider<PrinterService, PrinterState>(() => PrinterService());

