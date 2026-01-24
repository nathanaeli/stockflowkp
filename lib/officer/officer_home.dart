import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/officer/sale_loans_page.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:stockflowkp/auth/login_screen.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_page.dart';
import 'permissions_page.dart';
import 'category_management_page.dart';
import 'customer_management_page.dart';
import 'sales_management_page.dart';
import 'create_sale_page.dart';
import 'tenant_info_page.dart';
import 'pending_sales_page.dart';
import 'sales_analytics_page.dart';
import 'create_proforma_invoice_page.dart';
import 'view_proforma_invoice_page.dart';
import 'support_page.dart';
import 'how_to_use_page.dart';
import 'barcode_generator_screen.dart';
import 'check_stock_page.dart';
import 'backup_restore_page.dart';
import 'package:stockflowkp/utils/qr_scanner.dart';
import 'add_product_page.dart';
import 'product_details_page.dart';

// Simple Locale Provider
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);
  }

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language');

    if (savedLanguage != null && ['en', 'fr', 'sw'].contains(savedLanguage)) {
      _locale = Locale(savedLanguage);
      notifyListeners();
    }
  }
}

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});

  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _userData;
  List<String> _permissions = [];
  Timer? _syncTimer;
  late LocaleProvider _localeProvider;

  // Smart dashboard data
  double _todaySales = 0.0;
  int _pendingSalesCount = 0;
  int _lowStockCount = 0;
  bool _isLoading = false;
  bool _isFabRefreshing = false;

  @override
  void initState() {
    super.initState();
    _localeProvider = LocaleProvider();
    _localeProvider.loadSavedLocale();
    _loadUserData();
    _loadDashboardData();

    // Start background sync every 2 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted) return;
      if (_userData != null && _userData!['data'] != null) {
        final token = _userData!['data']['token'];
        await SyncService().syncAllPendingSales(token);
        await _fetchDashboardData(); // Automatically pull fresh data from server
        if (mounted) {
          await _loadDashboardData(
            checkAlerts: true,
            showLoading: false,
          ); // Refresh data after sync
        }
      }
    });
  }

  Future<void> _loadUserData() async {
    _userData = await DatabaseService().getUserData();

    if (_userData != null) {
      try {
        final user = _userData!['data']['user'];
        if (user['role'] != 'tenant') {
          final officerId = user['id'];
          _permissions = await DatabaseService().getPermissionNamesByOfficer(
            officerId,
          );
        }
      } catch (e) {
        print('Error loading permissions: $e');
      }
    }

    if (mounted) {
      setState(() {});
      if (_userData != null) {
        await _fetchDashboardData();
        await _loadDashboardData(); // Load smart dashboard data
      }
    }
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    try {
      final officerId = _userData!['data']['user']['id'];
      final token = _userData!['data']['token'];
      final apiService = ApiService();
      final dashboardData = await apiService.getOfficerDashboard(
        officerId,
        token,
      );
      print(dashboardData['products']);
      await DatabaseService().saveDashboardData(dashboardData);

      // Verify deletion and show alert if failed
      if (dashboardData.containsKey('deleted_product_ids') &&
          dashboardData['deleted_product_ids'] is List) {
        final deletedIds = dashboardData['deleted_product_ids'] as List;
        final db = await DatabaseService().database;
        final serverIds =
            deletedIds
                .map((id) => int.tryParse(id.toString()))
                .whereType<int>()
                .toList();

        if (serverIds.isNotEmpty) {
          final placeholders = List.filled(serverIds.length, '?').join(',');
          final results = await db.query(
            'products',
            columns: ['server_id'],
            where: 'server_id IN ($placeholders)',
            whereArgs: serverIds,
          );

          if (results.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Sync Warning: ${results.length} products failed to delete locally.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: () {
                    _fetchDashboardData();
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Failed to fetch dashboard: $e');
    }
  }

  Future<void> _handleRefresh() async {
    if (_userData != null && _userData!['data'] != null) {
      final token = _userData!['data']['token'];
      await SyncService().syncAllPendingSales(token);
      await _fetchDashboardData();
      if (mounted) {
        await _loadDashboardData(checkAlerts: true, showLoading: false);
      }
    }
  }

  Future<bool> _confirmRefreshIfPending() async {
    if (_pendingSalesCount == 0) return true;

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF0A1B32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  AppLocalizations.of(context)?.unsyncedData ?? 'Unsynced Data',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'You have $_pendingSalesCount unsynced sales. Refreshing will attempt to sync them first.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      AppLocalizations.of(context)?.cancel ?? 'Cancel',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BB4FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Sync & Refresh',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _onFabRefresh() async {
    if (_isFabRefreshing) return;

    final shouldProceed = await _confirmRefreshIfPending();
    if (!shouldProceed) return;

    setState(() => _isFabRefreshing = true);
    try {
      await _handleRefresh();
    } finally {
      if (mounted) setState(() => _isFabRefreshing = false);
    }
  }

  Future<void> _handleScannedQRCode(String qrCode) async {
    try {
      final cleanCode = qrCode.trim();
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Looking up product for QR: $cleanCode...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );

      // Use findProductByBarcodeOrSku to check both product_items (QR) and products (Barcode/SKU)
      final product = await DatabaseService().findProductByBarcodeOrSku(
        cleanCode,
      );

      if (product != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product found: ${product['name'] ?? 'Unknown'}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to product details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(product: product),
          ),
        );
      } else {
        // No product found, show message and navigate to check stock page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found for QR: $cleanCode'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckStockPage(initialBarcode: cleanCode),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error looking up QR code: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        // Fall back to check stock page on error
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckStockPage(initialBarcode: qrCode),
          ),
        );
      }
    }
  }

  Future<void> _loadDashboardData({
    bool checkAlerts = false,
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      // Load today's sales from local database
      await _loadTodaySales();
      await _loadPendingSalesCount();
      await _checkLowStock(showNotification: checkAlerts);
    } catch (e) {
      print('Failed to load dashboard data: $e');
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodaySales() async {
    try {
      final db = await DatabaseService().database;
      final today =
          DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format

      final result = await db.rawQuery(
        'SELECT SUM(total_amount) as today_total FROM sales WHERE DATE(created_at) = ?',
        [today],
      );

      if (mounted) {
        setState(() {
          _todaySales = (result.first['today_total'] as double?) ?? 0.0;
        });
      }
    } catch (e) {
      print('Error loading today sales: $e');
      if (mounted) setState(() => _todaySales = 0.0);
    }
  }

  Future<void> _loadPendingSalesCount() async {
    try {
      final syncService = SyncService();
      final count = await syncService.getPendingProductCount();
      if (mounted) {
        setState(() {
          _pendingSalesCount = count;
        });
      }
    } catch (e) {
      print('Error loading pending sales count: $e');
      if (mounted) setState(() => _pendingSalesCount = 0);
    }
  }

  Future<void> _checkLowStock({bool showNotification = false}) async {
    try {
      final lowStockProducts = await DatabaseService().getLowStockProducts(
        threshold: 10,
      );
      if (mounted) {
        setState(() {
          _lowStockCount = lowStockProducts.length;
        });

        if (showNotification && _lowStockCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.lowStockAlert(_lowStockCount) ??
                    '⚠️ Alert: $_lowStockCount products are low on stock!',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: AppLocalizations.of(context)?.view ?? 'VIEW',
                textColor: Colors.white,
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckStockPage()),
                    ),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking low stock: $e');
    }
  }

  bool _hasPermission(String permission) {
    if (_userData == null) return false;
    final user = _userData!['data']['user'];
    if (user['role'] == 'tenant') return true;
    return _permissions.contains(permission);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _localeProvider.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    Navigator.pop(context); // Close drawer

    if (_pendingSalesCount > 0) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isSyncing = false;
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                backgroundColor: const Color(0xFF0A1B32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  AppLocalizations.of(context)?.unsyncedData ?? 'Unsynced Data',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  AppLocalizations.of(
                        context,
                      )?.unsyncedWarning(_pendingSalesCount) ??
                      'You have $_pendingSalesCount pending items that haven\'t been synced yet. Signing out now will delete this data permanently.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: isSyncing ? null : () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)?.cancel ?? 'Cancel',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        isSyncing
                            ? null
                            : () {
                              Navigator.pop(context);
                              _performLogout();
                            },
                    child: Text(
                      AppLocalizations.of(context)?.deleteSignOut ??
                          'Delete & Sign Out',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSyncing
                            ? null
                            : () async {
                              setStateDialog(() => isSyncing = true);
                              try {
                                if (_userData != null &&
                                    _userData!['data'] != null) {
                                  final token = _userData!['data']['token'];
                                  await SyncService().syncAllPendingSales(
                                    token,
                                  );
                                  await _loadPendingSalesCount();

                                  if (_pendingSalesCount == 0) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.syncSuccessful ??
                                                'Sync successful! Signing out...',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      await Future.delayed(
                                        const Duration(seconds: 1),
                                      );
                                      _performLogout();
                                    }
                                  } else {
                                    if (mounted) {
                                      setStateDialog(() => isSyncing = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.syncFailed(
                                                  _pendingSalesCount,
                                                ) ??
                                                'Sync failed. $_pendingSalesCount items remaining.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  setStateDialog(() => isSyncing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                              context,
                                            )?.syncError(e) ??
                                            'Sync error: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BB4FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child:
                        isSyncing
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              AppLocalizations.of(context)?.syncSignOut ??
                                  'Sync & Sign Out',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      _showLogoutConfirmation();
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              AppLocalizations.of(context)?.signOut ?? 'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              AppLocalizations.of(context)?.confirmSignOut ??
                  'Are you sure you want to sign out? All local data will be cleared.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performLogout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performLogout() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService().database;
      final tables = [
        'sales',
        'sale_items',
        'products',
        'categories',
        'customers',
        'stocks',
        'officer',
        'user_data',
        'tenant_account',
        'proforma_invoices',
        'cart_drafts',
        'product_items',
        'stock_movements',
      ];

      for (var table in tables) {
        try {
          final check = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [table],
          );
          if (check.isNotEmpty) {
            await db.delete(table);
          }
        } catch (e) {
          debugPrint('Error clearing table $table: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.logoutFailed(e) ??
                  'Logout failed: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeProvider,
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: _localeProvider.locale,
          child: Builder(
            builder:
                (context) => Scaffold(
                  key: _scaffoldKey,
                  extendBodyBehindAppBar: true,
                  drawer: _buildGlassDrawer(context),
                  body: Stack(
                    children: [
                      // Background matches Login Page
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.5,
                            colors: [
                              Color(0xFF1E4976),
                              Color(0xFF0A1B32),
                              Color(0xFF020B18),
                            ],
                          ),
                        ),
                      ),

                      SafeArea(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: _getPage(_selectedIndex, context),
                        ),
                      ),

                      // Floating Bottom Navigation
                      _buildFloatingBottomNav(context),

                      // Refresh FAB (Only on Dashboard)
                      if (_selectedIndex == 0)
                        Positioned(
                          bottom: 120,
                          right: 24,
                          child: FloatingActionButton(
                            onPressed: _isFabRefreshing ? null : _onFabRefresh,
                            backgroundColor: const Color(0xFF4BB4FF),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child:
                                _isFabRefreshing
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }

  Widget _getPage(int index, BuildContext context) {
    switch (index) {
      case 0:
        return _buildDashboardView(context);
      case 1:
        return const SalesAnalyticsPage();
      case 2:
        return LocalProductPage(
          onRefresh: () async {
            if (mounted) {
              await _handleRefresh();
            }
          },
        );
      case 3:
        return const CustomerManagementPage();
      default:
        return _buildDashboardView(context);
    }
  }

  Widget _buildDashboardView(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final shouldProceed = await _confirmRefreshIfPending();
        if (shouldProceed) {
          await _handleRefresh();
        }
      },
      color: const Color(0xFF4BB4FF),
      backgroundColor: const Color(0xFF0A1B32),
      child: CustomScrollView(
        key: const PageStorageKey<String>('dashboard'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Custom Header
          SliverPadding(
            padding: const EdgeInsets.only(top: 20),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.notes_rounded,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Menu',
                    ),
                    Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)?.stockflowKP ??
                              'StockflowKP',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)?.winTheDream ??
                              'WIN THE DREAM',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message:
                              'Change Language / Changer de langue / Badilisha lugha',
                          child: _buildLanguageSelector(),
                        ),
                        const SizedBox(width: 8),
                        _buildGlassIconButton(
                          icon: Icons.notifications_active_outlined,
                          onTap: () {},
                          tooltip: 'Notifications',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Greeting
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.helloOfficer(
                          _userData?['data']?['user']?['name'] ??
                              AppLocalizations.of(context)?.officer ??
                              'Officer',
                        ) ??
                        'Hello, Officer 👋',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)?.readyForTasks ??
                        'Ready for today\'s tasks?',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Premium Glass Balance Card
          SliverToBoxAdapter(child: _buildGlassBalanceCard(context)),

          // Operations Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              delegate: SliverChildListDelegate([
                _buildActionTile(
                  Icons.qr_code_scanner_rounded,
                  AppLocalizations.of(context)?.scan ?? 'Scan',
                  Colors.white,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => Scaffold(
                              body: QRCodeScanner(
                                onQRCodeScanned: (code) {
                                  Navigator.pop(context, code);
                                },
                                initialMessage: 'Scan barcode',
                              ),
                            ),
                      ),
                    );

                    if (result != null && result is String && mounted) {
                      await _handleScannedQRCode(result);
                    }
                  },
                ),
                if (_hasPermission('add_product'))
                  _buildActionTile(
                    Icons.add_box_outlined,
                    AppLocalizations.of(context)?.addProduct ?? 'Add Product',
                    Colors.greenAccent,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddProductPage(),
                        ),
                      );
                      _loadDashboardData();
                    },
                  ),

                _buildActionTile(
                  Icons.inventory_2_outlined,
                  AppLocalizations.of(context)?.products ?? 'Products',
                  const Color(0xFF4BB4FF),
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _buildActionTile(
                  Icons.point_of_sale_outlined,
                  AppLocalizations.of(context)?.newSale ?? 'New Sale',
                  Colors.lightGreenAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CreateSalePage(
                                onSaleCreated: _loadDashboardData,
                              ),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.trending_up_rounded,
                  AppLocalizations.of(context)?.sales ?? 'Sales',
                  Colors.orangeAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SalesManagementPage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.category_outlined,
                  AppLocalizations.of(context)?.categories ?? 'Categories',
                  Colors.purpleAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryManagementPage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.admin_panel_settings_outlined,
                  AppLocalizations.of(context)?.permissions ?? 'Permissions',
                  Colors.blueAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PermissionsPage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.people_alt_outlined,
                  AppLocalizations.of(context)?.customers ?? 'Customers',
                  Colors.pinkAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerManagementPage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.business_rounded,
                  AppLocalizations.of(context)?.myCompany ?? 'My Company',
                  Colors.blueGrey,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TenantInfoPage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.request_quote_outlined,
                  AppLocalizations.of(context)?.proforma ?? 'Proforma',
                  Colors.tealAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const CreateProformaInvoicePage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.receipt_long_outlined,
                  AppLocalizations.of(context)?.invoices ?? 'Invoices',
                  Colors.cyanAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ViewProformaInvoicePage(),
                        ),
                      ),
                ),
                _buildActionTile(
                  Icons.money,
                  'Loans',
                  Colors.cyanAccent,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SaleLoansPage(),
                        ),
                      ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF0A1B32).withOpacity(0.95),
      icon: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.language, color: Colors.white, size: 24),
          ),
        ),
      ),
      onSelected: (String language) {
        _changeLanguage(language);
      },
      itemBuilder:
          (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'en',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.blue,
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'English',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'fr',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.red,
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Français',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'sw',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.green,
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kiswahili',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
    );
  }

  void _changeLanguage(String languageCode) {
    final locale = Locale(languageCode);

    // Update the locale using the provider
    _localeProvider.setLocale(locale);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Language changed to ${_getLanguageName(languageCode)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'sw':
        return 'Kiswahili';
      default:
        return 'Unknown';
    }
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBalanceCard(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'TZS ',
      decimalDigits: 2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.todaysSales ??
                                "Today's Sales",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(_todaySales),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: Color(0xFF4BB4FF),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildMiniBadge(
                        Icons.sync_problem_rounded,
                        "$_pendingSalesCount ${AppLocalizations.of(context)?.unsynced ?? 'Unsynced'}",
                      ),
                      const SizedBox(width: 12),

                      if (_lowStockCount > 0) ...[
                        const SizedBox(width: 12),
                        _buildMiniBadge(
                          Icons.warning_amber_rounded,
                          "$_lowStockCount ${AppLocalizations.of(context)?.lowStock ?? 'Low Stock'}",
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF020B18).withOpacity(0.85),
              border: const Border(right: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white12,
                            backgroundImage:
                                _userData?['data']?['user']?['profile_picture_url'] !=
                                        null
                                    ? NetworkImage(
                                      _userData!['data']['user']['profile_picture_url'],
                                    )
                                    : null,
                            child:
                                _userData?['data']?['user']?['profile_picture_url'] ==
                                        null
                                    ? const Icon(
                                      Icons.person_outline,
                                      size: 45,
                                      color: Colors.white70,
                                    )
                                    : null,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _userData?['data']?['user']?['name'] ??
                                AppLocalizations.of(context)?.officer ??
                                "Officer",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData?['data']?['user']?['email'] ??
                                AppLocalizations.of(context)?.defaultEmail ??
                                "email@example.com",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Divider(
                            color: Colors.white12,
                            indent: 30,
                            endIndent: 30,
                          ),
                          _drawerItem(
                            Icons.dashboard_customize_outlined,
                            AppLocalizations.of(context)?.dashboard ??
                                "Dashboard",
                            onTap: () => Navigator.pop(context),
                          ),
                          _drawerItem(
                            Icons.cloud_sync_outlined,
                            AppLocalizations.of(context)?.pendingSales ??
                                "Pending Sales",
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PendingSalesPage(),
                                  ),
                                ),
                          ),
                          _drawerItem(
                            Icons.inventory_rounded,
                            AppLocalizations.of(context)?.checkStock ??
                                "Check Stock",
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CheckStockPage(),
                                  ),
                                ),
                          ),
                          _drawerItem(
                            Icons.history_toggle_off_rounded,
                            AppLocalizations.of(context)?.activityLog ??
                                "Activity Log",
                          ),
                          _drawerItem(
                            Icons.qr_code_scanner,
                            AppLocalizations.of(context)?.barcodeGenerator ??
                                "Barcode Generator",
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const BarcodeGeneratorScreen(),
                                  ),
                                ),
                          ),
                          if (_hasPermission('backup_restore'))
                            _drawerItem(
                              Icons.settings_backup_restore_rounded,
                              AppLocalizations.of(context)?.backupRestore ??
                                  "Backup & Restore",
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BackupRestorePage(),
                                    ),
                                  ),
                            ),
                          _drawerItem(
                            Icons.menu_book_rounded,
                            AppLocalizations.of(context)?.howToUse ??
                                "How to use it ",
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HowToUsePage(),
                                  ),
                                ),
                          ),
                          _drawerItem(
                            Icons.help_center_outlined,
                            AppLocalizations.of(context)?.support ?? "Support",
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupportPage(),
                                  ),
                                ),
                          ),
                          // Note: Language settings moved to app bar for quick access
                          // _drawerItem(Icons.language, "Language", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSettingsPage()))),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    color: Colors.white12,
                    indent: 30,
                    endIndent: 30,
                  ),
                  _drawerItem(
                    Icons.logout_rounded,
                    AppLocalizations.of(context)?.signOut ?? "Sign Out",
                    color: Colors.redAccent.withOpacity(0.8),
                    onTap: _handleSignOut,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title, {
    Color color = Colors.white70,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
    return Positioned(
      bottom: 35,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  Icons.home_filled,
                  AppLocalizations.of(context)?.home ?? "Home",
                  0,
                ),
                _navItem(
                  Icons.bar_chart_rounded,
                  AppLocalizations.of(context)?.analytics ?? "Analytics",
                  1,
                ),
                _navItem(
                  Icons.inventory_2_rounded,
                  AppLocalizations.of(context)?.products ?? "Products",
                  2,
                ),
                _navItem(
                  Icons.group_outlined,
                  AppLocalizations.of(context)?.clients ?? "Clients",
                  3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF4BB4FF).withOpacity(0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4BB4FF) : Colors.white54,
              size: 15,
            ),
            if (isSelected) const SizedBox(width: 8),
            if (isSelected)
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4BB4FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
