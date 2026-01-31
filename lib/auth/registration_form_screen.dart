import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart'; // Assuming you want to navigate to login or dashboard after success

class RegistrationFormScreen extends StatefulWidget {
  final int planId;
  final String planName;

  const RegistrationFormScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Colors
  final Color _primaryColor = const Color(0xFF4BB4FF);

  // Background Gradient
  final LinearGradient _backgroundGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF0F2744), Color(0xFF1A3A5C)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'plan_id': widget.planId,
      };

      final response = await _apiService.register(data);

      if (!mounted) return;

      // Show success message and navigate
      // Show success animation
      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      // Wait for animation then navigate
      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Complete Registration',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: _backgroundGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: _primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Plan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  widget.planName,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Text(
                        'Business Details',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        validator:
                            (v) =>
                                v?.isEmpty ?? true ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator:
                            (v) =>
                                v?.isEmpty ?? true
                                    ? 'Email is required'
                                    : !v!.contains('@')
                                    ? 'Invalid email'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _businessNameController,
                        label: 'Business Name',
                        icon: Icons.store_outlined,
                        validator:
                            (v) =>
                                v?.isEmpty ?? true
                                    ? 'Business Name is required'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              validator:
                                  (v) =>
                                      (v?.length ?? 0) < 8
                                          ? 'Min 8 chars'
                                          : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white54,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirmPassword,
                              validator:
                                  (v) =>
                                      v != _passwordController.text
                                          ? 'Mismatch'
                                          : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white54,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2962FF), Color(0xFF2979FF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2962FF).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Create Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Full-screen animated loader overlay
          if (_isLoading) _buildCreatingAccountLoader(),

          // Success Animation Overlay
          if (_showSuccess) _buildSuccessAnimation(),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0A1628).withOpacity(0.98),
      child: const _SuccessAnimationWidget(),
    );
  }

  Widget _buildCreatingAccountLoader() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0A1628).withOpacity(0.95),
      child: _AccountCreationLoaderWidget(
        primaryColor: _primaryColor,
        businessName: _businessNameController.text.trim(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
      ),
    );
  }
}

// Account Creation Animated Loader Widget
class _AccountCreationLoaderWidget extends StatefulWidget {
  final Color primaryColor;
  final String businessName;

  const _AccountCreationLoaderWidget({
    required this.primaryColor,
    required this.businessName,
  });

  @override
  State<_AccountCreationLoaderWidget> createState() =>
      _AccountCreationLoaderWidgetState();
}

class _AccountCreationLoaderWidgetState
    extends State<_AccountCreationLoaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;
  final List<String> _steps = [
    'Setting up your workspace',
    'Configuring business settings',
    'Creating your account',
    'Finalizing setup',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 6.28,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Cycle through steps
    _cycleSteps();
  }

  void _cycleSteps() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % _steps.length;
        });
      }
    }
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated pulsing rings with particles
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outermost ring
                  Transform.scale(
                    scale: 1.0 + (_pulseAnimation.value * 0.4),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.primaryColor.withOpacity(
                            0.2 * (1 - _pulseAnimation.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Middle ring
                  Transform.scale(
                    scale: 1.0 + (_pulseAnimation.value * 0.25),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.primaryColor.withOpacity(
                            0.4 * (1 - _pulseAnimation.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Rotating particles
                  Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        children: List.generate(8, (index) {
                          final angle = (index * 3.14159 * 2) / 8;
                          return Transform.translate(
                            offset: Offset(
                              60 *
                                  (1 + 0.1 * _scaleAnimation.value) *
                                  (angle == 0 ? 1 : (angle / 3.14159).abs()),
                              60 *
                                  (1 + 0.1 * _scaleAnimation.value) *
                                  ((angle - 1.5708) / 3.14159).abs(),
                            ),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.primaryColor.withOpacity(
                                  0.6 + 0.4 * _pulseAnimation.value,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.primaryColor.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Center icon
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            widget.primaryColor,
                            widget.primaryColor.withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Animated progress text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _steps[_currentStep],
                  key: ValueKey<int>(_currentStep),
                  style: GoogleFonts.plusJakartaSans(
                    color: widget.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Main loading text
              Text(
                'Creating Your Account',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Personalized message
              if (widget.businessName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Setting up ${widget.businessName}...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentStep == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color:
                          _currentStep == index
                              ? widget.primaryColor
                              : Colors.white.withOpacity(0.2),
                      boxShadow:
                          _currentStep == index
                              ? [
                                BoxShadow(
                                  color: widget.primaryColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                              : [],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tips
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Colors.amber.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This will only take a moment...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SuccessAnimationWidget extends StatefulWidget {
  const _SuccessAnimationWidget();

  @override
  State<_SuccessAnimationWidget> createState() =>
      _SuccessAnimationWidgetState();
}

class _SuccessAnimationWidgetState extends State<_SuccessAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.shade400,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 60 * _checkAnimation.value,
                        color: Colors.white,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _scaleAnimation,
            child: Column(
              children: [
                Text(
                  "Success!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your account has been created.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
