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
      appBar: AppBar(title: Text('btn_op_start'.tr())),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('action_back'.tr())),
              ElevatedButton(
                onPressed: (_isValidForm() && !_isSubmitting) ? _handleSubmit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('action_ok'.tr()),
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

      // Her tezgah için ayrı istek at
      for (final loomNo in tezgahIds) {
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
      }

      if (mounted) {
        // Ana ekrana dön
        Navigator.of(context).pop(true); // true = başarılı

        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: tezgahIds,
          failedItems: [],
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Operasyon Başlatma Sonucu',
        );
      }
    } catch (e) {
      print("Hata: $e");
      if (mounted) {
        // Ana ekrana dön
        Navigator.of(context).pop(false); // false = başarısız
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: [],
          failedItems: tezgahIds,
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Operasyon Başlatma Sonucu',
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

