import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// İşlem sonucu popup'ı - Dokumacı Değiştir tarzında standardize edilmiş
class ResultDialog extends StatefulWidget {
  final List<String> successItems;
  final List<String> failedItems;
  final String successTitle;
  final String failedTitle;
  final String dialogTitle;
  final int autoCloseSeconds;
  final String? errorMessage;

  const ResultDialog({
    super.key,
    required this.successItems,
    required this.failedItems,
    required this.successTitle,
    required this.failedTitle,
    required this.dialogTitle,
    this.autoCloseSeconds = 2,
    this.errorMessage,
  });

  /// Result dialog'ını göster
  static Future<void> show({
    required BuildContext context,
    required List<String> successItems,
    required List<String> failedItems,
    required String successTitle,
    required String failedTitle,
    required String dialogTitle,
    int autoCloseSeconds = 2,
    String? errorMessage,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ResultDialog(
        successItems: successItems,
        failedItems: failedItems,
        successTitle: successTitle,
        failedTitle: failedTitle,
        dialogTitle: dialogTitle,
        autoCloseSeconds: autoCloseSeconds,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> {
  @override
  void initState() {
    super.initState();
    // Belirtilen süre sonra otomatik kapat
    Future.delayed(Duration(seconds: widget.autoCloseSeconds), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.successItems.isNotEmpty) ...[
            Text(
              '✅ ${widget.successTitle} (${widget.successItems.length}):',
              style: const TextStyle(
                color: Colors.green, 
                fontWeight: FontWeight.bold
              ),
            ),
            Text(widget.successItems.join(', ')),
            const SizedBox(height: 8),
          ],
          if (widget.failedItems.isNotEmpty) ...[
            Text(
              '❌ ${widget.failedTitle} (${widget.failedItems.length}):',
              style: const TextStyle(
                color: Colors.red, 
                fontWeight: FontWeight.bold
              ),
            ),
            Text(widget.failedItems.join(', ')),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
      // Tamam butonu yok - otomatik kapanacak
    );
  }
}
