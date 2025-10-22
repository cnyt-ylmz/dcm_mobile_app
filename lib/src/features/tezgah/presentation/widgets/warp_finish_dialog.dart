import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';


class WarpFinishDialog extends StatefulWidget {
  final String initialLoomsText;
  const WarpFinishDialog({super.key, this.initialLoomsText = ''});

  @override
  State<WarpFinishDialog> createState() => _WarpFinishDialogState();
}

class _WarpFinishDialogState extends State<WarpFinishDialog> {
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
      // Tek tezgah seçiliyse warp order'ı getir
      final loomNumbers = widget.initialLoomsText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (loomNumbers.length == 1) {
        _loadWarpOrder(loomNumbers.first);
      }
    }
    _loadPersonnels();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
    });
  }

  Future<void> _loadWarpOrder(String loomNo) async {
    print("_loadWarpOrder (FINISH) called with loomNo: $loomNo");
    setState(() => _isLoadingWorkOrder = true);
    try {
      // API çağrısı - Warp current endpoint (finish için)
      final apiClient = GetIt.I<ApiClient>();

      print("API çağrısı yapılıyor: /api/warps/current/$loomNo");
      final response = await apiClient.get(
        '/api/warps/current/$loomNo',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Response alındı!");
      print("Response status: ${response.statusCode}");
      print("Response data: ${response.data}");

      if (response.data != null &&
          response.data is List &&
          response.data.isNotEmpty &&
          response.data[0]['workOrderNo'] != null) {
        print("WorkOrderNo: ${response.data[0]['workOrderNo']}");
        if (mounted) {
          setState(() {
            _orderNoController.text =
                response.data[0]['workOrderNo'].toString();
          });
        }
      } else {
        print("Response data boş veya beklenen formatta değil");
      }
    } catch (e) {
      print("API Hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çözgü iş emri alınamadı: $e')),
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

  bool _isValidForm() {
    return _personnelIdController.text.trim().isNotEmpty &&
        _loomsController.text.trim().isNotEmpty;
  }

  Future<void> _submitWarpFinish() async {
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
      final int warpWorkOrderNo =
          orderNoText.isEmpty ? 0 : int.parse(orderNoText);

      final requestData = {
        'loomNo': _loomsController.text.trim(),
        'personnelID': int.parse(_personnelIdController.text.trim()),
        'warpWorkOrderNo': warpWorkOrderNo,
        'status': 1, // Bitirme
      };

      print("Çözgü bitirme isteği: $requestData");

      final response = await apiClient.post(
        '/api/DataMan/warpWorkOrderStartStopPause',
        data: requestData,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Response: ${response.data}");

      if (mounted) {
        Navigator.of(context).pop(); // Dialog'ı kapat
        
        // API response'unda status kontrolü
        final bool isSuccess = response.data['status'] == true;
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: isSuccess ? [_loomsController.text.trim()] : [],
          failedItems: isSuccess ? [] : [_loomsController.text.trim()],
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Çözgü İşlemi Sonucu',
          errorMessage: isSuccess ? null : response.data['message'],
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
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Çözgü İşlemi Sonucu',
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _onFormChanged() {
    // Form değiştiğinde UI'ı güncelle - TAMAM butonunu aktifleştir
    if (mounted) {
      setState(() {
        // Sadece setState çağır, form validasyonu _isValidForm() ile yapılıyor
      });
    }
  }

  void _onIdChanged() {
    final int? id = int.tryParse(_personnelIdController.text.trim());
    if (id == null) {
      _personnelNameController.text = '';
      return;
    }
    for (final entry in _personIndex) {
      if (entry.key == id) {
        _personnelNameController.text = entry.value;
        return;
      }
    }
    _personnelNameController.text = '';
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'warp_finish_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
            TextField(
              controller: _orderNoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'label_warp_order_no'.tr(),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('action_back'.tr())),
                ElevatedButton(
                  onPressed: (_isValidForm() && !_isSubmitting)
                      ? _submitWarpFinish
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('action_ok'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

