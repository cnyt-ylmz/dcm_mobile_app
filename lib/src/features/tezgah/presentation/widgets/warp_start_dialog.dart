import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';
import '../../../../core/widgets/qr_scanner_widget.dart';


class WarpStartDialog extends StatefulWidget {
  final String initialLoomsText;
  const WarpStartDialog({super.key, this.initialLoomsText = ''});

  @override
  State<WarpStartDialog> createState() => _WarpStartDialogState();
}

class _WarpStartDialogState extends State<WarpStartDialog> {
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
    print("WarpStartDialog initState başladı");
    _personnelIdController.addListener(_onIdChanged);
    _personnelIdController.addListener(_onFormChanged);
    _orderNoController.addListener(_onFormChanged);
    _loomsController.addListener(_onFormChanged);
    if (widget.initialLoomsText.isNotEmpty) {
      print("initialLoomsText: ${widget.initialLoomsText}");
      _loomsController.text = widget.initialLoomsText;
      // Tek tezgah seçiliyse warp order'ı getir
      final loomNumbers = widget.initialLoomsText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      print("Loom numbers: $loomNumbers");
      if (loomNumbers.length == 1) {
        print("Tek tezgah var, API çağrısı yapılacak: ${loomNumbers.first}");
        _loadWarpOrder(loomNumbers.first);
      } else {
        print(
            "Tek tezgah yok, API çağrısı yapılmayacak. Sayı: ${loomNumbers.length}");
      }
    } else {
      print("initialLoomsText boş");
    }
    _loadPersonnels();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
    });
  }

  Future<void> _loadWarpOrder(String loomNo) async {
    print("_loadWarpOrder called with loomNo: $loomNo");
    setState(() => _isLoadingWorkOrder = true);
    try {
      // API çağrısı - Warp next endpoint
      final apiClient = GetIt.I<ApiClient>();

      print("API çağrısı yapılıyor: /api/warps/next/$loomNo");
      final response = await apiClient.get(
        '/api/warps/next/$loomNo',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Response alındı!");
      print("Response status: ${response.statusCode}");
      print("Response data: ${response.data}");

      if (response.data != null && response.data['workOrderNo'] != null) {
        print("WorkOrderNo: ${response.data['workOrderNo']}");
        if (mounted) {
          setState(() {
            _orderNoController.text = response.data['workOrderNo'].toString();
            // Form validasyonunu tetikle - TAMAM butonunu güncelle
          });
        }
      } else {
        print("Response data boş veya workOrderNo yok");
      }
    } catch (e) {
      print("API Hatası: $e - Çözgü iş emri alınamadı, kullanıcı manuel girebilir");
      // Hata mesajı gösterme, sadece log'la
      // Kullanıcı manuel olarak iş emri numarası girebilir
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
    if (_personnelIdController.text.trim().isEmpty || 
        _loomsController.text.trim().isEmpty ||
        _orderNoController.text.trim().isEmpty) {
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

  Future<void> _submitWarpStart() async {
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
        'status': 0, // Başlatma
      };

      print("Çözgü başlatma isteği: $requestData");

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

  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          title: 'qr_scan_warp_order_title'.tr(),
          onCodeScanned: (code) {
            if (code.isNotEmpty) {
              setState(() {
                _orderNoController.text = code;
              });
            }
            // Boş string ise hiçbir şey yapma, manuel giriş için
          },
        ),
      ),
    );
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
              'warp_start_title'.tr(),
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
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _openQRScanner,
                        tooltip: 'QR Kod Tara',
                      ),
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
                        ? _submitWarpStart
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

