import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static const String _tenantAccountKey = 'tenant_account';
  static const String _currencyKey = 'tenant_currency';
  static const String _companyNameKey = 'company_name';
  static const String _logoUrlKey = 'logo_url';
  static const String _phoneKey = 'phone';
  static const String _emailKey = 'email';
  static const String _addressKey = 'address';
  static const String _timezoneKey = 'timezone';
  static const String _websiteKey = 'website';
  static const String _descriptionKey = 'description';
  static const String _selectedLanguageKey = 'selected_language';

  static SharedPreferencesService? _instance;
  static SharedPreferences? _prefs;

  static Future<SharedPreferencesService> getInstance() async {
    _instance ??= SharedPreferencesService();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Tenant Account Management
  Future<void> saveTenantAccount(Map<String, dynamic> accountData) async {
    await _prefs?.setString(_tenantAccountKey, jsonEncode(accountData));
    
    // Save individual fields for easy access
    final tenantAccount = accountData['tenant_account'];
    if (tenantAccount != null) {
      await _saveIndividualFields(tenantAccount);
    }
  }

  Future<Map<String, dynamic>?> getTenantAccount() async {
    final jsonString = _prefs?.getString(_tenantAccountKey);
    if (jsonString != null) {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> _saveIndividualFields(Map<String, dynamic> tenantAccount) async {
    await _prefs?.setString(_currencyKey, tenantAccount['currency'] ?? 'KES');
    await _prefs?.setString(_companyNameKey, tenantAccount['company_name'] ?? '');
    await _prefs?.setString(_logoUrlKey, tenantAccount['logo_url'] ?? '');
    await _prefs?.setString(_phoneKey, tenantAccount['phone'] ?? '');
    await _prefs?.setString(_emailKey, tenantAccount['email'] ?? '');
    await _prefs?.setString(_addressKey, tenantAccount['address'] ?? '');
    await _prefs?.setString(_timezoneKey, tenantAccount['timezone'] ?? 'Africa/Nairobi');
    await _prefs?.setString(_websiteKey, tenantAccount['website'] ?? '');
    await _prefs?.setString(_descriptionKey, tenantAccount['description'] ?? '');
  }

  // Individual field getters
  String getCurrency() {
    return _prefs?.getString(_currencyKey) ?? 'KES';
  }

  String getCompanyName() {
    return _prefs?.getString(_companyNameKey) ?? '';
  }

  String getLogoUrl() {
    return _prefs?.getString(_logoUrlKey) ?? '';
  }

  String getPhone() {
    return _prefs?.getString(_phoneKey) ?? '';
  }

  String getEmail() {
    return _prefs?.getString(_emailKey) ?? '';
  }

  String getAddress() {
    return _prefs?.getString(_addressKey) ?? '';
  }

  String getTimezone() {
    return _prefs?.getString(_timezoneKey) ?? 'Africa/Nairobi';
  }

  String getWebsite() {
    return _prefs?.getString(_websiteKey) ?? '';
  }

  String getDescription() {
    return _prefs?.getString(_descriptionKey) ?? '';
  }

  // Clear tenant account data
  Future<void> clearTenantAccount() async {
    await _prefs?.remove(_tenantAccountKey);
    await _prefs?.remove(_currencyKey);
    await _prefs?.remove(_companyNameKey);
    await _prefs?.remove(_logoUrlKey);
    await _prefs?.remove(_phoneKey);
    await _prefs?.remove(_emailKey);
    await _prefs?.remove(_addressKey);
    await _prefs?.remove(_timezoneKey);
    await _prefs?.remove(_websiteKey);
    await _prefs?.remove(_descriptionKey);
  }

  // Check if tenant account data exists
  bool hasTenantAccount() {
    return _prefs?.containsKey(_tenantAccountKey) ?? false;
  }

  // Language preference management
  Future<void> setSelectedLanguage(String languageCode) async {
    await _prefs?.setString(_selectedLanguageKey, languageCode);
  }

  Future<String?> getSelectedLanguage() async {
    return _prefs?.getString(_selectedLanguageKey);
  }

  String getCurrentLanguage() {
    return _prefs?.getString(_selectedLanguageKey) ?? 'en'; // Default to English
  }

  bool hasLanguagePreference() {
    return _prefs?.containsKey(_selectedLanguageKey) ?? false;
  }

  Future<void> clearLanguagePreference() async {
    await _prefs?.remove(_selectedLanguageKey);
  }
}