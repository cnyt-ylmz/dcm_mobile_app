import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/tezgah.dart';
import '../../domain/usecases/get_tezgahlar.dart';

part 'tezgah_event.dart';
part 'tezgah_state.dart';

class TezgahBloc extends Bloc<TezgahEvent, TezgahState> {
  final GetTezgahlar getTezgahlar;
  final Box<dynamic> _settingsBox;

  TezgahBloc({required this.getTezgahlar, required Box<dynamic> settingsBox})
      : _settingsBox = settingsBox,
        super(const TezgahState.initial()) {
    on<TezgahFetched>(_onFetched);
    on<TezgahGroupChanged>(_onGroupChanged);
    on<TezgahToggleSelection>(_onToggle);
    on<TezgahSelectAll>(_onSelectAll);
  }

  Future<void> _onFetched(
      TezgahFetched event, Emitter<TezgahState> emit) async {
    emit(state.copyWith(status: TezgahStatus.loading));
    try {
      // Kaydedilmiş grup seçimini yükle
      final String? savedGroup = _settingsBox.get('selected_group') as String?;
      
      final List<Tezgah> items =
          await getTezgahlar.call(group: savedGroup);
      final Set<String> uniqueGroups = items
          .map((e) => (e.groupName).trim())
          .where((g) => g.isNotEmpty)
          .toSet();
      final List<String> groupList = uniqueGroups.toList()..sort(_compareGroupNames);
      emit(state.copyWith(
        status: TezgahStatus.success,
        items: _applyFilter(items, savedGroup),
        allItems: items,
        groups: groupList,
        selectedGroup: savedGroup,
      ));
    } catch (e) {
      emit(state.copyWith(status: TezgahStatus.failure));
    }
  }

  Future<void> _onGroupChanged(
      TezgahGroupChanged event, Emitter<TezgahState> emit) async {
    final String? group = event.group;
    final List<Tezgah> filtered = _applyFilter(state.allItems, group);
    
    // Grup seçimini kalıcı olarak kaydet
    if (group != null) {
      await _settingsBox.put('selected_group', group);
    } else {
      await _settingsBox.delete('selected_group');
    }
    
    emit(state.copyWith(selectedGroup: group, items: filtered));
  }

  void _onToggle(TezgahToggleSelection event, Emitter<TezgahState> emit) {
    final List<Tezgah> updated = state.items
        .map((e) =>
            e.id == event.tezgahId ? e.copyWith(isSelected: !e.isSelected) : e)
        .toList();
    emit(state.copyWith(items: updated));
  }

  void _onSelectAll(TezgahSelectAll event, Emitter<TezgahState> emit) {
    final List<Tezgah> updated = state.items
        .map((e) => e.copyWith(isSelected: event.selectAll))
        .toList();
    emit(state.copyWith(items: updated));
  }
}

int _compareGroupNames(String a, String b) {
  // Sayısal sıralama için özel karşılaştırma
  // Önce sayısal kısmı çıkar, sonra karşılaştır
  final int? numA = int.tryParse(a.replaceAll(RegExp(r'[^\d]'), ''));
  final int? numB = int.tryParse(b.replaceAll(RegExp(r'[^\d]'), ''));
  
  if (numA != null && numB != null) {
    return numA.compareTo(numB);
  }
  
  // Sayısal değilse normal string karşılaştırması
  return a.compareTo(b);
}

List<Tezgah> _applyFilter(List<Tezgah> all, String? group) {
  if (group == null || group.isEmpty) return all;
  return all.where((e) => e.groupName == group).toList();
}
