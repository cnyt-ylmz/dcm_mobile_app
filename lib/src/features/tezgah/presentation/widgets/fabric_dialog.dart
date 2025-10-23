import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'fabric_start_dialog.dart';
import 'fabric_stop_dialog.dart';
import 'fabric_finish_dialog.dart';
import '../bloc/tezgah_bloc.dart';

Future<void> showFabricDialog(BuildContext context,
    {String initialLoomsText = ''}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'fabric_ops_title'.tr(),
                style: Theme.of(dialogContext).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _WideActionButton(
                text: 'fabric_start_order'.tr(),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricStartDialog(initialLoomsText: initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                },
              ),
              const SizedBox(height: 16),
              _WideActionButton(
                text: 'fabric_stop_order'.tr(),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricStopDialog(initialLoomsText: initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                },
              ),
              const SizedBox(height: 16),
              _WideActionButton(
                text: 'fabric_finish_order'.tr(),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) =>
                        FabricFinishDialog(initialLoomsText: initialLoomsText),
                  );
                  if (result == true && context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WideActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _WideActionButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}