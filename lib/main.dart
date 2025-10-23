import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/core/di/di.dart';
import 'src/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await configureDependencies(GetIt.I);

  // 🚀 Uygulama başlatılıyor...
  print('🚀 DCM Mobile Tezgah Kontrol Uygulaması başlatılıyor (Auth disabled)...');

  // Persisted locale from Hive
  final Box<dynamic> settings = GetIt.I<Box<dynamic>>();
  final String? savedLocaleCode = settings.get('locale_code') as String?;
  final Locale startLocale =
      savedLocaleCode == null ? const Locale('tr') : Locale(savedLocaleCode);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      startLocale: startLocale,
      child: const FazApp(),
    ),
  );
}

class FazApp extends StatelessWidget {
  const FazApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = buildRouter();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TEZGAHLAR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF1565C0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF1565C0), width: 2),
          ),
          labelStyle: TextStyle(color: const Color(0xFF1565C0)),
          floatingLabelStyle: TextStyle(color: const Color(0xFF1565C0)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Cursor dark background
        dialogBackgroundColor: const Color(0xFF252526), // Cursor dialog background
        cardColor: const Color(0xFF2D2D30), // Cursor card background
        dividerColor: const Color(0xFF3E3E42), // Cursor divider
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF1565C0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF1565C0), width: 2),
          ),
          labelStyle: TextStyle(color: const Color(0xFF1565C0)),
          floatingLabelStyle: TextStyle(color: const Color(0xFF1565C0)),
        ),
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
    );
  }
}
