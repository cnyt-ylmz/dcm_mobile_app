import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';


class FabricFinishDialog extends StatefulWidget {
  final String initialLoomsText;
  const FabricFinishDialog({super.key, this.initialLoomsText = ''});

  @override
  State<FabricFinishDialog> createState() => _FabricFinishDialogState();
}

class _FabricFinishDialogState extends State<FabricFinishDialog> {
  final TextEditingController _loomsController = TextEditingController();
  final TextEditingController _personnelIdController = TextEditingController();
  final TextEditingController _personnelNameController =
      TextEditingController();
  final TextEditingController _orderNoController = TextEditingController();
  final FocusNode _personnelIdFocus = FocusNode();
  List<MapEntry<int, String>> _personIndex = <MapEntry<int, String>>[];
  bool _isLoadingWorkOrder = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _personnelIdController.addListener(_onIdChanged);
    _personnelIdController.addListener(_onFormChanged);
    _orderNoController.addListener(_onFormChanged);
    _loomsController.addListener(_onFormChanged);
    if (widget.initialLoomsText.isNotEmpty) {
      _loomsController.text = widget.initialLoomsText;
      // Tek tezgah seçiliyse current work order'ı getir
      final loomNumbers = widget.initialLoomsText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (loomNumbers.length == 1) {
        _loadCurrentWorkOrder(loomNumbers.first);
      }
    }
    _loadPersonnels();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
    });
  }

  Future<void> _loadCurrentWorkOrder(String loomNo) async {
    setState(() => _isLoadingWorkOrder = true);
    try {
      final apiClient = GetIt.I<ApiClient>();

      print("🌐 API Request: http://95.70.139.125:5100/api/style-work-orders/next/$loomNo");
      
      final response = await apiClient.get(
        '/api/style-work-orders/next/$loomNo',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.data != null && response.data['workOrderNo'] != null) {
        if (mounted) {
          setState(() {
            _orderNoController.text = response.data['workOrderNo'].toString();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'error_current_work_order_load_failed'.tr(namedArgs: {'orderNo': _orderNoController.text.trim()})}: $e',
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkOrder = false);
      }
    }
  }

  Future<void> _loadPersonnels() async {
    try {
      final loader = LoadPersonnels(GetIt.I<PersonnelRepositoryImpl>());
      final list = await loader();
      if (!mounted) return;
      setState(() {
        _personIndex = list.map((e) => MapEntry(e.id, e.name)).toList();
      });
    } catch (_) {
      // ignore
    }
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {
        // Form validasyonunu güncelle
      });
    }
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
    _onFormChanged();
  }

  bool _isValidForm() {
    if (_personnelIdController.text.trim().isEmpty || _loomsController.text.trim().isEmpty) {
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

  // API'den gelen hata mesajlarını çeviri anahtarları ile değiştir
  String _translateErrorMessage(String? message) {
    if (message == null) return '';
    
    // Türkçe hata mesajlarını çeviri anahtarları ile değiştir
    if (message.contains('İş emri numarasına ilişkin tanımlı dokuma iş emri bulunamadı')) {
      return 'error_work_order_not_found'.tr(namedArgs: {'orderNo': _orderNoController.text.trim()});
    }
    
    return message; // Bilinmeyen hata mesajları için orijinal mesajı döndür
  }

  // Ortak submit metodu - status parametresi ile hangi işlem olduğunu belirler
  Future<void> _submitFabricOperation({
    required int status, // 0: başlat, 1: bitir, 2: durdur
    required String successMessage,
    required String errorMessage,
    Color successColor = Colors.green,
  }) async {
    if (!_isValidForm() || _isSubmitting) return;

    // Personel no validasyonu
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

    setState(() => _isSubmitting = true);

    try {
      final apiClient = GetIt.I<ApiClient>();

      final String orderNoText = _orderNoController.text.trim();
      final int styleWorkOrderNo =
          orderNoText.isEmpty ? 0 : int.parse(orderNoText);

      final requestData = {
        'loomNo': _loomsController.text.trim(),
        'personnelID': int.parse(_personnelIdController.text.trim()),
        'styleWorkOrderNo': styleWorkOrderNo,
        'status': status,
      };

      print("Kumaş işlemi isteği (status: $status): $requestData");

      final response = await apiClient.post(
        '/api/DataMan/styleWorkOrderStartStopPause',
        data: requestData,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Response: ${response.data}");

      if (mounted) {
        Navigator.of(context).pop(true); // Dialog'ı kapat ve başarılı olduğunu belirt
        
        // API response'unda status kontrolü
        final bool isSuccess = response.data['status'] == true;
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: isSuccess ? [_loomsController.text.trim()] : [],
          failedItems: isSuccess ? [] : [_loomsController.text.trim()],
          successTitle: 'successful'.tr(),
          failedTitle: 'failed'.tr(),
          dialogTitle: 'fabric_operation_result'.tr(),
          errorMessage: isSuccess ? null : _translateErrorMessage(response.data['message']),
        );
      }
    } catch (e) {
      print("Hata: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Dialog'ı kapat
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: [],
          failedItems: [_loomsController.text.trim()],
          successTitle: 'successful'.tr(),
          failedTitle: 'failed'.tr(),
          dialogTitle: 'fabric_operation_result'.tr(),
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _personnelIdController.removeListener(_onIdChanged);
    _personnelIdController.removeListener(_onFormChanged);
    _orderNoController.removeListener(_onFormChanged);
    _loomsController.removeListener(_onFormChanged);
    _personnelIdFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'fabric_finish_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _loomsController,
              readOnly: true,
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
            TextField(
              controller: _orderNoController,
              readOnly: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'label_fabric_order_no'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingWorkOrder
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
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
                    onPressed: (_isValidForm() && !_isSubmitting)
                        ? () => _submitFabricOperation(
                              status: 1, // Bitirme
                              successMessage: 'Kumaş iş emri başarıyla bitirildi',
                              errorMessage: 'Kumaş iş emri bitirilemedi',
                              successColor: Colors.green,
                            )
                        : null,
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
      ),
    );
  }
}

