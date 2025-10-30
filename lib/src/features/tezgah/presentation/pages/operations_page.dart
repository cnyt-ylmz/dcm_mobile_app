import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../operation/data/repositories/operation_repository_impl.dart';
import '../../../operation/domain/entities/operation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';
import '../bloc/tezgah_bloc.dart';


class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key, this.initialLoomsText = ''});
  final String initialLoomsText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('btn_op_start'.tr()),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _OperationStartForm(initialLoomsText: initialLoomsText),
    );
  }
}

class _OperationStartForm extends StatefulWidget {
  final String initialLoomsText;
  const _OperationStartForm({required this.initialLoomsText});

  @override
  State<_OperationStartForm> createState() => _OperationStartFormState();
}

class _OperationStartFormState extends State<_OperationStartForm> {
  final TextEditingController _loomsController = TextEditingController();
  final TextEditingController _personnelIdController = TextEditingController();
  final TextEditingController _personnelNameController =
      TextEditingController();
  final TextEditingController _operationCodeController =
      TextEditingController();
  final FocusNode _personnelIdFocus = FocusNode();

  List<MapEntry<int, String>> _personIndex = <MapEntry<int, String>>[];
  List<Operation> _operations = <Operation>[];
  Operation? _selectedOperation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loomsController.text = widget.initialLoomsText;
    _personnelIdController.addListener(_onIdChanged);
    _operationCodeController.addListener(_onOpCodeChanged);
    _loadInitialData();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _personnelIdController.removeListener(_onIdChanged);
    _operationCodeController.removeListener(_onOpCodeChanged);
    _personnelIdFocus.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Personeller
      final persons =
          await LoadPersonnels(GetIt.I<PersonnelRepositoryImpl>())();
      _personIndex = persons.map((e) => MapEntry(e.id, e.name)).toList();
      // Operasyonlar
      _operations = await GetIt.I<OperationRepositoryImpl>().fetchAll();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onIdChanged() {
    final int? id = int.tryParse(_personnelIdController.text.trim());
    if (id == null) {
      _personnelNameController.text = '';
    } else {
      for (final entry in _personIndex) {
        if (entry.key == id) {
          _personnelNameController.text = entry.value;
          break;
        }
      }
      if (_personnelNameController.text.isEmpty) {
        _personnelNameController.text = '';
      }
    }
    
    // Form validasyonunu güncelle
    if (mounted) {
      setState(() {
        // Form validasyonunu güncelle
      });
    }
  }

  void _onOpCodeChanged() {
    final String code = _operationCodeController.text.trim();
    Operation? match;
    for (final op in _operations) {
      if (op.code == code) {
        match = op;
        break;
      }
    }
    if (match != _selectedOperation) {
      setState(() {
        _selectedOperation = match;
      });
    }
    
    // Form validasyonunu güncelle
    if (mounted) {
      setState(() {
        // Form validasyonunu güncelle
      });
    }
  }

  bool _isValidForm() {
    if (_personnelIdController.text.trim().isEmpty || 
        _loomsController.text.trim().isEmpty ||
        _selectedOperation == null) {
      return false;
    }
    
    // Personel no'nun geçerli olup olmadığını kontrol et
    final personnelId = int.tryParse(_personnelIdController.text.trim());
    if (personnelId == null) {
      return false;
    }
    
    // Personel no'nun listede olup olmadığını kontrol et
    for (final entry in _personIndex) {
      if (entry.key == personnelId) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tezgahlar (readOnly ve çok satır)
          TextField(
            controller: _loomsController,
            readOnly: true,
            minLines: 1,
            maxLines: 8,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              labelText: 'label_looms'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _personnelIdController,
                  focusNode: _personnelIdFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'label_personnel_no'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _personnelNameController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'label_personnel_name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Operasyon seçimi: serbest kod girişi + dropdown
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _operationCodeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'label_operation_code'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Operation>(
                  value: _selectedOperation,
                  isExpanded: true,
                  items: _operations
                      .map((op) => DropdownMenuItem<Operation>(
                            value: op,
                            child: Text('${op.code} - ${op.name}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedOperation = val;
                      if (val != null) {
                        _operationCodeController.text = val.code;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'label_operation_select'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: BorderSide(
                      color: Colors.grey,
                      width: 1,
                    ),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : Colors.black,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text('action_cancel_submit'.tr()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isValidForm() && !_isSubmitting) ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: BorderSide(
                      color: (_isValidForm() && !_isSubmitting) 
                          ? const Color(0xFF1565C0)  // Aktif durumda mavi çerçeve
                          : Colors.grey,              // Pasif durumda gri çerçeve
                      width: (_isValidForm() && !_isSubmitting) ? 2 : 1,  // Aktif durumda 2px, pasif durumda 1px
                    ),
                    backgroundColor: (_isValidForm() && !_isSubmitting) 
                        ? const Color(0xFF1565C0) 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF2D2D30) 
                            : Colors.white),
                    foregroundColor: (_isValidForm() && !_isSubmitting) 
                        ? Colors.white 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF5A5A5A) 
                            : Colors.black87),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('action_submit'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _handleSubmit() async {
    // Validasyonlar
    final loomsText = _loomsController.text.trim();
    if (loomsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tezgah seçiniz!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final personnelId = int.tryParse(_personnelIdController.text.trim());
    if (personnelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen personel seçiniz!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Personel no'nun listede olup olmadığını kontrol et
    bool personnelExists = false;
    for (final entry in _personIndex) {
      if (entry.key == personnelId) {
        personnelExists = true;
        break;
      }
    }
    
    if (!personnelExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir personel seçiniz!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedOperation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen operasyon seçiniz!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Tezgah ID'lerini virgül veya boşlukla ayır
    final tezgahIds = loomsText
        .split(RegExp(r'[,\s]+'))
        .where((id) => id.isNotEmpty)
        .toList();

    if (tezgahIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli tezgah bulunamadı!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Loading göster
    setState(() => _isSubmitting = true);

    try {
      final apiClient = GetIt.I<ApiClient>();

      // İlk ilerleme dialogunu göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ProgressDialog(
          totalLooms: tezgahIds.length,
          currentLoom: 0,
        ),
      );

      // Her tezgah için ayrı istek at ve ilerlemeyi güncelle
      for (int i = 0; i < tezgahIds.length; i++) {
        final loomNo = tezgahIds[i];

        // İlerleme dialogunu güncelle
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ProgressDialog(
            totalLooms: tezgahIds.length,
            currentLoom: i + 1,
            currentLoomNo: loomNo,
          ),
        );

        final requestData = {
          "loomNo": loomNo,
          "personnelID": personnelId,
          "operationCode": int.tryParse(_selectedOperation!.code) ?? 0,
          "status": 0, // 0: Start
        };

        print("Operasyon başlatma isteği: $requestData");

        final response = await apiClient.post(
          '/api/DataMan/operationStartStop',
          data: requestData,
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ),
        );

        print("Response: ${response.data}");

        // Kısa bir gecikme ekle (çok hızlı geçmesin)
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        // İlerleme dialogunu kapat
        Navigator.of(context).pop();
        // Ana ekrana dön
        Navigator.of(context).pop(true); // true = başarılı

        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: tezgahIds,
          failedItems: [],
          successTitle: 'successful'.tr(),
          failedTitle: 'failed'.tr(),
          dialogTitle: 'operation_start_result'.tr(),
        );
      }
    } catch (e) {
      print("Hata: $e");
      if (mounted) {
        // İlerleme dialogunu kapat (açıksa)
        Navigator.of(context).pop();
        // Ana ekrana dön
        Navigator.of(context).pop(false); // false = başarısız
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: [],
          failedItems: tezgahIds,
          successTitle: 'successful'.tr(),
          failedTitle: 'failed'.tr(),
          dialogTitle: 'operation_start_result'.tr(),
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

}

class _ProgressDialog extends StatelessWidget {
  final int totalLooms;
  final int currentLoom;
  final String? currentLoomNo;

  const _ProgressDialog({
    required this.totalLooms,
    required this.currentLoom,
    this.currentLoomNo,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalLooms == 0 ? 0 : currentLoom / totalLooms;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'progress_processing_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$currentLoom / $totalLooms',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (currentLoomNo != null) ...[
              const SizedBox(height: 8),
              Text(
                '${'label_loom'.tr()}: $currentLoomNo',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

