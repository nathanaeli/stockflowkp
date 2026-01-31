import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/shared_preferences_service.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _selectedLanguage = 'en';
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    final savedLanguage = await _prefsService.getSelectedLanguage();
    if (savedLanguage != null && mounted) {
      setState(() {
        _selectedLanguage = savedLanguage;
      });
    }
  }

  void _changeLanguage(String languageCode) async {
    await _prefsService.setSelectedLanguage(languageCode);
    if (mounted) {
      setState(() {
        _selectedLanguage = languageCode;
      });

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageCode == 'en'
                ? 'Language changed to English'
                : languageCode == 'sw'
                ? 'Lugha imebadilishwa kuwa Kiswahili'
                : 'Language changed to French',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Language Settings',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Language',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred language for the app interface',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              _buildLanguageOption(
                languageCode: 'en',
                languageName: 'English',
                languageNative: 'English',
                flag: '🇺🇸',
                description: 'Default language',
              ),
              const SizedBox(height: 16),

              _buildLanguageOption(
                languageCode: 'sw',
                languageName: 'Swahili',
                languageNative: 'Kiswahili',
                flag: '🇰🇪',
                description: 'For East Africa region',
              ),
              const SizedBox(height: 16),

              _buildLanguageOption(
                languageCode: 'fr',
                languageName: 'French',
                languageNative: 'Français',
                flag: '🇫🇷',
                description: 'For French speaking countries',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required String languageNative,
    required String flag,
    String? description,
  }) {
    final isSelected = _selectedLanguage == languageCode;

    return GestureDetector(
      onTap: () => _changeLanguage(languageCode),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF4BB4FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF4BB4FF)
                    : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    languageNative,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF4BB4FF), size: 24)
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white54,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
