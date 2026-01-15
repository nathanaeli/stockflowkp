import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/auth/landing_screen.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/services/shared_preferences_service.dart';
import 'package:provider/provider.dart';
import 'package:stockflowkp/services/locale_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _syncTimer;
  Locale _locale = const Locale('en');
  SharedPreferencesService? _prefsService;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _startBackgroundSync();
  }

  Future<void> _initializeApp() async {
    _prefsService = await SharedPreferencesService.getInstance();
    await _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    // Check if user has a saved language preference
    final savedLanguage = await _prefsService?.getSelectedLanguage();
    
    if (savedLanguage != null && mounted) {
      setState(() {
        _locale = Locale(savedLanguage);
      });
    } else {
      // Default to device language if supported, otherwise English
      final deviceLocale = WidgetsBinding.instance.window.locale;
      final supportedLanguages = ['en', 'sw', 'fr'];
      
      if (supportedLanguages.contains(deviceLocale.languageCode)) {
        setState(() {
          _locale = deviceLocale;
        });
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startBackgroundSync() {
    // Run sync every 2 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await _performSync();
    });

    // Also run immediately after a short delay to allow app to settle
    Future.delayed(const Duration(seconds: 5), () {
      _performSync();
    });
  }

  Future<void> _performSync() async {
    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      MyApp.isSyncingNotifier.value = true;

      if (token != null && token.isNotEmpty) {
        debugPrint('🔄 [Auto-Sync] Starting background synchronization...');

        // 1. Sync pending products, items, and stock
        await syncService.syncAllPendingData(token);

        // 2. Sync pending sales
        await syncService.syncAllPendingSales(token);

        debugPrint('✅ [Auto-Sync] Background synchronization completed.');
      } else {
        debugPrint('ℹ️ [Auto-Sync] Skipped: No auth token available.');
      }
    } catch (e) {
      debugPrint('❌ [Auto-Sync] Error during background sync: $e');
    } finally {
      MyApp.isSyncingNotifier.value = false;
    }
  }

  void _changeLanguage(Locale locale) async {
    await _prefsService?.setSelectedLanguage(locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockFlow KP',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4BB4FF),
          brightness: Brightness.dark,
          background: const Color(0xFF0A1B32),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1B32),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('sw'), // Swahili
        Locale('fr'), // French
      ],
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            ValueListenableBuilder<bool>(
              valueListenable: MyApp.isSyncingNotifier,
              builder: (context, isSyncing, _) {
                if (!isSyncing) return const SizedBox.shrink();
                return Positioned(
                  top: MediaQuery.of(context).padding.top,
                  right: 16,
                  child: const SafeArea(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4BB4FF)),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      home: LandingScreen(onLanguageChange: _changeLanguage, currentLocale: _locale),
    );
  }
}