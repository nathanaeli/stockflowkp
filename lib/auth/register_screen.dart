import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerNameController = TextEditingController();
  
  bool _obscureText = true;
  int _currentStep = 0;
  bool _isLoading = false;
  
  // API Data
  List<dynamic> _plans = [];
  dynamic _selectedPlan;
  String _selectedBillingCycle = 'monthly';
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _floatController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  
  // Translation maps
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'title': 'Create Account - Step',
      'choosePlan': 'Choose Your Plan',
      'choosePlanSubtitle': 'Select the plan that best fits your business needs',
      'personalInfo': 'Personal Information',
      'personalInfoSubtitle': 'Tell us about yourself',
      'businessSetup': 'Business Setup',
      'businessSetupSubtitle': 'Tell us about your business',
      'subscriptionDetails': 'Subscription Details',
      'subscriptionDetailsSubtitle': 'Choose your billing cycle',
      'fullName': 'Full Name',
      'email': 'Email',
      'password': 'Password',
      'shopName': 'Shop Name',
      'location': 'Location',
      'managerName': 'Manager Name',
      'next': 'Next',
      'back': 'Back',
      'completeRegistration': 'Complete Registration',
      'loading': 'Loading...',
      'popular': 'Most Popular',
      'bestValue': 'Best Value',
      'save': 'Save',
      'monthly': 'Monthly',
      'quarterly': 'Quarterly',
      'annually': 'Annually',
      'triannual': '3 Years',
      'billingCycles': 'Billing Cycles',
      'selectedPlan': 'Selected Plan',
      'basePrice': 'Base Price',
      'totalSavings': 'Total Savings',
      'discountApplied': 'Discount Applied',
      'monthlyPrice': 'Monthly Price',
      'billing': 'Billing',
      'success': 'Success!',
      'successMessage': 'Your account has been created successfully. Please check your email for verification.',
      'error': 'Error',
      'ok': 'OK',
      'month': 'month',
      'months': 'months',
      'year': 'year',
      'years': 'years',
      'planFeatures': 'Plan Features',
      'maxDukas': 'Max Dukas',
      'maxProducts': 'Max Products',
      'recommended': 'Recommended',
    },
    'sw': {
      'title': 'Unda Akaunti - Hatua',
      'choosePlan': 'Chagua Mpango Wako',
      'choosePlanSubtitle': 'Chagua mpango unaofaa zaidi na mahitaji ya biashara yako',
      'personalInfo': 'Maelezo ya Binafsi',
      'personalInfoSubtitle': 'Tuambie kukusaidia',
      'businessSetup': 'Utangulizi wa Biashara',
      'businessSetupSubtitle': 'Tuambie kuhusu biashara yako',
      'subscriptionDetails': 'Maelezo ya Usajili',
      'subscriptionDetailsSubtitle': 'Chagua mzunguko wa kulipa',
      'fullName': 'Jina Kamili',
      'email': 'Barua pepe',
      'password': 'Nenosiri',
      'shopName': 'Jina la Duka',
      'location': 'Mahali',
      'managerName': 'Jina la Meneja',
      'next': 'Ifuatayo',
      'back': 'Nyuma',
      'completeRegistration': 'Kamilisha Usajili',
      'loading': 'Inapakia...',
      'popular': 'Maarufu Zaidi',
      'bestValue': 'Thamani Bora',
      'save': 'Kokotoa',
      'monthly': 'Kila Mwezi',
      'quarterly': 'Kila Robo ya Mwaka',
      'annually': 'Kila Mwaka',
      'triannual': 'Miaka 3',
      'billingCycles': 'Mzunguko wa Malipo',
      'selectedPlan': 'Mpango Uliochaguliwa',
      'basePrice': 'Bei ya Msingi',
      'totalSavings': 'Jumla ya Akiba',
      'discountApplied': 'Punguzo Lime tumika',
      'monthlyPrice': 'Bei ya Mwezi',
      'billing': 'Malipo',
      'success': 'Imefanikiwa!',
      'successMessage': 'Akaunti yako imeundwa kwa mafanikio. Tafadhali angalia barua pepe yako kwa uthibitisho.',
      'error': 'Hitilafu',
      'ok': 'Sawa',
      'month': 'mwezi',
      'months': 'miezi',
      'year': 'mwaka',
      'years': 'miaka',
      'planFeatures': 'Vipengele vya Mpango',
      'maxDukas': 'Duka za Juu',
      'maxProducts': 'Bidhaa za Juu',
      'recommended': 'Imeshauliwa',
    },
    'fr': {
      'title': 'Créer un Compte - Étape',
      'choosePlan': 'Choisissez Votre Plan',
      'choosePlanSubtitle': 'Sélectionnez le plan qui correspond le mieux à vos besoins professionnels',
      'personalInfo': 'Informations Personnelles',
      'personalInfoSubtitle': 'Parlez-nous de vous',
      'businessSetup': 'Configuration de l\'Entreprise',
      'businessSetupSubtitle': 'Parlez-nous de votre entreprise',
      'subscriptionDetails': 'Détails de l\'Abonnement',
      'subscriptionDetailsSubtitle': 'Choisissez votre cycle de facturation',
      'fullName': 'Nom Complet',
      'email': 'Email',
      'password': 'Mot de Passe',
      'shopName': 'Nom du Magasin',
      'location': 'Emplacement',
      'managerName': 'Nom du Gérant',
      'next': 'Suivant',
      'back': 'Retour',
      'completeRegistration': 'Terminer l\'Inscription',
      'loading': 'Chargement...',
      'popular': 'Le Plus Populaire',
      'bestValue': 'Meilleure Valeur',
      'save': 'Économiser',
      'monthly': 'Mensuel',
      'quarterly': 'Trimestriel',
      'annually': 'Annuel',
      'triannual': '3 Ans',
      'billingCycles': 'Cycles de Facturation',
      'selectedPlan': 'Plan Sélectionné',
      'basePrice': 'Prix de Base',
      'totalSavings': 'Économies Totales',
      'discountApplied': 'Remise Appliquée',
      'monthlyPrice': 'Prix Mensuel',
      'billing': 'Facturation',
      'success': 'Succès!',
      'successMessage': 'Votre compte a été créé avec succès. Veuillez vérifier votre email pour la vérification.',
      'error': 'Erreur',
      'ok': 'OK',
      'month': 'mois',
      'months': 'mois',
      'year': 'an',
      'years': 'ans',
      'planFeatures': 'Fonctionnalités du Plan',
      'maxDukas': 'Max Duka',
      'maxProducts': 'Max Produits',
      'recommended': 'Recommandé',
    },
  };
  
  String _currentLanguage = 'en';
  
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? _translations['en']?[key] ?? key;
  }
  
  @override
  void initState() {
    super.initState();
    _loadPlans();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));
    
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
    _floatController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _locationController.dispose();
    _managerNameController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _floatController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getPlans('dummy-token');
      if (response['success'] == true) {
        setState(() {
          _plans = response['data']['plans'] ?? [];
        });
      }
    } catch (e) {
      setState(() {
        _plans = [
          {
            'id': 1,
            'name': 'Basic Plan',
            'description': 'Essential features for small businesses',
            'price': 29.99,
            'billing_cycle': 'monthly',
            'max_dukas': 1,
            'max_products': 100,
            'features': ['Basic inventory management', 'Sales tracking', 'Customer management'],
            'is_popular': false,
          },
          {
            'id': 2,
            'name': 'Premium Plan',
            'description': 'Advanced features for growing businesses',
            'price': 49.99,
            'billing_cycle': 'monthly',
            'max_dukas': 5,
            'max_products': 1000,
            'features': ['Advanced inventory management', 'Sales tracking', 'Customer management', 'Advanced analytics', 'Multi-duka support'],
            'is_popular': true,
          },
          {
            'id': 3,
            'name': 'Enterprise Plan',
            'description': 'Complete solution for large enterprises',
            'price': 99.99,
            'billing_cycle': 'monthly',
            'max_dukas': 25,
            'max_products': 5000,
            'features': ['All Premium features', 'API access', 'Priority support', 'Custom integrations', 'Advanced reporting'],
            'is_popular': false,
          }
        ];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _slideController.reset();
      _fadeController.reset();
      _scaleController.reset();
      _slideController.forward();
      _fadeController.forward();
      _scaleController.forward();
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _slideController.reset();
      _fadeController.reset();
      _scaleController.reset();
      _slideController.forward();
      _fadeController.forward();
      _scaleController.forward();
    }
  }
  
  double calculateDiscount(String billingCycle, double basePrice) {
    switch (billingCycle) {
      case 'quarterly':
        return basePrice * 0.1; // 10% discount
      case 'yearly':
        return basePrice * 0.2; // 20% discount
      case 'triannual':
        return basePrice * 0.25; // 25% discount
      default:
        return 0.0; // No discount for monthly
    }
  }
  
  double calculateTotalPrice(String billingCycle, double basePrice) {
    double discount = calculateDiscount(billingCycle, basePrice);
    switch (billingCycle) {
      case 'quarterly':
        return (basePrice - discount) * 3;
      case 'yearly':
        return (basePrice - discount) * 12;
      case 'triannual':
        return (basePrice - discount) * 36;
      default:
        return basePrice;
    }
  }
  
  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final registrationData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'shop_name': _shopNameController.text.trim(),
        'location': _locationController.text.trim(),
        'manager_name': _managerNameController.text.trim(),
        'plan_id': _selectedPlan['id'],
        'billing_cycle': _selectedBillingCycle,
      };
      
      final response = await _apiService.registerTenant(registrationData, 'dummy-token');
      
      if (response['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showErrorDialog('Registration failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A47),
        title: Text(translate('success'), style: const TextStyle(color: Colors.white)),
        content: Text(
          translate('successMessage'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Text(translate('ok'), style: const TextStyle(color: Color(0xFF4BB4FF))),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A47),
        title: Text(translate('error'), style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('ok'), style: const TextStyle(color: Color(0xFF4BB4FF))),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${translate('title')} ${_currentStep + 1}/4',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.language, color: Colors.white, size: 20),
              onSelected: (String value) {
                setState(() {
                  _currentLanguage = value;
                });
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'en',
                  child: Text('English 🇬🇧'),
                ),
                PopupMenuItem(
                  value: 'sw',
                  child: Text('Kiswahili 🇰🇪'),
                ),
                PopupMenuItem(
                  value: 'fr',
                  child: Text('Français 🇫🇷'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1B32),
              Color(0xFF1A2A47),
              Color(0xFF2A3B57),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    final offset = isActive ? sin(_floatAnimation.value * 2 * pi + index) * 2.0 : 0.0;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF4BB4FF) : Colors.white24,
                          border: Border.all(
                            color: isCompleted ? const Color(0xFF4BB4FF) : Colors.white24,
                            width: 2,
                          ),
                          boxShadow: isActive ? [
                            BoxShadow(
                              color: const Color(0xFF4BB4FF).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ] : null,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.white54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
                if (index < 3) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFF4BB4FF) : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPlanSelection();
      case 1:
        return _buildPersonalInfo();
      case 2:
        return _buildBusinessSetup();
      case 3:
        return _buildSubscriptionDetails();
      default:
        return Container();
    }
  }
  
  Widget _buildPlanSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('choosePlan'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translate('choosePlanSubtitle'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                        const SizedBox(height: 16),
                        Text(
                          translate('loading'),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      final isSelected = _selectedPlan == plan;
                      final isPopular = plan['is_popular'] == true;
                      
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + index * 100),
                        curve: Curves.elasticOut,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: InkWell(
                          onTap: () => setState(() => _selectedPlan = plan),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSelected ? [
                                  const Color(0xFF4BB4FF).withOpacity(0.3),
                                  const Color(0xFF4BB4FF).withOpacity(0.1),
                                ] : [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4BB4FF) : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: const Color(0xFF4BB4FF).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              ] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPopular)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4BB4FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      translate('popular'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
                                            plan['name'] ?? 'Plan ${index + 1}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            plan['description'] ?? '',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              color: Colors.white70,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4BB4FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [Color(0xFF4BB4FF), Color(0xFF6C63FF)],
                                      ).createShader(bounds),
                                      child: Text(
                                        '\$${plan['price']?.toString() ?? '0'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '/${plan['billing_cycle'] ?? translate('month')}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (plan['features'] != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translate('planFeatures'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...List.generate(
                                          (plan['features'] as List).length,
                                          (featureIndex) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4BB4FF),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    plan['features'][featureIndex],
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildFeatureChip('${translate('maxDukas')}: ${plan['max_dukas'] ?? 1}'),
                                    const SizedBox(width: 8),
                                    _buildFeatureChip('${translate('maxProducts')}: ${plan['max_products'] ?? 100}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildNavigationButtons(
            onNext: _selectedPlan != null ? _nextStep : null,
            showBack: false,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4BB4FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4BB4FF),
        ),
      ),
    );
  }
  
  Widget _buildPersonalInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('personalInfo'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    translate('personalInfoSubtitle'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildAnimatedTextField(
                    controller: _nameController,
                    label: translate('fullName'),
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedTextField(
                    controller: _emailController,
                    label: translate('email'),
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedTextField(
                    controller: _passwordController,
                    label: translate('password'),
                    icon: Icons.lock,
                    obscureText: _obscureText,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() => _obscureText = !_obscureText);
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildNavigationButtons(
              onNext: () {
                if (_formKey.currentState!.validate()) {
                  _nextStep();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBusinessSetup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('businessSetup'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    translate('businessSetupSubtitle'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildAnimatedTextField(
                    controller: _shopNameController,
                    label: translate('shopName'),
                    icon: Icons.store,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your shop name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedTextField(
                    controller: _locationController,
                    label: translate('location'),
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedTextField(
                    controller: _managerNameController,
                    label: translate('managerName'),
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the manager name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            _buildNavigationButtons(
              onNext: () {
                if (_formKey.currentState!.validate()) {
                  _nextStep();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubscriptionDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('subscriptionDetails'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translate('subscriptionDetailsSubtitle'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedPlan != null) _buildSelectedPlanSummary(),
          const SizedBox(height: 24),
          Text(
            translate('billingCycles'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildBillingOption(
                  translate('monthly'),
                  '1 ${translate('month')}',
                  _selectedBillingCycle == 'monthly',
                  () => setState(() => _selectedBillingCycle = 'monthly'),
                  discount: 0,
                ),
                _buildBillingOption(
                  translate('quarterly'),
                  '3 ${translate('months')}',
                  _selectedBillingCycle == 'quarterly',
                  () => setState(() => _selectedBillingCycle = 'quarterly'),
                  discount: 10,
                ),
                _buildBillingOption(
                  translate('annually'),
                  '1 ${translate('year')}',
                  _selectedBillingCycle == 'yearly',
                  () => setState(() => _selectedBillingCycle = 'yearly'),
                  discount: 20,
                  isRecommended: true,
                ),
                _buildBillingOption(
                  translate('triannual'),
                  '3 ${translate('years')}',
                  _selectedBillingCycle == 'triannual',
                  () => setState(() => _selectedBillingCycle = 'triannual'),
                  discount: 25,
                  isBestValue: true,
                ),
              ],
            ),
          ),
          _buildNavigationButtons(
            onNext: _completeRegistration,
            buttonText: translate('completeRegistration'),
            showBack: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectedPlanSummary() {
    final basePrice = _selectedPlan['price']?.toDouble() ?? 0.0;
    final totalPrice = calculateTotalPrice(_selectedBillingCycle, basePrice);
    final discount = calculateDiscount(_selectedBillingCycle, basePrice);
    final savings = _selectedBillingCycle != 'monthly' ? discount : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4BB4FF).withOpacity(0.2),
            const Color(0xFF6C63FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF4BB4FF), size: 24),
              const SizedBox(width: 8),
              Text(
                '${translate('selectedPlan')}: ${_selectedPlan['name']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${translate('basePrice')}: \$${basePrice.toStringAsFixed(2)}/${translate('month')}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (savings > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${translate('totalSavings')}: \$${savings.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4BB4FF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                ),
                child: Text(
                  '\$${totalPrice.toStringAsFixed(2)} ${translate('billing')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4BB4FF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildBillingOption(String title, String description, bool isSelected, VoidCallback onTap, {
    int discount = 0,
    bool isRecommended = false,
    bool isBestValue = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSelected ? [
                const Color(0xFF4BB4FF).withOpacity(0.3),
                const Color(0xFF6C63FF).withOpacity(0.2),
              ] : [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF4BB4FF) : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: const Color(0xFF4BB4FF).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4BB4FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  translate('recommended'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (isBestValue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  translate('bestValue'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF4BB4FF), size: 24),
                ],
              ),
              if (discount > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${translate('save')} $discount%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, icon).copyWith(
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }
  
  Widget _buildNavigationButtons({
    VoidCallback? onNext,
    VoidCallback? onBack,
    String? buttonText,
    bool showBack = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack ?? _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF4BB4FF), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  translate('back'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: showBack ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4BB4FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 8,
                shadowColor: const Color(0xFF4BB4FF).withOpacity(0.3),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      buttonText ?? translate('next'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1A2A47),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
