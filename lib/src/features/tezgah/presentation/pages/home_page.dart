import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/usecases/get_tezgahlar.dart';
import '../../domain/entities/tezgah.dart';
import '../../domain/repositories/tezgah_repository.dart';
import '../bloc/tezgah_bloc.dart';
import '../widgets/fabric_dialog.dart';
import '../widgets/warp_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/result_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final GetTezgahlar usecase = GetTezgahlar(GetIt.I<TezgahRepository>());
    final Box<dynamic> settingsBox = GetIt.I<Box<dynamic>>();
    return BlocProvider(
      create: (_) => TezgahBloc(
        getTezgahlar: usecase,
        settingsBox: settingsBox,
      )..add(TezgahFetched()),
      child: const _HomeView(),
    );
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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'teksdata',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF3868B9), // Yeni mavi renk
            fontWeight: FontWeight.w600,
            fontSize: 28,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.pushNamed('settings');
            },
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(
            MediaQuery.of(context).orientation == Orientation.landscape
                ? 8.0
                : 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GroupDropdown(),
            SizedBox(
                height: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 8
                    : 8),
            _SelectAllRow(),
            SizedBox(
                height: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 8
                    : 8),
            const Expanded(child: _TezgahGrid()),
            SizedBox(
                height: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 8
                    : 8),
            const _BottomActions(),
          ],
        ),
      ),
    );
  }
}

class _GroupDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TezgahBloc, TezgahState>(
      builder: (context, state) {
        final List<String> groups = state.groups;
        return DropdownButtonFormField<String?>(
          value: state.selectedGroup,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('all'.tr())),
            ...groups
                .map((g) => DropdownMenuItem<String?>(value: g, child: Text(g)))
          ],
          onChanged: (value) =>
              context.read<TezgahBloc>().add(TezgahGroupChanged(value)),
          decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'label_group'.tr(),
          ),
        );
      },
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          Checkbox(
            value: context.select<TezgahBloc, bool>((b) {
              final s = b.state;
              return s.items.isNotEmpty && s.items.every((e) => e.isSelected);
            }),
            onChanged: (v) =>
                context.read<TezgahBloc>().add(TezgahSelectAll(v ?? false)),
          ),
          Text('select_all'.tr(),
              style: Theme.of(context).textTheme.bodyMedium!),
        ]),
        Row(children: [
          Text('btn_refresh'.tr(),
              style: Theme.of(context).textTheme.bodyMedium!),
          IconButton(
            onPressed: () {
              context.read<TezgahBloc>().add(TezgahFetched());
            },
            icon: const Icon(Icons.refresh),
          ),
        ]),
      ],
    );
  }
}

class _TezgahGrid extends StatelessWidget {
  const _TezgahGrid();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TezgahBloc, TezgahState>(
      builder: (context, state) {
        if (state.status == TezgahStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == TezgahStatus.failure) {
          return Center(child: Text('error_load_failed'.tr()));
        }
        final List<Tezgah> items = state.items;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            const double spacing = 12;
            // Dinamik kolon sayısı: her cihaz/orientasyon için uygun
            final media = MediaQuery.of(context);
            final bool isTablet = media.size.shortestSide >= 600;
            final bool isLandscape = media.orientation == Orientation.landscape;
            final double desiredTileWidth = isTablet
                ? (isLandscape ? 200 : 180)
                : (isLandscape ? 140 : 160);
            int crossAxisCount = (maxWidth / desiredTileWidth).floor();
            crossAxisCount = crossAxisCount.clamp(2, 8);

            // Hesaplanan hücre genişliğine göre aspect ratio
            final double totalSpacing = spacing * (crossAxisCount - 1);
            final double tileWidth = (maxWidth - totalSpacing) / crossAxisCount;
            final double tileHeight = 100; // Portre ve yatay için 100px
            final double childAspectRatio = tileWidth / tileHeight;

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final Tezgah item = items[index];
                return GestureDetector(
                  onTap: () => context
                      .read<TezgahBloc>()
                      .add(TezgahToggleSelection(item.id)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _eventBackgroundColor(item.eventId, context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.grey.shade300,
                        width: item.isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        // Sol üst köşede Loom No
                        Positioned(
                          top: -5,
                          left: 0,
                          child: Text(
                            item.loomNo,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                        // Dokumacı Adı - Loom No'nun altında ve sola dayalı
                        Positioned(
                          top: 20,
                          left: 0,
                          child: Text(
                            item.weaverName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                            ),
                          ),
                        ),
                        // Stil Adı - Dokumacı Adı'nın altında ve sola dayalı
                        Positioned(
                          top: 40,
                          left: 0,
                          child: Text(
                            item.styleName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                            ),
                          ),
                        ),
                        // Operasyon adı - Kendi satırında, sola dayalı (varsa)
                        if (item.operationName.isNotEmpty)
                          Positioned(
                            top: 60, // Stil Adı'nın altında (15px boşluk)
                            left: 0, // Sola dayalı
                            child: Text(
                              item.operationName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

Color _eventBackgroundColor(int eventId, BuildContext context) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  
  if (isDarkMode) {
    switch (eventId) {
      case 0:
        return const Color(0xFF2D3A2D); // Cursor yeşil - Çalışıyor
      case 1:
        return const Color(0xFF2D2D30); // Cursor gri - Diğer Duruş
      case 2:
        return const Color(0xFF2D2F3A); // Cursor mavi - Atkı Duruşu
      case 3:
        return const Color(0xFF3A2D2D); // Cursor turuncu - Çözgü Duruşu
      default:
        return const Color(0xFF2D2D30); // Cursor varsayılan
    }
  } else {
    switch (eventId) {
      case 0:
        return const Color(0xFFE8F5E8); // Pastel yeşil - Çalışıyor
      case 1:
        return const Color(0xFFF5F5F5); // Pastel gri - Diğer Duruş
      case 2:
        return const Color(0xFFE3F2FD); // Pastel mavi - Atkı Duruşu
      case 3:
        return const Color(0xFFFFF3E0); // Pastel turuncu - Çözgü Duruşu
      default:
        return Colors.grey.shade100; // Varsayılan
    }
  }
}

class _TileText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int eventId;
  final int maxLines;

  const _TileText({
    required this.text,
    required this.style,
    required this.eventId,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    // Pastel renklerde koyu metin kullan
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style.copyWith(
        color: Colors.black87, // Tüm pastel renklerde koyu metin
        fontWeight: style.fontSize != null && style.fontSize! >= 18
            ? FontWeight.w600
            : null,
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 600;
    final bool hasSelection = context.select<TezgahBloc, bool>(
        (b) => b.state.items.any((e) => e.isSelected));
    final bool hasExactlyOneSelection = context.select<TezgahBloc, bool>(
        (b) => b.state.items.where((e) => e.isSelected).length == 1);

    String selectedLoomsText() {
      final items = context.read<TezgahBloc>().state.items;
      return items.where((e) => e.isSelected).map((e) => e.loomNo).join(',');
    }

    final List<Widget> buttons = [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasSelection ? 8 : 2,
          shadowColor: hasSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasSelection
            ? () async {
                await context.pushNamed('weaving',
                    extra: selectedLoomsText());
                if (context.mounted) {
                  context.read<TezgahBloc>().add(TezgahFetched());
                }
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_weaver'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasSelection ? 8 : 2,
          shadowColor: hasSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasSelection
            ? () async {
                await context.pushNamed('operations', extra: selectedLoomsText());
                if (context.mounted) {
                  context.read<TezgahBloc>().add(TezgahFetched());
                }
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_op_start'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasSelection ? 8 : 2,
          shadowColor: hasSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasSelection
            ? () async {
                final items = context.read<TezgahBloc>().state.items;
                final selected = items.where((e) => e.isSelected).toList();
                final noOp = selected
                    .where((e) => (e.operationName.isEmpty))
                    .map((e) => e.loomNo)
                    .toList();
                if (noOp.isNotEmpty) {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        'end_ops_warn_title'.tr(),
                        style: Theme.of(ctx).textTheme.titleLarge, // 22px
                        textAlign: TextAlign.left,
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'end_ops_warn_body'.tr(namedArgs: {'list': noOp.join(', ')}),
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 16.0),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(100, 40),
                                  ),
                                  child: Text('action_ok'.tr())),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  return;
                }

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'end_ops_title'.tr(),
                      style: Theme.of(ctx).textTheme.titleLarge, // 22px
                      textAlign: TextAlign.left,
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('end_ops_body'.tr()),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
                                  ),
                                  child: Text('action_cancel'.tr())),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(100, 40),
                                  ),
                                  child: Text('action_ok'.tr())),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                if (confirmed != true) {
                  // İptalle dönülse bile ana sayfayı yenile
                  if (context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                  return;
                }

                // Operasyon sonlandırma API çağrısı
                await _handleEndOperation(context);
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_op_end'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasExactlyOneSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasExactlyOneSelection ? 8 : 2,
          shadowColor: hasExactlyOneSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasExactlyOneSelection
            ? () async {
                final selected = selectedLoomsText();
                await showFabricDialog(context, initialLoomsText: selected);
                if (context.mounted) {
                  context.read<TezgahBloc>().add(TezgahFetched());
                }
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_fabric'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasExactlyOneSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasExactlyOneSelection ? 8 : 2,
          shadowColor: hasExactlyOneSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasExactlyOneSelection
            ? () async {
                final selected = selectedLoomsText();
                await showWarpDialog(context, initialLoomsText: selected);
                if (context.mounted) {
                  context.read<TezgahBloc>().add(TezgahFetched());
                }
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_warp'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasExactlyOneSelection ? const Color(0xFF1565C0) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D30) : null),
          foregroundColor: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
          elevation: hasExactlyOneSelection ? 8 : 2,
          shadowColor: hasExactlyOneSelection ? const Color(0xFF1565C0).withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: hasExactlyOneSelection
            ? () async {
                final selectedLoom = selectedLoomsText();
                // İş emri kontrolü yap
                final hasWorkOrder = await _checkWorkOrderForPieceCut(selectedLoom);
                if (!hasWorkOrder) {
                  // Dialog göster
                  await _showNoWorkOrderDialog(context);
                  // İptalle dönüşte de yenileyelim
                  if (context.mounted) {
                    context.read<TezgahBloc>().add(TezgahFetched());
                  }
                  return;
                }
                await context.pushNamed('piece-cut', extra: selectedLoom);
                if (context.mounted) {
                  context.read<TezgahBloc>().add(TezgahFetched());
                }
              }
            : null,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: Text(
            'btn_piece_cut'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasExactlyOneSelection ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5A5A5A) : Colors.white),
            ),
          ),
        ),
      ),
    ];

    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: isLandscape
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: buttons
                      .take(3)
                      .map((b) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(height: 55, child: b),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: buttons
                      .skip(3)
                      .map((b) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(height: 55, child: b),
                            ),
                          ))
                      .toList(),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: buttons
                      .take(2)
                      .map((b) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: SizedBox(height: 55, child: b),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: buttons
                      .skip(2)
                      .take(2)
                      .map((b) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: SizedBox(height: 55, child: b),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: buttons
                      .skip(4)
                      .map((b) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: SizedBox(height: 55, child: b),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
    );

    // Grup arka planını kaldır: Butonları doğrudan göster
    return content;
  }
}

/// Operasyon sonlandırma fonksiyonu
Future<void> _handleEndOperation(BuildContext context) async {
  final state = context.read<TezgahBloc>().state;
  final selectedItems = state.items.where((t) => t.isSelected).toList();

  if (selectedItems.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tezgah seçiniz!'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  // İlerleme dialogunu başlat
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ProgressDialog(
      totalLooms: selectedItems.length,
      currentLoom: 0,
    ),
  );

  try {
    final apiClient = GetIt.I<ApiClient>();

    // Her tezgah için ayrı istek at ve ilerlemeyi güncelle
    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];

      // İlerleme dialogunu güncelle
      if (context.mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ProgressDialog(
            totalLooms: selectedItems.length,
            currentLoom: i + 1,
            currentLoomNo: item.id,
          ),
        );
      }
      final requestData = {
        "loomNo": item.id,
        "personnelID": 1, // Backend 0 kabul etmiyor, varsayılan 1 kullan
        "operationCode": 1, // Sabit 1
        "status": 1, // Sabit 1 (Stop/End)
      };

      print("Operasyon sonlandırma isteği: $requestData");

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

    // İlerleme dialogunu kapat
    if (!context.mounted) return;
    Navigator.of(context).pop();

    // Result dialog göster
    await ResultDialog.show(
      context: context,
      successItems: selectedItems.map((e) => e.id).toList(),
      failedItems: [],
      successTitle: 'successful'.tr(),
      failedTitle: 'failed'.tr(),
      dialogTitle: 'operation_end_result'.tr(),
    );

    // Otomatik yenileme
    if (context.mounted) {
      context.read<TezgahBloc>().add(TezgahFetched());
    }
  } catch (e) {
    print("Hata: $e");

    // İlerleme dialogunu kapat (açıksa)
    if (!context.mounted) return;
    Navigator.of(context).pop();

    // Result dialog göster
    await ResultDialog.show(
      context: context,
      successItems: [],
      failedItems: selectedItems.map((e) => e.id).toList(),
      successTitle: 'successful'.tr(),
      failedTitle: 'failed'.tr(),
      dialogTitle: 'operation_end_result'.tr(),
      errorMessage: e.toString(),
    );
  }
}

// İş emri kontrolü için metod
Future<bool> _checkWorkOrderForPieceCut(String loomNo) async {
  try {
    final apiClient = GetIt.I<ApiClient>();
    
    print("🌐 API Request: http://95.70.139.125:5100/api/style-work-orders/current/$loomNo");
    
    final response = await apiClient.get(
      '/api/style-work-orders/current/$loomNo',
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (response.data != null && response.data['workOrderNo'] != null) {
      print("✅ Piece Cut - Work Order found: ${response.data['workOrderNo']}");
      return true;
    } else {
      print("❌ Piece Cut - No Work Order found");
      return false;
    }
  } catch (e) {
    print("❌ Piece Cut - Work order check error: $e");
    return false;
  }
}

// İş emri olmadığında gösterilecek dialog
Future<void> _showNoWorkOrderDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'piece_cut_no_work_order_title'.tr(),
          style: Theme.of(dialogContext).textTheme.titleLarge,
          textAlign: TextAlign.left,
        ),
        content: Text(
          'piece_cut_no_work_order'.tr(),
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(fontSize: 16.0),
          textAlign: TextAlign.left,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 40),
                ),
                child: Text('action_ok'.tr()),
              ),
            ],
          ),
        ],
      );
    },
  );
}
