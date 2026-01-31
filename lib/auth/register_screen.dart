import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'registration_form_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _plans = [];
  String? _error;
  int? _selectedPlanId;

  // Colors
  final Color _primaryColor = const Color(0xFF4BB4FF); // Light Blue

  // Background Gradient
  final LinearGradient _backgroundGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF0F2744), Color(0xFF1A3A5C)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final response = await _apiService.getPlans();
      if (response['success'] == true) {
        setState(() {
          _plans = response['data'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load plans');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Choose Your Plan',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child:
              _isLoading
                  ? Center(child: _buildAnimatedLoader())
                  : _error != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red[300],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Oops! Something went wrong',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load subscription plans',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _fetchPlans();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: _primaryColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: GoogleFonts.plusJakartaSans(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Text(
                          'Select a plan that fits your business needs. You can upgrade or downgrade at any time.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          itemCount: _plans.length,
                          itemBuilder: (context, index) {
                            final plan = _plans[index];
                            return _buildPlanCard(plan);
                          },
                        ),
                      ),
                      _buildBottomBar(),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(dynamic plan) {
    final isSelected = _selectedPlanId == plan['id'];

    // Custom formatter for "8,000 TSH" format
    final currencyFormatter = NumberFormat("#,##0", "en_US");
    final double price = double.tryParse(plan['price'].toString()) ?? 0.0;
    final bool isFree = price == 0;

    // Gradient definitions
    final headerGradient =
        isFree
            ? const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)], // Green for free
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
            : LinearGradient(
              colors:
                  isSelected
                      ? [
                        const Color(0xFF2962FF),
                        const Color(0xFF448AFF),
                      ] // Blue for selected paid
                      : [
                        const Color(0xFF424242),
                        const Color(0xFF616161),
                      ], // Grey for unselected paid
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan['id'];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _primaryColor.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: headerGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan['name'],
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isFree)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Best for Starters',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.1),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color:
                                isSelected
                                    ? _primaryColor
                                    : Colors.white.withOpacity(0.5),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isFree
                              ? 'Free Forever'
                              : '${currencyFormatter.format(price)} TSH',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!isFree) ...[
                          const SizedBox(width: 4),
                          Text(
                            '/ ${plan['billing_cycle']}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Plan Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['description'] ?? 'Plan details',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'WHAT\'S INCLUDED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...((plan['features'] as List<dynamic>?) ?? []).map((
                      feature,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64FFDA).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Color(0xFF64FFDA),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature['name'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),

                    // Constraints with better icons
                    Row(
                      children: [
                        Expanded(
                          child: _buildConstraintItem(
                            Icons.storefront_rounded,
                            '${plan['max_dukas']}',
                            'Shops',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        Expanded(
                          child: _buildConstraintItem(
                            Icons.inventory_2_rounded,
                            '${plan['max_products']}',
                            'Products',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLoader() {
    return _AnimatedLoaderWidget(primaryColor: _primaryColor);
  }

  Widget _buildConstraintItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient:
                  _selectedPlanId == null
                      ? LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade900],
                      )
                      : const LinearGradient(
                        colors: [Color(0xFF2962FF), Color(0xFF2979FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
              boxShadow:
                  _selectedPlanId == null
                      ? []
                      : [
                        BoxShadow(
                          color: const Color(0xFF2962FF).withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
            ),
            child: ElevatedButton(
              onPressed:
                  _selectedPlanId == null
                      ? null
                      : () {
                        final selectedPlan = _plans.firstWhere(
                          (p) => p['id'] == _selectedPlanId,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RegistrationFormScreen(
                                  planId: _selectedPlanId!,
                                  planName: selectedPlan['name'],
                                ),
                          ),
                        );
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledForegroundColor: Colors.white.withOpacity(0.3),
                disabledBackgroundColor: Colors.transparent,
              ),
              child:
                  _selectedPlanId == null
                      ? Text(
                        'Select a plan to continue',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Loader Widget with continuous animation
class _AnimatedLoaderWidget extends StatefulWidget {
  final Color primaryColor;

  const _AnimatedLoaderWidget({required this.primaryColor});

  @override
  State<_AnimatedLoaderWidget> createState() => _AnimatedLoaderWidgetState();
}

class _AnimatedLoaderWidgetState extends State<_AnimatedLoaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(); // Repeat infinitely

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 6.28,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated pulsing circles
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing circle
                Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.3),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(
                          0.3 * (1 - _pulseAnimation.value),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Middle pulsing circle
                Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.2),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(
                          0.5 * (1 - _pulseAnimation.value),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Rotating inner container
                Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor,
                          widget.primaryColor.withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Animated text with fade-in
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeIn,
              builder: (context, textValue, child) {
                return Opacity(
                  opacity: textValue,
                  child: Column(
                    children: [
                      Text(
                        'Loading Plans...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preparing the best options for you',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
