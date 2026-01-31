import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Support & Security",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient matching the app theme
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header with app logo and title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                    child: Column(
                      children: [
                        // App Logo Container
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4BB4FF,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.help_center_outlined,
                                      color: Color(0xFF4BB4FF),
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "StockFlowKP",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "We're here to help you succeed",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contact Information Section
                  _buildSectionHeader("📞 Contact Information"),
                  _buildContactCards(context),

                  // Support Options Section
                  _buildSectionHeader("🛠️ Support Options"),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildSupportOptionCard(
                          Icons.menu_book_rounded,
                          "User Manual",
                          "Read the comprehensive guide",
                          "View PDF",
                          Icons.arrow_forward_ios,
                          () => _openUserManual(context),
                        ),
                        _buildSupportOptionCard(
                          Icons.download_rounded,
                          "Download Manual",
                          "Save PDF to Downloads folder",
                          "Save",
                          Icons.save_alt_rounded,
                          () => _saveUserManualToDownloads(context),
                        ),
                        _buildSupportOptionCard(
                          Icons.phone_in_talk_outlined,
                          "Phone Support",
                          "Call us for immediate assistance",
                          "0622080947",
                          Icons.arrow_forward_ios,
                          () => _showContactOptions(
                            context,
                            'phone',
                            '+255 622 080 947',
                          ),
                        ),
                        _buildSupportOptionCard(
                          Icons.email_outlined,
                          "Email Support",
                          "Send us detailed questions",
                          "info@stockflowkp.online",
                          Icons.arrow_forward_ios,
                          () => _showContactOptions(
                            context,
                            'email',
                            'info@stockflowkp.online',
                          ),
                        ),
                        _buildSupportOptionCard(
                          Icons.location_on_outlined,
                          "Visit Our Office",
                          "Come see us in person",
                          "Dodoma, Tanzania",
                          Icons.arrow_forward_ios,
                          () => _showContactOptions(
                            context,
                            'location',
                            'Dodoma, Tanzania',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Security Information Section
                  _buildSectionHeader("🔒 Security & Privacy"),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildInfoCard(
                          Icons.shield_outlined,
                          "Data Protection",
                          "Your business data is encrypted and securely stored. We use industry-standard security measures to protect your information from unauthorized access.",
                          const Color(0xFF4BB4FF),
                        ),
                        _buildInfoCard(
                          Icons.lock_outline,
                          "Secure Transactions",
                          "All financial transactions are processed through secure payment gateways with SSL encryption to ensure your data remains safe.",
                          Colors.lightGreenAccent,
                        ),
                        _buildInfoCard(
                          Icons.privacy_tip_outlined,
                          "Privacy Policy",
                          "We respect your privacy and never share your business data with third parties without your explicit consent.",
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),

                  // Legal & Policy Section
                  _buildSectionHeader("📋 Legal & Policies"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    child: Column(
                      children: [
                        _buildPolicyCard(
                          "Terms of Service",
                          "By using StockFlowKP, you agree to our terms of service which outline the rules and regulations for using our inventory management system.",
                          Icons.description_outlined,
                        ),
                        _buildPolicyCard(
                          "Privacy Policy",
                          "Our privacy policy explains how we collect, use, and protect your personal and business information in compliance with data protection laws.",
                          Icons.policy_outlined,
                        ),
                        _buildPolicyCard(
                          "License Agreement",
                          "StockFlowKP is licensed software. Your license grants you the right to use the software according to the terms specified in your agreement.",
                          Icons.verified_outlined,
                        ),
                        _buildPolicyCard(
                          "Refund Policy",
                          "We offer refunds according to our refund policy. Please contact our support team for assistance with refund requests.",
                          Icons.money_off_csred_outlined,
                        ),
                        _buildPolicyCard(
                          "Acceptable Use Policy",
                          "Our acceptable use policy defines appropriate and inappropriate use of the StockFlowKP platform to ensure a safe environment for all users.",
                          Icons.rule_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContactCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildContactRow(
                  Icons.email,
                  "Email",
                  "info@stockflowkp.online",
                  () => _showContactOptions(
                    context,
                    'email',
                    'info@stockflowkp.online',
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                _buildContactRow(
                  Icons.phone,
                  "Phone",
                  "+255 622 080 947",
                  () =>
                      _showContactOptions(context, 'phone', '+255 622 080 947'),
                ),
                const Divider(color: Colors.white12, height: 1),
                _buildContactRow(
                  Icons.location_on,
                  "Location",
                  "Dodoma, Tanzania",
                  () => _showContactOptions(
                    context,
                    'location',
                    'Dodoma, Tanzania',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4BB4FF), size: 24),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white54,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSupportOptionCard(
    IconData icon,
    String title,
    String subtitle,
    String value,
    IconData trailing,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4BB4FF), size: 24),
              ),
              title: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              trailing: Icon(trailing, color: Colors.white54, size: 16),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String description,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyCard(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ExpansionTile(
              leading: Icon(icon, color: Colors.cyanAccent, size: 24),
              title: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              iconColor: Colors.white54,
              collapsedIconColor: Colors.white54,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    // In a real app, you would use the clipboard package here
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: const Color(0xFF4BB4FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showContactOptions(BuildContext context, String type, String value) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF020B18).withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Contact Options',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (type == 'phone')
                        ListTile(
                          leading: const Icon(
                            Icons.phone,
                            color: Color(0xFF4BB4FF),
                          ),
                          title: Text(
                            'Call $value',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text('Direct phone call'),
                          onTap: () {
                            Navigator.pop(context);
                            _copyToClipboard(context, value);
                          },
                        ),
                      if (type == 'email')
                        ListTile(
                          leading: const Icon(
                            Icons.email,
                            color: Color(0xFF4BB4FF),
                          ),
                          title: Text(
                            'Email $value',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text('Send email message'),
                          onTap: () {
                            Navigator.pop(context);
                            _copyToClipboard(context, value);
                          },
                        ),
                      if (type == 'location')
                        ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Color(0xFF4BB4FF),
                          ),
                          title: Text(
                            'Location: $value',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text('View on map'),
                          onTap: () {
                            Navigator.pop(context);
                            _copyToClipboard(context, value);
                          },
                        ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: const Icon(Icons.copy, color: Colors.white70),
                        title: Text(
                          'Copy $value',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                          ),
                        ),
                        subtitle: const Text('Copy to clipboard'),
                        onTap: () {
                          Navigator.pop(context);
                          _copyToClipboard(context, value);
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

  Future<void> _openUserManual(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
          ),
    );

    try {
      final byteData = await rootBundle.load('assets/manue.pdf');
      final file = File('${(await getTemporaryDirectory()).path}/manue.pdf');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open manual. Please ensure assets/manue.pdf exists.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveUserManualToDownloads(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      final byteData = await rootBundle.load('assets/manue.pdf');
      final buffer = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      String filePath;
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          filePath = '${directory.path}/StockFlowKP_User_Manual.pdf';
        } else {
          final extDir = await getExternalStorageDirectory();
          filePath = '${extDir?.path}/StockFlowKP_User_Manual.pdf';
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/StockFlowKP_User_Manual.pdf';
      }

      final file = File(filePath);
      await file.writeAsBytes(buffer);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $filePath'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
