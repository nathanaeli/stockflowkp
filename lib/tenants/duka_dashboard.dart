import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/tenants/duka_products_page.dart';
import 'package:stockflowkp/tenants/sales_page.dart';
import 'dart:ui';

class DukaDashboard extends StatefulWidget {
  final Map<dynamic, dynamic> duka;

  const DukaDashboard({super.key, required this.duka});

  @override
  State<DukaDashboard> createState() => _DukaDashboardState();
}

class _DukaDashboardState extends State<DukaDashboard> {
  int _selectedIndex = 0;

  // Helper for currency formatting
  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(symbol: 'Tsh ', decimalDigits: 0);
    return formatter.format(amount ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final duka = widget.duka;
    final stats = duka['stats'] ?? {};
    final todaySales = stats['today_sales'] ?? duka['today_sales'] ?? 0;
    final todayProfit = stats['today_profit'] ?? duka['today_profit'] ?? 0;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(
                  Icons.menu_rounded, // Changed to menu icon for drawer
                  color: Colors.white,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: Text(
          duka['name'] ?? 'Shop Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: const [],
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _buildContentForIndex(
                  _selectedIndex,
                  duka,
                  l10n,
                  todaySales,
                  todayProfit,
                  stats,
                ),
              ),
            ),
          ),

          _buildFloatingBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(
    int index,
    Map duka,
    AppLocalizations l10n,
    dynamic todaySales,
    dynamic todayProfit,
    Map stats,
  ) {
    switch (index) {
      case 0:
        return _buildOverview(duka, l10n, todaySales, todayProfit, stats);
      case 1:
        return DukaProductsPage(dukaId: duka['id'], dukaName: duka['name']);
      case 2:
        return SalesPage(dukaId: duka['id']);
      default:
        return _buildOverview(duka, l10n, todaySales, todayProfit, stats);
    }
  }

  Widget _buildOverview(
    Map duka,
    AppLocalizations l10n,
    dynamic todaySales,
    dynamic todayProfit,
    Map stats,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 32,
                    color: Color(0xFF4BB4FF),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duka['name'] ?? 'Shop Name',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duka['location'] ?? 'Location not available',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (duka['status'] == 'active'
                            ? Colors.greenAccent
                            : Colors.grey)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (duka['status'] == 'active'
                              ? Colors.greenAccent
                              : Colors.grey)
                          .withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    (duka['status'] ?? 'Active').toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          duka['status'] == 'active'
                              ? Colors.greenAccent
                              : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(l10n.performanceToday, Icons.insights_rounded),
          const SizedBox(height: 16),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildDetailStatCard(
                l10n.todaySales,
                _formatCurrency(todaySales),
                Icons.payments_outlined,
                Colors.greenAccent,
              ),
              _buildDetailStatCard(
                l10n.todayProfit,
                _formatCurrency(todayProfit),
                Icons.trending_up_rounded,
                const Color(0xFF4BB4FF),
              ),
              if (stats['total_customers'] != null)
                _buildDetailStatCard(
                  l10n.customers,
                  "${stats['total_customers']}",
                  Icons.people_outline_rounded,
                  Colors.orangeAccent,
                ),
              if (stats['total_products_in_stock'] != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: _buildDetailStatCard(
                    l10n.stockCount,
                    "${stats['total_products_in_stock']}",
                    Icons.inventory_2_outlined,
                    Colors.purpleAccent,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(
            l10n.management,
            Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 16),

          // Management Actions Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildActionCard(
                'Back to Main',
                Icons.dashboard_customize_outlined,
                Colors.orangeAccent,
                () => Navigator.pop(context),
              ),
              _buildActionCard(
                l10n.viewFullReport,
                Icons.analytics_outlined,
                Colors.blueAccent,
                () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildProfileItem(
                  Icons.person_outline,
                  "Manager",
                  duka['manager'] ?? 'Not Assigned',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Colors.white10),
                ),
                _buildProfileItem(
                  Icons.calendar_today_rounded,
                  l10n.created,
                  duka['created_at'] != null
                      ? DateFormat.yMMMd().format(
                        DateTime.parse(duka['created_at']),
                      )
                      : 'N/A',
                ),
              ],
            ),
          ),
        ],
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
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Colors.orangeAccent,
                      ),
                      title: Text(
                        'Main Dashboard',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close Drawer
                        Navigator.pop(context); // Go back to TenantDashboard
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  _drawerItem(
                    Icons.dashboard_rounded,
                    'Shop Overview',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 0);
                    },
                  ),
                  _drawerItem(
                    Icons.inventory_2_rounded,
                    'Products',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 1);
                    },
                  ),
                  _drawerItem(
                    Icons.receipt_long_rounded,
                    'Sales History',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 2);
                    },
                  ),
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                  ),
                ),
                _navItem(Icons.dashboard_rounded, 'Overview', 0),
                _navItem(Icons.inventory_2_rounded, 'Products', 1),
                _navItem(Icons.receipt_long_rounded, 'Sales', 2),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4BB4FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
