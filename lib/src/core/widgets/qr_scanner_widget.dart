import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onCodeScanned;
  final String title;

  const QRScannerWidget({
    super.key,
    required this.onCodeScanned,
    required this.title,
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController controller = MobileScannerController();
  bool isFlashOn = false;
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (capture.barcodes.isNotEmpty && _isScanning && mounted) {
                  final String? code = capture.barcodes.first.rawValue;
                  if (code != null) {
                    _isScanning = false; // Tekrar taramayı engelle
                    widget.onCodeScanned(code);
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 20,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(height: 2),
                Text(
                  'qr_scan_instruction'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onCodeScanned('');
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.keyboard, size: 16),
                    label: Text('qr_manual_entry'.tr(), style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}