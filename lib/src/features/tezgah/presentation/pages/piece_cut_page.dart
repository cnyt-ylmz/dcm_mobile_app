import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../../personnel/domain/entities/personnel.dart';
import '../../../personnel/domain/usecases/load_personnels.dart';
import '../../../personnel/data/repositories/personnel_repository_impl.dart';
import '../../../personnel/data/datasources/personnel_remote_data_source.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';

class PieceCutPage extends StatelessWidget {
  final String selectedLoomNo;

  const PieceCutPage({
    Key? key,
    required this.selectedLoomNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('btn_piece_cut'.tr()),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _PieceCutForm(selectedLoomNo: selectedLoomNo),
    );
  }
}

class _PieceCutForm extends StatefulWidget {
  final String selectedLoomNo;

  const _PieceCutForm({required this.selectedLoomNo});

  @override
  State<_PieceCutForm> createState() => _PieceCutFormState();
}

class _PieceCutFormState extends State<_PieceCutForm> {
  final TextEditingController _loomNoController = TextEditingController();
  final TextEditingController _personnelIdController = TextEditingController();
  final TextEditingController _personnelNameController = TextEditingController();
  final TextEditingController _topNoController = TextEditingController();
  final TextEditingController _metreController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _personnelIdFocus = FocusNode();

  List<Personnel> _personnels = [];
  Personnel? _selectedPersonnel;
  bool _isLoading = false;
  bool _isLoadingWorkOrder = false;

  @override
  void initState() {
    super.initState();
    _loomNoController.text = widget.selectedLoomNo;
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
      
      // API çağrılarını ekran açıldıktan sonra başlat
      Future.microtask(() {
        _loadPersonnels();
        _loadWorkOrderData();
      });
    });
  }

  @override
  void dispose() {
    _loomNoController.dispose();
    _personnelIdController.dispose();
    _personnelNameController.dispose();
    _topNoController.dispose();
    _metreController.dispose();
    _personnelIdFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPersonnels() async {
    try {
      // Önce UI'yi göstermek için setState çağır
      if (mounted) {
        setState(() {});
      }
      
      final apiClient = GetIt.I<ApiClient>();
      final personnelRemoteDataSource = PersonnelRemoteDataSourceImpl(apiClient: apiClient);
      final personnelRepository = PersonnelRepositoryImpl(remote: personnelRemoteDataSource);
      final loadPersonnels = LoadPersonnels(personnelRepository);
      
      final personnels = await loadPersonnels();
      if (mounted) {
        setState(() => _personnels = personnels);
      }
    } catch (e) {
      print('Personnel yükleme hatası: $e');
    }
  }

  Future<void> _loadWorkOrderData() async {
    if (!mounted) return;
    
    print('🔄 _loadWorkOrderData başlatıldı - Loom No: ${widget.selectedLoomNo}');
    setState(() => _isLoadingWorkOrder = true);
    
    try {
      final apiClient = GetIt.I<ApiClient>();
      print('🌐 API çağrısı yapılıyor: /api/pieces/loom-workorder-pieces (POST)');
      final response = await apiClient.post('/api/pieces/loom-workorder-pieces', data: {'loomNo': widget.selectedLoomNo});
      
      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Data: ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        final workOrderData = response.data;
        
        // Debug: API'den gelen tüm alanları yazdır
        print('🔍 Loom Work Order Pieces API Response:');
        if (workOrderData is List && workOrderData.isNotEmpty) {
          final firstItem = workOrderData[0];
          print('  First item: $firstItem');
          
          // TOP NO'yu pieceNo'dan al
          if (firstItem['pieceNo'] != null) {
            _topNoController.text = firstItem['pieceNo'].toString();
            print('✅ TOP NO alındı: ${firstItem['pieceNo']}');
          } else {
            print('❌ pieceNo alanı bulunamadı');
          }
          
          // METRE'yi productedLength'den al ve virgülden sonra 2 hane olacak şekilde formatla
          if (firstItem['productedLength'] != null) {
            final double value = firstItem['productedLength'].toDouble();
            _metreController.text = value.toStringAsFixed(2).replaceAll('.', ',');
            print('✅ METRE alındı: ${value.toStringAsFixed(2)}');
          } else {
            print('❌ productedLength alanı bulunamadı');
          }
        } else {
          print('❌ API response boş veya geçersiz format');
        }
      } else {
        print('❌ API Response başarısız - Status: ${response.statusCode}, Data: ${response.data}');
      }
    } catch (e) {
      print('❌ Loom work order pieces verileri yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkOrder = false);
      }
      print('🏁 _loadWorkOrderData tamamlandı');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = GetIt.I<ApiClient>();
      final response = await apiClient.post(
        '/api/DataMan/pieceCutting',
        data: {
          'loomNo': _loomNoController.text,
          'personnelID': _personnelIdController.text,
          'topNo': _topNoController.text,
          'metre': _metreController.text,
        },
      );

      if (response.statusCode == 200) {
        _showResultDialog(
          successItems: ['${_loomNoController.text} tezgahı için top kesimi başarılı'],
          failedItems: [],
        );
        _clearForm();
      } else {
        _showResultDialog(
          successItems: [],
          failedItems: ['${_loomNoController.text} tezgahı için top kesimi başarısız'],
        );
      }
    } catch (e) {
      _showResultDialog(
        successItems: [],
        failedItems: ['Top kesimi işlemi başarısız: $e'],
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onPersonnelIdChanged(String value) {
    if (value.isNotEmpty) {
      try {
        final personnelId = int.parse(value);
        final personnel = _personnels.firstWhere(
          (p) => p.id == personnelId,
          orElse: () => Personnel(id: 0, name: ''),
        );
        if (personnel.id != 0) {
          _personnelNameController.text = personnel.name;
          setState(() => _selectedPersonnel = personnel);
        } else {
          _personnelNameController.clear();
          setState(() => _selectedPersonnel = null);
        }
      } catch (e) {
        _personnelNameController.clear();
        setState(() => _selectedPersonnel = null);
      }
    } else {
      _personnelNameController.clear();
      setState(() => _selectedPersonnel = null);
    }
    setState(() {}); // Form validasyonunu güncellemek için
  }

  bool _isFormValid() {
    return _personnelIdController.text.isNotEmpty &&
           _personnelNameController.text.isNotEmpty &&
           _topNoController.text.isNotEmpty &&
           _metreController.text.isNotEmpty;
  }

  void _clearForm() {
    _personnelIdController.clear();
    _personnelNameController.clear();
    _topNoController.clear();
    _metreController.clear();
    setState(() => _selectedPersonnel = null);
  }

  void _showResultDialog({
    required List<String> successItems,
    required List<String> failedItems,
  }) {
    showDialog(
      context: context,
      builder: (context) => ResultDialog(
        successItems: successItems,
        failedItems: failedItems,
        successTitle: 'successful'.tr(),
        failedTitle: 'failed'.tr(),
        dialogTitle: 'piece_cut_result'.tr(),
      ),
    ).then((_) {
      // Dialog kapandıktan sonra ana sayfaya dön ve refresh et
      Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            TextField(
              controller: _loomNoController,
              readOnly: true,
              minLines: 1,
              maxLines: 8,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                labelText: 'label_looms'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _personnelIdController,
                    focusNode: _personnelIdFocus,
                    decoration: InputDecoration(
                      labelText: 'label_personnel_no'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation_personnel_no_required'.tr();
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _onPersonnelIdChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _personnelNameController,
                    decoration: InputDecoration(
                      labelText: 'label_personnel_name'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    readOnly: true,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation_personnel_name_required'.tr();
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
        TextFormField(
          controller: _topNoController,
          decoration: InputDecoration(
            labelText: 'label_top_no'.tr(),
            border: const OutlineInputBorder(),
            suffixIcon: _isLoadingWorkOrder
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : null,
          ),
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) => setState(() {}), // Form validasyonunu güncellemek için
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'validation_top_no_required'.tr();
            }
            return null;
          },
        ),
            const SizedBox(height: 16),
        TextFormField(
          controller: _metreController,
          decoration: InputDecoration(
            labelText: 'label_metre'.tr(),
            border: const OutlineInputBorder(),
            suffixIcon: _isLoadingWorkOrder
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => setState(() {}), // Form validasyonunu güncellemek için
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'validation_metre_required'.tr();
            }
            // Virgülü noktaya çevirerek kontrol et
            final normalizedValue = value.replaceAll(',', '.');
            if (double.tryParse(normalizedValue) == null) {
              return 'Geçerli bir sayı girin';
            }
            return null;
          },
        ),
            const SizedBox(height: 24),
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
                    onPressed: _isLoading || !_isFormValid() ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: _isFormValid() 
                            ? const Color(0xFF1565C0)  // Aktif durumda mavi çerçeve
                            : Colors.grey,              // Pasif durumda gri çerçeve
                        width: _isFormValid() ? 2 : 1,  // Aktif durumda 2px, pasif durumda 1px
                      ),
                      backgroundColor: _isFormValid() 
                          ? const Color(0xFF1565C0) 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? const Color(0xFF2D2D30) 
                              : Colors.white),
                      foregroundColor: _isFormValid() 
                          ? Colors.white 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? const Color(0xFF5A5A5A) 
                              : Colors.black87),
                    ),
                    child: _isLoading
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
      ),
    );
  }
}
