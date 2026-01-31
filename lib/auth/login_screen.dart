import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockflowkp/tenants/TenantDashboard.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../officer/officer_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showSuccess = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Animation controllers for background effects
  late AnimationController _fadeController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Floating background animation
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _floatingAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_floatingController);
    _floatingController.repeat();

    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _emailController.text = prefs.getString('saved_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final response = await apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }

      final dbService = DatabaseService();
      await dbService.saveUserData(response);

      final role = response['data']['user']['role'];
      if (role == 'officer' || role == 'tenant') {
        await dbService.saveCategoriesAndPermissions(response);
      }

      if (!mounted) return;

      // Show success animation
      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      // Wait for animation then navigate
      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      if (role == 'officer') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OfficerHome()),
        );
      } else if (role == 'tenant') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TenantDashboard()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _shakeController.forward(from: 0.0);
      final errorMessage = e.toString().replaceAll(
        RegExp(r'Exception:\s*'),
        '',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: const Color(0xFF0F2744).withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  title: Text(
                    'Forgot Password',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter your email to get a password reset link.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          'Email',
                          Icons.email_rounded,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                final email = emailController.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter your email'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => isLoading = true);
                                try {
                                  final apiService = ApiService();
                                  final response = await apiService
                                      .forgotPassword(email);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response['message'] ??
                                            'Reset link sent',
                                      ),
                                      backgroundColor:
                                          response['success'] == true
                                              ? Colors.green
                                              : Colors.redAccent,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => isLoading = false);
                                  }
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          isLoading
                              ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Send Link'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.1),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628), // Deep Dark Blue
              Color(0xFF0F2744), // Slightly lighter blue
              Color(0xFF1A3A5C), // Premium blue accent
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background particles
            ...List.generate(
              15,
              (index) => _buildFloatingParticle(index, size),
            ),

            // Gradient orbs
            _buildGradientOrb(
              top: -50,
              right: -50,
              color: const Color(0xFF4BB4FF).withOpacity(0.1),
              size: 300,
            ),
            _buildGradientOrb(
              bottom: 50,
              left: -80,
              color: const Color(0xFF6C63FF).withOpacity(0.08),
              size: 250,
            ),

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Logo / Header
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            height: 80,
                            width: 80,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4BB4FF,
                                  ).withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/favicon.ico',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          localizations.appTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Login Form Container
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                      ),
                                      decoration: _inputDecoration(
                                        localizations.email,
                                        Icons.email_rounded,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        if (!RegExp(
                                          r'^[^@]+@[^@]+\.[^@]+',
                                        ).hasMatch(value)) {
                                          return 'Please enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                      ),
                                      decoration: _inputDecoration(
                                        localizations.password,
                                        Icons.lock_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged:
                                                    (value) => setState(
                                                      () =>
                                                          _rememberMe =
                                                              value ?? false,
                                                    ),
                                                fillColor:
                                                    WidgetStateProperty.resolveWith(
                                                      (states) {
                                                        if (states.contains(
                                                          WidgetState.selected,
                                                        )) {
                                                          return const Color(
                                                            0xFF4BB4FF,
                                                          );
                                                        }
                                                        return Colors
                                                            .transparent;
                                                      },
                                                    ),
                                                side: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  width: 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Remember Me',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: _forgotPassword,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Forgot Password?',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF4BB4FF),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF5EC8FF),
                                            Color(0xFF4BB4FF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF4BB4FF,
                                            ).withOpacity(0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        onPressed: _isLoading ? null : _login,
                                        child:
                                            _isLoading
                                                ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                )
                                                : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      localizations.login,
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ),
                                  ],
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

            // Success Animation Overlay
            if (_showSuccess)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: const Color(0xFF0A1628).withOpacity(0.98),
                child: const _SuccessAnimationWidget(),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: Color(0xFF4BB4FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildFloatingParticle(int index, Size size) {
    final random = Random(index);
    final startX = random.nextDouble() * size.width;
    final startY = random.nextDouble() * size.height;
    final particleSize = 2.0 + random.nextDouble() * 3;

    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        final offset = sin((_floatingAnimation.value * 2 * pi) + index) * 20;
        return Positioned(
          left: startX,
          top: startY + offset,
          child: Container(
            width: particleSize,
            height: particleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1 + random.nextDouble() * 0.15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOrb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    required double size,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.2, 1.0],
          ),
        ),
      ),
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
                  "Welcome Back!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Logging you in safely...",
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
