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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
    _loadPersonnels();
    _loadWorkOrderData();
    
    // Personel No alanına otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _personnelIdFocus.requestFocus();
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
      final apiClient = GetIt.I<ApiClient>();
      final personnelRemoteDataSource = PersonnelRemoteDataSourceImpl(apiClient: apiClient);
      final personnelRepository = PersonnelRepositoryImpl(remote: personnelRemoteDataSource);
      final loadPersonnels = LoadPersonnels(personnelRepository);
      
      final personnels = await loadPersonnels();
      setState(() => _personnels = personnels);
    } catch (e) {
      print('Personnel yükleme hatası: $e');
    }
  }

  Future<void> _loadWorkOrderData() async {
    setState(() => _isLoadingWorkOrder = true);
    try {
      final apiClient = GetIt.I<ApiClient>();
      final response = await apiClient.get('/api/style-work-orders/current/${widget.selectedLoomNo}');
      
      if (response.statusCode == 200 && response.data != null) {
        final workOrderData = response.data;
        
        // TOP NO'yu workOrderNo'dan al
        if (workOrderData['workOrderNo'] != null) {
          _topNoController.text = workOrderData['workOrderNo'].toString();
        }
        
        // METRE'yi productedLength'den al ve virgülden sonra 2 hane olacak şekilde formatla
        if (workOrderData['productedLength'] != null) {
          final double value = workOrderData['productedLength'].toDouble();
          _metreController.text = value.toStringAsFixed(2).replaceAll('.', ',');
        }
      }
    } catch (e) {
      print('Work order verileri yükleme hatası: $e');
    } finally {
      setState(() => _isLoadingWorkOrder = false);
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
        successTitle: 'Başarılı',
        failedTitle: 'Başarısız',
        dialogTitle: 'Top Kesimi Sonucu',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
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
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        ElevatedButton(
          onPressed: _isLoading || !_isFormValid() ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('action_submit'.tr()),
        ),
          ],
        ),
      ),
    );
  }
}
