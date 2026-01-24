import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/auth/login_screen.dart';
import 'package:stockflowkp/auth/register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.onLanguageChange,
    required this.currentLocale,
  });

  final void Function(Locale) onLanguageChange;
  final Locale currentLocale;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _floatingController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;

  // Translation maps
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'title': 'StockFlow KP',
      'subtitle': 'Streamline Your Inventory Management',
      'login': 'Get Started',
      'register': 'Create Account',
      'footer': 'Inventory management made simple',
      'efficient': 'Efficient',
      'reliable': 'Reliable',
      'smart': 'Smart',
      'selectLanguage': 'Select Language',
      'english': 'English',
      'swahili': 'Swahili',
      'french': 'French',
    },
    'sw': {
      'title': 'StockFlow KP',
      'subtitle': 'Rahisisha Usimamizi wa Mizigo',
      'login': 'Anza',
      'register': 'Unda Akaunti',
      'footer': 'Usimamizi wa mizigo umefanywa rahisi',
      'efficient': 'Thabiti',
      'reliable': 'Vinavyotegemewa',
      'smart': 'Mahiri',
      'selectLanguage': 'Chagua Lugha',
      'english': 'Kiingereza',
      'swahili': 'Kiswahili',
      'french': 'Kifaransa',
    },
    'fr': {
      'title': 'StockFlow KP',
      'subtitle': 'Optimisez la Gestion de Votre Inventaire',
      'login': 'Commencer',
      'register': 'Créer un Compte',
      'footer': 'La gestion d\'inventaire simplifiée',
      'efficient': 'Efficace',
      'reliable': 'Fiable',
      'smart': 'Intelligent',
      'selectLanguage': 'Sélectionner la Langue',
      'english': 'Anglais',
      'swahili': 'Swahili',
      'french': 'Français',
    },
  };

  String get _currentLanguage => widget.currentLocale.languageCode;

  String get _t => _translations[_currentLanguage]?[_currentLanguage] ?? '';

  String translate(String key) {
    return _translations[_currentLanguage]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Pulse animation for logo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Floating animation for background elements
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
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // Prevents back navigation
      child: Scaffold(
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
              // Animated background particles
              ...List.generate(
                15,
                (index) => _buildFloatingParticle(index, size),
              ),

              // Premium Gradient orbs
              _buildGradientOrb(
                top: size.height * 0.1,
                left: -100,
                color: const Color(0xFF4BB4FF).withOpacity(0.15),
                size: 300,
              ),
              _buildGradientOrb(
                top: size.height * 0.6,
                right: -80,
                color: const Color(0xFF6C63FF).withOpacity(0.12),
                size: 250,
              ),

              // Main content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Spacer(flex: 2),
                          // Animated Logo Area
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/favicon.ico',
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // App Title with premium gradient
                          ShaderMask(
                            shaderCallback:
                                (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFF4BB4FF)],
                                ).createShader(bounds),
                            child: Text(
                              translate('title'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tagline
                          Text(
                            translate('subtitle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.75),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Features row with glassomorphism
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFeatureChip(
                                    translate('efficient'),
                                    Icons.speed_rounded,
                                  ),
                                  _buildDivider(),
                                  _buildFeatureChip(
                                    translate('reliable'),
                                    Icons.verified_rounded,
                                  ),
                                  _buildDivider(),
                                  _buildFeatureChip(
                                    translate('smart'),
                                    Icons.auto_awesome_rounded,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),

                          // Login Button (Primary Action)
                          _buildPrimaryButton(
                            label: translate('login'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Register Button (Secondary Action)
                          _buildSecondaryButton(
                            label: translate('register'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Footer text
                          Text(
                            translate('footer'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Language button (Top Right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 20,
                child: _buildLanguageButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 14,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildFloatingParticle(int index, Size size) {
    final random = Random(index);
    final startX = random.nextDouble() * size.width;
    final startY = random.nextDouble() * size.height;
    final particleSize = 2.0 + random.nextDouble() * 4;

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
              color: Colors.white.withOpacity(0.1 + random.nextDouble() * 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOrb({
    double? top,
    double? left,
    double? right,
    required Color color,
    required double size,
  }) {
    return Positioned(
      top: top,
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

  Widget _buildFeatureChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF4BB4FF)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5EC8FF), Color(0xFF4BB4FF), Color(0xFF2D9CDB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4BB4FF).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
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
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.02),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.language_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _showLanguageDialog,
            tooltip: 'Change Language',
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2744),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  translate('selectLanguage'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                _buildLanguageOption(translate('english'), 'en', '🇬🇧'),
                _buildLanguageOption(translate('swahili'), 'sw', '🇹🇿'),
                _buildLanguageOption(translate('french'), 'fr', '🇫🇷'),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(String name, String code, String flag) {
    final isSelected = widget.currentLocale.languageCode == code;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFF4BB4FF).withOpacity(0.1)
                : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? const Color(0xFF4BB4FF).withOpacity(0.5)
                  : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Text(flag, style: const TextStyle(fontSize: 28)),
        title: Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing:
            isSelected
                ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4BB4FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                )
                : null,
        onTap: () {
          widget.onLanguageChange(Locale(code));
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
