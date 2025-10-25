import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import 'fabric_start_dialog.dart';
import 'fabric_stop_dialog.dart';
import 'fabric_finish_dialog.dart';
import '../bloc/tezgah_bloc.dart';
import '../../../../core/network/api_client.dart';

Future<void> showFabricDialog(BuildContext context,
    {String initialLoomsText = ''}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _FabricDialog(initialLoomsText: initialLoomsText);
    },
  );
}

class _FabricDialog extends StatefulWidget {
  final String initialLoomsText;

  const _FabricDialog({required this.initialLoomsText});

  @override
  State<_FabricDialog> createState() => _FabricDialogState();
}

class _FabricDialogState extends State<_FabricDialog> {
  bool _isLoading = true;
  String? _workOrderNo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWorkOrder();
  }

  Future<void> _loadWorkOrder() async {
    try {
      final apiClient = GetIt.I<ApiClient>();
      final loomNo = widget.initialLoomsText.trim();
      
      print("🌐 API Request: http://95.70.139.125:5100/api/style-work-orders/next/$loomNo");
      
      final response = await apiClient.get(
        '/api/style-work-orders/next/$loomNo',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.data != null && response.data['workOrderNo'] != null) {
            _workOrderNo = response.data['workOrderNo'].toString();
          } else {
            _workOrderNo = null;
          }
        });
      }
    } catch (e) {
      print("❌ Work order yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _workOrderNo = null;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'fabric_ops_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (_workOrderNo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'work_order_info'.tr(namedArgs: {'orderNo': _workOrderNo!}),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _WideActionButton(
                text: 'fabric_start_order'.tr(),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricStartDialog(initialLoomsText: widget.initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                },
              ),
              const SizedBox(height: 16),
              _WideActionButton(
                text: 'fabric_stop_order'.tr(),
                onPressed: _workOrderNo != null ? () async {
                  Navigator.of(context).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricStopDialog(initialLoomsText: widget.initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                } : null,
                isEnabled: _workOrderNo != null,
              ),
              const SizedBox(height: 16),
              _WideActionButton(
                text: 'fabric_finish_order'.tr(),
                onPressed: _workOrderNo != null ? () async {
                  Navigator.of(context).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricFinishDialog(initialLoomsText: widget.initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                } : null,
                isEnabled: _workOrderNo != null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WideActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const _WideActionButton({
    required this.text,
    this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled 
              ? const Color(0xFF1565C0) 
              : (isDarkMode ? const Color(0xFF2D2D30) : null),
          foregroundColor: isEnabled 
              ? Colors.white 
              : (isDarkMode ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: isEnabled ? 8 : 2,
          shadowColor: isEnabled 
              ? const Color(0xFF1565C0).withOpacity(0.3) 
              : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: isEnabled ? onPressed : null,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isEnabled 
                ? Colors.white 
                : (isDarkMode ? const Color(0xFF5A5A5A) : Colors.white),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}