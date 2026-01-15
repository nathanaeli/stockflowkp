import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class HowToUsePage extends StatefulWidget {
  const HowToUsePage({super.key});

  @override
  State<HowToUsePage> createState() => _HowToUsePageState();
}

class _HowToUsePageState extends State<HowToUsePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _openPDF() async {
    try {
      final byteData = await rootBundle.load('assets/user_manual.pdf');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/StockflowKP_User_Manual.pdf');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open PDF. Please ensure the file exists.')),
      );
    }
  }

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to StockflowKP',
      'description': 'Your comprehensive inventory and sales management platform. Let\'s get you started with the basics.',
      'icon': Icons.waving_hand_rounded,
      'color': const Color(0xFF4BB4FF),
    },
    {
      'title': 'Dashboard Overview',
      'description': 'Access your dashboard to view today\'s sales, pending syncs, and quick actions. Use the menu button to open the navigation drawer.',
      'icon': Icons.dashboard_rounded,
      'color': Colors.lightGreenAccent,
    },
    {
      'title': 'Managing Products',
      'description': 'Add, edit, and organize your products. Use the Products section to maintain your inventory with categories and pricing.',
      'icon': Icons.inventory_2_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'title': 'Creating Sales',
      'description': 'Process sales efficiently. Select products, calculate totals, and complete transactions. Sales sync automatically when online.',
      'icon': Icons.point_of_sale_rounded,
      'color': Colors.purpleAccent,
    },
    {
      'title': 'Customer Management',
      'description': 'Keep track of your customers. Add new clients, view their purchase history, and manage relationships.',
      'icon': Icons.people_alt_rounded,
      'color': Colors.pinkAccent,
    },
    {
      'title': 'Sales Analytics',
      'description': 'Monitor your business performance. View sales trends, reports, and analytics to make informed decisions.',
      'icon': Icons.bar_chart_rounded,
      'color': Colors.tealAccent,
    },
    {
      'title': 'Proforma Invoices',
      'description': 'Create and manage proforma invoices. Generate quotes and convert them to actual sales when ready.',
      'icon': Icons.request_quote_rounded,
      'color': Colors.cyanAccent,
    },
    {
      'title': 'Sync & Offline Mode',
      'description': 'Work offline and sync when connected. Your data is automatically backed up and synchronized with the cloud.',
      'icon': Icons.cloud_sync_rounded,
      'color': Colors.blueGrey,
    },
    {
      'title': 'Support & Help',
      'description': 'Need assistance? Use the Support section to contact our team or access additional resources.',
      'icon': Icons.help_center_rounded,
      'color': Colors.redAccent,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'How to Use',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPDF,
        backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.8),
        tooltip: 'View User Manual PDF',
        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
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
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return _buildStepPage(_steps[index]);
                  },
                ),
              ),
              _buildPageIndicator(),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepPage(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: step['color'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(
                color: step['color'].withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              step['icon'],
              size: 60,
              color: step['color'],
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            step['title'],
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Description
          Text(
            step['description'],
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _steps.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? const Color(0xFF4BB4FF)
                  : Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            _buildGlassButton(
              'Previous',
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            )
          else
            const SizedBox(width: 100),

          if (_currentPage < _steps.length - 1)
            _buildGlassButton(
              'Next',
              onTap: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            )
          else
            _buildGlassButton(
              'Get Started',
              onTap: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}