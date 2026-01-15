import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/shared_preferences_service.dart';
import 'duka_details_page.dart';

class TenantPage extends StatefulWidget {
  const TenantPage({Key? key}) : super(key: key);

  @override
  State<TenantPage> createState() => _TenantPageState();
}

class _TenantPageState extends State<TenantPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _tenantData;
  Map<String, dynamic>? _tenantAccountData;
  List<dynamic>? _officers;
  String? _error;
  late SharedPreferencesService _prefsService;
  late NumberFormat _currencyFormat;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _fetchTenantDetails();
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _setupCurrencyFormatter();
  }

  void _setupCurrencyFormatter() {
    final currency = _prefsService.getCurrency();
    // Create locale based on currency (fallback to en_US)
    String locale = 'en_US';
    if (currency == 'KES') {
      locale = 'en_KE';
    } else if (currency == 'USD') {
      locale = 'en_US';
    } else if (currency == 'EUR') {
      locale = 'de_DE';
    } else if (currency == 'GBP') {
      locale = 'en_GB';
    }
    
    _currencyFormat = NumberFormat('#,##0.00', locale);
  }

  Future<void> _fetchTenantDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      final token = userData['data']['token'];
      if (token == null) {
        throw Exception('Token not found');
      }

      final apiService = ApiService();
      final response = await apiService.getTenantDetails(token);

      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _tenantData = response['data'];
          _isLoading = false;
        });
        // Fetch additional data for other tabs
        _fetchOfficers(token);
        // Fetch tenant account information
        _fetchTenantAccount(token);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch tenant details');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTenantAccount(String token) async {
    try {
      final apiService = ApiService();
      final response = await apiService.getTenantAccount(token);
      
      if (!mounted) return;
      if (response['success'] == true) {
        final accountData = response['data'];
        setState(() {
          _tenantAccountData = accountData;
        });
        
        // Save to shared preferences
        await _prefsService.saveTenantAccount(accountData);
        
        // Update currency formatter if currency changed
        _setupCurrencyFormatter();
      }
    } catch (e) {
      print('Error fetching tenant account: $e');
      // Don't show error to user for account data, just log it
    }
  }

  Future<void> _fetchOfficers(String token) async {
    try {
      final apiService = ApiService();
      final response = await apiService.getOfficers(token);
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _officers = response['data']['officers'];
        });
      }
    } catch (e) {
      print('Error fetching officers: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        title: Text(
          'Tenant Dashboard',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF0A1B32).withOpacity(0.5),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withOpacity(0.8)),
                          const SizedBox(height: 16),
                          Text('Error: $_error', style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchTenantDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _buildBody(),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDrawer() {
    final tenant = _tenantData?['tenant'];
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4BB4FF), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: Text(
                        (tenant?['name'] ?? 'T').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant?['name'] ?? 'Tenant',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tenant?['email'] ?? 'tenant@example.com',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', true, () => Navigator.pop(context)),
                  _buildDrawerItem(Icons.person_rounded, 'Profile', false, () {}),
                  _buildDrawerItem(Icons.settings_rounded, 'Settings', false, () {}),
                  _buildDrawerItem(Icons.help_rounded, 'Help & Support', false, () {}),
                ],
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDrawerItem(
                Icons.logout_rounded,
                'Logout',
                false,
                () {
                  Navigator.pop(context); // Close drawer
                  Navigator.pop(context); // Go back
                },
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildDukasTab();
      case 2:
        return _buildOfficersTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B32),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4BB4FF),
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'Dukas'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Officers'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4BB4FF).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: color ?? (isSelected ? const Color(0xFF4BB4FF) : Colors.white70),
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? (isSelected ? Colors.white : Colors.white70),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_tenantData == null) return const SizedBox();

    final tenant = _tenantData!['tenant'];
    final dukas = _tenantData!['dukas'] as List<dynamic>;
    final summary = _tenantData!['summary'];

    return RefreshIndicator(
      onRefresh: _fetchTenantDetails,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        children: [
          // Tenant Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4BB4FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business_rounded, color: Color(0xFF4BB4FF), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant['name'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            tenant['email'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (tenant['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (tenant['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.5)),
                      ),
                      child: Text(
                        (tenant['status'] ?? 'N/A').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: tenant['status'] == 'active' ? Colors.green : Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.phone_rounded, tenant['phone'] ?? 'N/A'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on_rounded, tenant['address'] ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildSummaryCard(
                'Total Dukas',
                summary['total_dukas'].toString(),
                Icons.store_rounded,
                const Color(0xFF4BB4FF),
              ),
              _buildSummaryCard(
                'Total Revenue',
                '${_formatCurrency(summary['total_sales_revenue'])}',
                Icons.attach_money_rounded,
                Colors.greenAccent,
              ),
              _buildSummaryCard(
                'Today\'s Revenue',
                '${_formatCurrency(summary['today_total_revenue'])}',
                Icons.today_rounded,
                Colors.orangeAccent,
              ),
              _buildSummaryCard(
                'Total Profit/Loss',
                '${_formatCurrency(summary['total_profit_loss'])}',
                Icons.trending_up_rounded,
                Colors.purpleAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dukas List
          Text(
            'Your Dukas (${dukas.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...dukas.map((duka) => _buildDukaCard(duka)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.white60,
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
    );
  }

  Widget _buildDukaCard(dynamic duka) {
    final summary = duka['summary'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DukaDetailsPage(duka: Map<String, dynamic>.from(duka)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4BB4FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: Color(0xFF4BB4FF), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duka['name'] ?? 'N/A',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${duka['location'] ?? 'N/A'} • Manager: ${duka['manager_name'] ?? 'N/A'}',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMiniStat('Revenue', _formatCurrency(summary['total_revenue'])),
                      const SizedBox(width: 16),
                      _buildMiniStat('Today', summary['today_sales_count'].toString()),
                      const SizedBox(width: 16),
                      _buildMiniStat('Loans', summary['total_loans'].toString()),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(dynamic value) {
    final doubleVal = double.tryParse(value?.toString() ?? '0') ?? 0;
    final formattedValue = _currencyFormat.format(doubleVal);
    final currency = _prefsService.getCurrency();
    
    // Return formatted value with currency symbol or code
    if (currency == 'KES') {
      return '$formattedValue';
    } else if (currency == 'USD') {
      return '\$formattedValue';
    } else if (currency == 'EUR') {
      return '€$formattedValue';
    } else if (currency == 'GBP') {
      return '£$formattedValue';
    } else {
      // Default: show currency code before amount
      return '$currency $formattedValue';
    }
  }

  Widget _buildDukasTab() {
    if (_tenantData == null) return const SizedBox();

    final dukas = _tenantData!['dukas'] as List<dynamic>;

    return RefreshIndicator(
      onRefresh: _fetchTenantDetails,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Dukas (${dukas.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateDukaDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Duka'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...dukas.map((duka) => _buildDukaManagementCard(duka)),
        ],
      ),
    );
  }

  Widget _buildOfficersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final dbService = DatabaseService();
        final userData = await dbService.getUserData();
        if (userData != null) {
          final token = userData['data']['token'];
          await _fetchOfficers(token);
          await _fetchTenantAccount(token); // Also refresh account data
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Officers (${_officers?.length ?? 0})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateOfficerDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Officer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_officers != null)
            ..._officers!.map((officer) => _buildOfficerCard(officer))
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))),
        ],
      ),
    );
  }


  Widget _buildDukaManagementCard(dynamic duka) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DukaDetailsPage(duka: Map<String, dynamic>.from(duka)),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.store, color: Color(0xFF4BB4FF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duka['name'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          duka['location'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleDukaAction(value, duka),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Text('View Details')),
                      const PopupMenuItem(value: 'plan', child: Text('View Plan')),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficerCard(dynamic officer) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF4BB4FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officer['name'] ?? 'N/A',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        officer['email'] ?? 'N/A',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        'Role: ${officer['assignment']['role'] ?? 'N/A'}',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        'Duka: ${officer['assignment']['duka_name'] ?? 'N/A'}',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (officer['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (officer['status'] ?? 'N/A').toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: officer['status'] == 'active' ? Colors.green : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleOfficerAction(value, officer),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  void _handleDukaAction(String action, dynamic duka) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DukaDetailsPage(duka: Map<String, dynamic>.from(duka)),
          ),
        );
        break;
      case 'plan':
        _showDukaPlanDialog(duka);
        break;
    }
  }

  void _handleOfficerAction(String action, dynamic officer) {
    switch (action) {
      case 'edit':
        _showEditOfficerDialog(officer);
        break;
      case 'delete':
        _showDeleteOfficerDialog(officer);
        break;
    }
  }

  void _showCreateDukaDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final managerController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    String status = 'active';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1B32),
          title: Text(
            'Create New Duka',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Duka Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: managerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Manager Name (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latitudeController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Latitude (Optional)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: longitudeController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Longitude (Optional)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: status,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF0A1B32),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) => setState(() => status = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty || locationController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name and location are required')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final dbService = DatabaseService();
                        final userData = await dbService.getUserData();
                        if (userData == null) throw Exception('User data not found');

                        final token = userData['data']['token'];
                        final apiService = ApiService();

                        final dukaData = {
                          'name': nameController.text,
                          'location': locationController.text,
                          'manager_name': managerController.text.isNotEmpty ? managerController.text : null,
                          'latitude': latitudeController.text.isNotEmpty ? double.parse(latitudeController.text) : null,
                          'longitude': longitudeController.text.isNotEmpty ? double.parse(longitudeController.text) : null,
                          'status': status,
                        };

                        final response = await apiService.createDuka(dukaData, token);

                        if (response['success'] == true) {
                          Navigator.pop(context);
                          _fetchTenantDetails(); // Refresh data
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Duka created successfully')),
                          );
                        } else {
                          throw Exception(response['message']);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOfficerDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final roleController = TextEditingController();
    int? selectedDukaId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1B32),
          title: Text(
            'Create New Officer',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedDukaId,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF0A1B32),
                  decoration: InputDecoration(
                    labelText: 'Assign to Duka',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: (_tenantData?['dukas'] as List<dynamic>?)?.map((duka) {
                    return DropdownMenuItem<int>(
                      value: duka['id'],
                      child: Text(duka['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedDukaId = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Role (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          passwordController.text.isEmpty ||
                          selectedDukaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name, email, password, and duka assignment are required')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final dbService = DatabaseService();
                        final userData = await dbService.getUserData();
                        if (userData == null) throw Exception('User data not found');

                        final token = userData['data']['token'];
                        final apiService = ApiService();

                        final officerData = {
                          'name': nameController.text,
                          'email': emailController.text,
                          'phone': phoneController.text.isNotEmpty ? phoneController.text : null,
                          'duka_id': selectedDukaId,
                          'password': passwordController.text,
                          'role': roleController.text.isNotEmpty ? roleController.text : 'officer',
                        };

                        final response = await apiService.createOfficer(officerData, token);

                        if (response['success'] == true) {
                          Navigator.pop(context);
                          final token = userData['data']['token'];
                          _fetchOfficers(token); // Refresh officers list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Officer created successfully')),
                          );
                        } else {
                          throw Exception(response['message']);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOfficerDialog(dynamic officer) {
    final nameController = TextEditingController(text: officer['name']);
    final emailController = TextEditingController(text: officer['email']);
    final phoneController = TextEditingController(text: officer['phone']);
    final roleController = TextEditingController(text: officer['assignment']['role']);
    int? selectedDukaId = officer['assignment']['duka_id'];
    bool status = officer['status'] == 'active';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1B32),
          title: Text(
            'Edit Officer',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedDukaId,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF0A1B32),
                  decoration: InputDecoration(
                    labelText: 'Assign to Duka',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: (_tenantData?['dukas'] as List<dynamic>?)?.map((duka) {
                    return DropdownMenuItem<int>(
                      value: duka['id'],
                      child: Text(duka['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedDukaId = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active Status', style: TextStyle(color: Colors.white)),
                  value: status,
                  onChanged: (value) => setState(() => status = value),
                  activeColor: const Color(0xFF4BB4FF),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          selectedDukaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name, email, and duka assignment are required')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final dbService = DatabaseService();
                        final userData = await dbService.getUserData();
                        if (userData == null) throw Exception('User data not found');

                        final token = userData['data']['token'];
                        final apiService = ApiService();

                        final officerData = {
                          'name': nameController.text,
                          'email': emailController.text,
                          'phone': phoneController.text.isNotEmpty ? phoneController.text : null,
                          'duka_id': selectedDukaId,
                          'role': roleController.text.isNotEmpty ? roleController.text : null,
                          'status': status,
                        };

                        final response = await apiService.updateOfficer(officer['id'], officerData, token);

                        if (response['success'] == true) {
                          Navigator.pop(context);
                          final token = userData['data']['token'];
                          _fetchOfficers(token); // Refresh officers list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Officer updated successfully')),
                          );
                        } else {
                          throw Exception(response['message']);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteOfficerDialog(dynamic officer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1B32),
        title: Text(
          'Delete Officer',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${officer['name']}? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                final dbService = DatabaseService();
                final userData = await dbService.getUserData();
                if (userData == null) throw Exception('User data not found');

                final token = userData['data']['token'];
                final apiService = ApiService();

                final response = await apiService.deleteOfficer(officer['id'], token);

                if (response['success'] == true) {
                  _fetchOfficers(token); // Refresh officers list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Officer removed successfully')),
                  );
                } else {
                  throw Exception(response['message']);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  void _showDukaPlanDialog(dynamic duka) async {
    try {
      final dbService = DatabaseService();
      final userData = await dbService.getUserData();
      if (userData == null) throw Exception('User data not found');

      final token = userData['data']['token'];
      final apiService = ApiService();

      final response = await apiService.getDukaPlan(token, duka['id']);

      if (response['success'] == true) {
        final plan = response['data']['plan'];
        final dukaInfo = response['data']['duka'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            title: Text(
              'Plan for ${dukaInfo['name']}',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Plan',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['name'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan['description'] ?? 'N/A',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(plan['price']),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Duration',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${plan['duration_days']?.toString() ?? 'N/A'} days',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Features',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (plan['features'] as List<dynamic>?)?.map((feature) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4BB4FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                              ),
                              child: Text(
                                feature.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF4BB4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList() ?? [],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      } else {
        throw Exception(response['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading plan: $e')),
      );
    }
  }
}
