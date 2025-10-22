import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';


Future<void> showPieceCutDialog(BuildContext context,
    {String selectedLoomNo = ''}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return PieceCutDialog(selectedLoomNo: selectedLoomNo);
    },
  );
}

class PieceCutDialog extends StatefulWidget {
  final String selectedLoomNo;
  const PieceCutDialog({super.key, this.selectedLoomNo = ''});

  @override
  State<PieceCutDialog> createState() => _PieceCutDialogState();
}

class _PieceCutDialogState extends State<PieceCutDialog> {
  final TextEditingController _tezgahController = TextEditingController();
  final TextEditingController _personnelIdController = TextEditingController();
  final TextEditingController _personnelNameController =
      TextEditingController();
  final TextEditingController _topNoController = TextEditingController();
  final TextEditingController _metreController = TextEditingController();
  final FocusNode _personnelIdFocus = FocusNode();
  List<MapEntry<int, String>> _personIndex = <MapEntry<int, String>>[];
  bool _isLoadingPieces = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _personnelIdController.addListener(_onIdChanged);
    _personnelIdController.addListener(_onFormChanged);
    _topNoController.addListener(_onFormChanged);
    _metreController.addListener(_onFormChanged);
    if (widget.selectedLoomNo.isNotEmpty) {
      _tezgahController.text = widget.selectedLoomNo;
      // Otomatik olarak pieces bilgilerini yükle
      _loadPieces();
    }
    _loadPersonnels();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
    });
  }

  Future<void> _loadPieces() async {
    if (widget.selectedLoomNo.isEmpty) return;

    setState(() => _isLoadingPieces = true);
    try {
      final apiClient = GetIt.I<ApiClient>();

      print("Pieces yükleniyor: ${widget.selectedLoomNo}");

      final response = await apiClient.post(
        '/api/pieces/loom-workorder-pieces',
        data: {'loomNo': widget.selectedLoomNo},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Response: ${response.data}");

      if (response.data != null &&
          response.data is List &&
          response.data.isNotEmpty) {
        final pieceData = response.data[0];
        if (mounted) {
          setState(() {
            _topNoController.text = pieceData['pieceNo']?.toString() ?? '';
            _metreController.text =
                pieceData['productedLength']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      print("API Hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Top bilgileri alınamadı: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPieces = false);
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
    if (_personnelIdController.text.trim().isEmpty || 
        _tezgahController.text.trim().isEmpty ||
        _topNoController.text.trim().isEmpty ||
        _metreController.text.trim().isEmpty) {
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

  Future<void> _submitPieceCut() async {
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

      final requestData = {
        'loomNo': _tezgahController.text.trim(),
        'personnelID': int.parse(_personnelIdController.text.trim()),
        'pieceNo': int.parse(_topNoController.text.trim()),
        'pieceLength': double.parse(_metreController.text.trim()),
        'manuelLength': 0, // Her zaman 0
      };

      print("Top kesim isteği: $requestData");

      final response = await apiClient.post(
        '/api/DataMan/pieceCutting',
        data: requestData,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      print("Top kesim response: ${response.data}");

      if (mounted) {
        Navigator.of(context).pop(); // Dialog'ı kapat
        
        // API response'unda status kontrolü
        final bool isSuccess = response.data['status'] == true;
        
        // Result dialog göster
        await ResultDialog.show(
          context: context,
          successItems: isSuccess ? [_tezgahController.text.trim()] : [],
          failedItems: isSuccess ? [] : [_tezgahController.text.trim()],
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Top Kesimi Sonucu',
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
          failedItems: [_tezgahController.text.trim()],
          successTitle: 'Başarılı',
          failedTitle: 'Başarısız',
          dialogTitle: 'Top Kesimi Sonucu',
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
    _topNoController.removeListener(_onFormChanged);
    _metreController.removeListener(_onFormChanged);
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
              'piece_cut_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tezgahController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'label_tezgah'.tr(),
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
              controller: _topNoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'label_top_no'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingPieces
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
            const SizedBox(height: 12),
            TextField(
              controller: _metreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'label_metre'.tr(),
                border: const OutlineInputBorder(),
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
                      ? _submitPieceCut
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

