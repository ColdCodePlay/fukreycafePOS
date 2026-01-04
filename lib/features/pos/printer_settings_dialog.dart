import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../services/printer_service.dart';

class PrinterSettingsDialog extends ConsumerWidget {
  const PrinterSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerServiceProvider);
    final printerNotifier = ref.read(printerServiceProvider.notifier);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.print, color: Color(0xFFE38242)),
          SizedBox(width: 10),
          Text('Printer Settings'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (printerState.isConnected && printerState.selectedDevice != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connected to:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(printerState.selectedDevice!.name ?? 'Unknown Device',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => printerNotifier.disconnect(),
                      child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            const Text('Available Devices', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            if (printerState.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No paired bluetooth devices found. Please pair the printer in your phone settings first.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: printerState.devices.length,
                  itemBuilder: (context, index) {
                    final device = printerState.devices[index];
                    final isSelected = printerState.selectedDevice?.address == device.address;

                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.address ?? ''),
                      trailing: isSelected && printerState.isConnected
                          ? const Icon(Icons.check, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => printerNotifier.connect(device),
                              child: const Text('Connect'),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => printerNotifier.getDevices(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 4),
              Text('Refresh'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
