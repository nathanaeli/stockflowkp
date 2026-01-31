import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../auth/login_screen.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:stockflowkp/services/locale_provider.dart';
import 'package:stockflowkp/tenants/duka_dashboard.dart';
import 'package:stockflowkp/tenants/sales_page.dart';
import 'package:stockflowkp/tenants/profit_loss_page.dart';
import 'package:stockflowkp/tenants/officers_page.dart';

import 'package:stockflowkp/tenants/categories_page.dart';
import 'package:stockflowkp/tenants/transactions_report_page.dart';
import 'package:stockflowkp/tenants/inventory_analysis_page.dart';
import 'package:stockflowkp/tenants/create_duka_page.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();

  Map<String, dynamic>? _tenantData;
  List<dynamic> _dukasList = [];
  List<dynamic> _lowStockProducts = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  String? _token;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _dbService.getUserData();
      if (userData != null && userData['data'] != null) {
        if (!mounted) return;
        setState(() {
          _userData = userData;
          _token = userData['data']['token'];
        });
        await _fetchDetails();
      } else {
        if (!mounted) return;
        setState(() {
          _error = "User session not found. Please log in again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error loading session: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDetails() async {
    if (_token == null) return;

    try {
      final tenantFuture = _apiService.getTenantDetails(_token!);
      final dukasFuture = _apiService.getTenantDukas(_token!);

      // We'll fetch P&L separately but in parallel if needed, or sequentially here.
      // Let's create a future for it too.
      // Default to current month for initial load

      final lowStockFuture = _apiService.getLowStockProducts(_token!);

      final responses = await Future.wait([
        tenantFuture,
        dukasFuture,
        lowStockFuture,
      ]);
      final tenantResponse = responses[0];
      final dukasResponse = responses[1];
      final lowStockResponse = responses[2];

      if (tenantResponse['success'] == true) {
        if (!mounted) return;
        setState(() {
          _tenantData = tenantResponse;
          if (dukasResponse['success'] == true) {
            _dukasList = dukasResponse['data'] ?? [];
          }
          if (lowStockResponse['success'] == true) {
            _lowStockProducts = lowStockResponse['data'] ?? [];
          }
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              tenantResponse['message'] ?? "Failed to fetch dashboard data.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to sign out?',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _dbService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Delete Account',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to PERMANENTLY delete your account?',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This action is IRREVERSIBLE. All your data including shops, inventory, sales, and staff will be permanently removed.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Permanently Delete',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final response = await _apiService.deleteTenantAccount(_token!);
        if (response['success'] == true) {
          await _dbService.logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account deleted successfully."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? "Deletion failed"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting account: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Helper for currency formatting
  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(symbol: 'Tsh ', decimalDigits: 0);
    return formatter.format(amount ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _tenantData?['tenant_name'] ?? 'Tenant Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate_rounded, color: Colors.white),
            onPressed: () => _showLanguageDialog(context),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: _showNotificationsModal,
              ),
              if (_lowStockProducts.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_lowStockProducts.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      drawer: _buildGlassDrawer(context),
      body: Stack(
        children: [
          // Background Gradient
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
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4BB4FF),
                      ),
                    )
                    : _error != null
                    ? _buildErrorView()
                    : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _buildContentForIndex(_selectedIndex),
                      ),
                    ),
          ),

          // Floating Bottom Navigation
          _buildFloatingBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    if (_tenantData == null || _tenantData!['overview'] == null) {
      return const SizedBox.shrink();
    }

    switch (index) {
      case 0:
        return _buildHomeView();
      case 1:
        return _buildShopsListView();
      case 2:
        return _buildSalesView();
      case 3:
        return const ProfitLossPage();
      case 4:
        return _buildProfileView();
      case 5:
        return const OfficersPage();
      case 6:
        return const CategoriesPage();
      case 7:
        return const TransactionsReportPage();
      case 8:
        return const InventoryAnalysisPage();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildSalesView() {
    return const SalesPage();
  }

  Widget _buildHomeView() {
    final overview = _tenantData!['overview'];
    final financials = overview['financials'] ?? {};
    final inventory = overview['inventory'] ?? {};
    final dukas =
        _dukasList.isNotEmpty
            ? _dukasList
            : List.from(overview['today_by_duka'] ?? []);

    return RefreshIndicator(
      onRefresh: _fetchDetails,
      backgroundColor: const Color(0xFF0A1B32),
      color: const Color(0xFF4BB4FF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSyncedDate(),
            const SizedBox(height: 24),

            _buildSectionHeader(
              AppLocalizations.of(context)!.financialOverview,
              Icons.payments_outlined,
            ),
            const SizedBox(height: 16),
            _buildFinancialGrid(financials, context),

            const SizedBox(height: 32),

            _buildSectionHeader(
              AppLocalizations.of(context)!.businessInventory,
              Icons.business_center_outlined,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              AppLocalizations.of(context)!.totalProducts,
              inventory['total_products']?.toString() ?? '0',
              Icons.inventory_2_outlined,
              Colors.cyanAccent,
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              AppLocalizations.of(context)!.stockValueCost,
              _formatCurrency(inventory['stock_valuation']),
              Icons.analytics_outlined,
              Colors.tealAccent,
              fullWidth: true,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader(
              AppLocalizations.of(context)!.todaysPerformanceByShop,
              Icons.storefront_outlined,
            ),
            const SizedBox(height: 16),
            if (dukas.isEmpty)
              _buildEmptyDukas()
            else
              ...dukas.map((duka) => _buildDukaCard(duka)).toList(),

            const SizedBox(height: 100), // Spacing for nav bar
          ],
        ),
      ),
    );
  }

  Widget _buildShopsListView() {
    final dukas = _dukasList;

    return RefreshIndicator(
      onRefresh: _fetchDetails,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        itemCount: dukas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncedDate(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  AppLocalizations.of(context)!.allShops,
                  Icons.storefront_rounded,
                ),
                const SizedBox(height: 16),
              ],
            );
          }
          final duka = dukas[index - 1];
          return _buildDukaCard(duka);
        },
      ),
    );
  }

  Widget _buildProfileView() {
    final user = _userData?['data']?['user'] ?? {};
    final tenantName = _tenantData?['tenant_name'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4BB4FF), width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white12,
              backgroundImage:
                  user['profile_picture_url'] != null
                      ? NetworkImage(user['profile_picture_url'])
                      : null,
              child:
                  user['profile_picture_url'] == null
                      ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white70,
                      )
                      : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user['name'] ?? 'Tenant User',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            user['email'] ?? '',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildProfileItem(
                  Icons.business_rounded,
                  AppLocalizations.of(context)!.tenantName,
                  tenantName,
                ),
                const Divider(color: Colors.white10, height: 32),
                _buildProfileItem(
                  Icons.shield_rounded,
                  AppLocalizations.of(context)!.role,
                  "Administrator",
                ),
                const Divider(color: Colors.white10, height: 32),
                _buildProfileItem(
                  Icons.calendar_today_rounded,
                  AppLocalizations.of(context)!.joined,
                  "Jan 20, 2026",
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {
              // Placeholder for edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Edit Profile functionality coming soon"),
                ),
              );
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(AppLocalizations.of(context)!.editProfile),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
              foregroundColor: const Color(0xFF4BB4FF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _handleDeleteAccount,
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text("Delete Account"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(height: 100), // Extra space for bottom nav
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4BB4FF), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassDrawer(BuildContext context) {
    final user = _userData?['data']?['user'] ?? {};
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF020B18).withOpacity(0.95),
                  const Color(0xFF0A1E35).withOpacity(0.90),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 24, 30),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4BB4FF),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4BB4FF).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white12,
                            backgroundImage:
                                user['profile_picture_url'] != null
                                    ? NetworkImage(user['profile_picture_url'])
                                    : null,
                            child:
                                user['profile_picture_url'] == null
                                    ? const Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Colors.white70,
                                    )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name'] ?? 'Tenant User',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _drawerItem(
                            Icons.dashboard_rounded,
                            l10n.dashboard,
                            isSelected: _selectedIndex == 0,
                            onTap: () {
                              Navigator.pop(context); // Close drawer
                              setState(() => _selectedIndex = 0);
                            },
                          ),
                          _drawerItem(
                            Icons.storefront_rounded,
                            l10n.myShops,
                            isSelected: _selectedIndex == 1,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 1);
                            },
                          ),
                          _drawerItem(
                            Icons.receipt_long_rounded,
                            l10n.sales,
                            isSelected: _selectedIndex == 2,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 2);
                            },
                          ),
                          const SizedBox(height: 24),
                          _drawerSectionTitle(l10n.analytics.toUpperCase()),
                          _drawerItem(
                            Icons.bar_chart_rounded,
                            l10n.profitAndLoss,
                            isSelected: _selectedIndex == 3,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 3);
                            },
                          ),
                          _drawerItem(
                            Icons.receipt_long_outlined,
                            l10n.transactionsReport,
                            isSelected: _selectedIndex == 7,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 7);
                            },
                          ),
                          _drawerItem(
                            Icons.analytics_outlined,
                            l10n.inventoryAndAging,
                            isSelected: _selectedIndex == 8,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 8);
                            },
                          ),
                          const SizedBox(height: 24),
                          _drawerSectionTitle(l10n.management.toUpperCase()),
                          _drawerItem(
                            Icons.people_outline_rounded,
                            l10n.manageOfficers,
                            isSelected: _selectedIndex == 5,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 5);
                            },
                          ),
                          _drawerItem(
                            Icons.category_outlined,
                            l10n.productCategories,
                            isSelected: _selectedIndex == 6,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 6);
                            },
                          ),
                          _drawerItem(
                            Icons.add_business_rounded,
                            l10n.registerNewShop,
                            onTap: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateDukaPage(),
                                ),
                              );
                              if (result == true) {
                                _loadInitialData(); // Refresh list if shop created
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          _drawerSectionTitle(l10n.profile.toUpperCase()),
                          _drawerItem(
                            Icons.person_outline_rounded,
                            l10n.profile,
                            isSelected: _selectedIndex == 4,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 4);
                            },
                          ),
                          _drawerItem(
                            Icons.settings_outlined,
                            l10n.settings,
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${l10n.settings}: ${l10n.featureComingSoon}",
                                  ),
                                ),
                              );
                            },
                          ),
                          _drawerItem(
                            Icons.help_center_outlined,
                            l10n.support,
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${l10n.support}: ${l10n.featureComingSoon}",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                    child: Column(
                      children: [
                        _drawerItem(
                          Icons.delete_forever_rounded,
                          "Delete Account",
                          color: Colors.redAccent.withOpacity(0.9),
                          onTap: _handleDeleteAccount,
                        ),
                        _drawerItem(
                          Icons.logout_rounded,
                          l10n.signOut,
                          color: Colors.redAccent.withOpacity(0.9),
                          onTap: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title, {
    Color color = Colors.white70,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF4BB4FF).withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected
                        ? const Color(0xFF4BB4FF).withOpacity(0.3)
                        : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF4BB4FF) : color,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white : color,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4BB4FF),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
              color: Colors.black.withOpacity(0.2), // Lighter glass effect
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  Icons.home_filled,
                  AppLocalizations.of(context)!.home,
                  0,
                ),
                _navItem(
                  Icons.storefront_rounded,
                  AppLocalizations.of(context)!.myShops,
                  1,
                ),
                _navItem(
                  Icons.receipt_long_rounded,
                  AppLocalizations.of(context)!.sales,
                  2,
                ),
                _navItem(
                  Icons.person_outline_rounded,
                  AppLocalizations.of(context)!.profile,
                  4,
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
              size: 18,
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.somethingWentWrong,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retryConnection),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedDate() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            "${AppLocalizations.of(context)!.serverSync}: ${_tenantData!['sync_date'] ?? 'Just now'}",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4BB4FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialGrid(
    Map<dynamic, dynamic> financials,
    BuildContext context,
  ) {
    var l10n = AppLocalizations.of(context)!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          l10n.totalSales,
          _formatCurrency(financials['total_sales']),
          Icons.trending_up_rounded,
          Colors.greenAccent,
        ),
        _buildStatCard(
          l10n.estProfit,
          _formatCurrency(financials['total_profit']),
          Icons.auto_graph_rounded,
          Colors.blueAccent,
        ),
        _buildStatCard(
          l10n.expenses,
          _formatCurrency(financials['total_expenses']),
          Icons.trending_down_rounded,
          Colors.orangeAccent,
        ),
        _buildStatCard(
          l10n.netIncome,
          _formatCurrency(financials['net_income']),
          Icons.account_balance_wallet_rounded,
          Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDukaCard(Map<dynamic, dynamic> duka) {
    final stats = duka['stats'];
    final todaySales =
        stats != null ? stats['today_sales'] : duka['today_sales'];
    final todayProfit =
        stats != null ? stats['today_profit'] : duka['today_profit'];
    final customerCount = stats != null ? stats['total_customers'] : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DukaDashboard(duka: duka)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF4BB4FF),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duka['name'] ?? 'Shop Name',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        duka['location'] ?? 'Location not set',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (customerCount != null || duka['sales_count'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          customerCount != null
                              ? Icons.people_outline_rounded
                              : Icons.receipt_long_rounded,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${customerCount ?? duka['sales_count'] ?? 0}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Colors.white10),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDukaMiniStat(
                    AppLocalizations.of(context)!.todaySales,
                    _formatCurrency(todaySales),
                    Icons.show_chart_rounded,
                    Colors.white70,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.white10),
                Expanded(
                  child: _buildDukaMiniStat(
                    AppLocalizations.of(context)!.todayProfit,
                    _formatCurrency(todayProfit),
                    Icons.trending_up_rounded,
                    const Color(0xFF4BB4FF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockCard(Map<String, dynamic> product) {
    // Determine status color based on quantity
    final quantity = product['total_bulk_quantity'] ?? 0;
    final isCritical = quantity <= 5;
    final color = isCritical ? Colors.redAccent : Colors.orangeAccent;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Unknown Product',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      product['category'] ?? 'Uncategorized',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '$quantity Units',
                    style: GoogleFonts.plusJakartaSans(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCritical ? 'CRITICAL' : 'LOW STOCK',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E), // Dark theme color
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          if (_lowStockProducts.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Notifications',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_lowStockProducts.length} New',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4BB4FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _lowStockProducts.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No new notifications',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _lowStockProducts.length,
                            itemBuilder: (context, index) {
                              final product = _lowStockProducts[index];
                              final quantity =
                                  product['total_bulk_quantity'] ?? 0;
                              final isCritical = quantity <= 5;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isCritical
                                            ? Colors.redAccent.withOpacity(0.3)
                                            : Colors.orangeAccent.withOpacity(
                                              0.3,
                                            ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isCritical
                                              ? Colors.redAccent
                                              : Colors.orangeAccent)
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color:
                                          isCritical
                                              ? Colors.redAccent
                                              : Colors.orangeAccent,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    product['name'] ?? 'Unknown',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Stock is running low: $quantity units remaining',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view details',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showProductLocationsDialog(product);
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  void _showProductLocationsDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stock Locations',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product: ${product['name']}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                // Locations List
                if (product['locations'] != null)
                  ...(product['locations'] as List).map<Widget>((loc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc['duka_name'] ?? 'Unknown Shop',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (loc['quantity'] ?? 0) <= 5
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : Colors.orangeAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${loc['quantity'] ?? 0} units',
                              style: GoogleFonts.plusJakartaSans(
                                color:
                                    (loc['quantity'] ?? 0) <= 5
                                        ? Colors.redAccent
                                        : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  Text(
                    'No location details available',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A2A47),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.selectLanguage,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLanguageOption(context, 'English', 'en', '🇬🇧'),
                _buildLanguageOption(context, 'Swahili', 'sw', '🇰🇪'),
                _buildLanguageOption(context, 'Français', 'fr', '🇫🇷'),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String name,
    String code,
    String flag,
  ) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isSelected = localeProvider.locale.languageCode == code;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(Icons.check_circle, color: Color(0xFF4BB4FF))
              : null,
      onTap: () {
        localeProvider.setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildDukaMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9, // Reduced font size
            color: Colors.white38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, // Reduced font size
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDukas() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          style: BorderStyle.none,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noShopActivity,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
