import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:stockflowkp/services/database_service.dart';

// Run CSV conversion in a separate isolate to prevent UI freezing
String _generateCsvString(List<List<dynamic>> data) {
  return const ListToCsvConverter().convert(data);
}

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isLoading = false;

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    // Small delay to ensure loading spinner renders before heavy IO starts
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final dbService = DatabaseService();
      final dbPath = await dbService.getDatabasePath();

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final backupName = 'stockflowkp_backup_$dateStr.db';

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final backupPath = '${tempDir.path}/$backupName';

      // Copy database file to backup location
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);

      // Get officer's email to pre-fill
      final userData = await dbService.getUserData();
      String? officerEmail;
      if (userData != null) {
        if (userData['email'] != null) {
          officerEmail = userData['email'];
        } else if (userData['data'] != null && userData['data']['user'] != null) {
          officerEmail = userData['data']['user']['email'];
        }
      }

      final Email email = Email(
        body: 'Please find attached the backup of your StockFlow KP database.',
        subject: 'StockFlow KP Database Backup',
        recipients: officerEmail != null ? [officerEmail] : [],
        attachmentPaths: [backupPath],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created. Sending via email...'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createCsvBackup() async {
    setState(() => _isLoading = true);
    // Small delay to ensure loading spinner renders
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final db = await DatabaseService().database;
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      List<String> attachments = [];

      // Helper to export table
      Future<void> exportTable(String tableName, String fileName) async {
        final data = await db.query(tableName);
        if (data.isNotEmpty) {
          // Prepare data structure
          final headers = data.first.keys.toList();
          final rows = data.map((row) => row.values.toList()).toList();
          final csvData = [headers, ...rows];

          // Convert to CSV string in background isolate
          String csv = await compute(_generateCsvString, csvData);
          
          final file = File('${tempDir.path}/${fileName}_$dateStr.csv');
          await file.writeAsString(csv);
          attachments.add(file.path);
        }
      }

      await exportTable('sales', 'sales');
      await exportTable('products', 'products');
      await exportTable('customers', 'customers');
      await exportTable('stocks', 'stocks');

      if (attachments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to export.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Get officer's email
      final userData = await DatabaseService().getUserData();
      String? officerEmail;
      if (userData != null) {
        if (userData['email'] != null) {
          officerEmail = userData['email'];
        } else if (userData['data'] != null && userData['data']['user'] != null) {
          officerEmail = userData['data']['user']['email'];
        }
      }

      final Email email = Email(
        body: 'Please find attached the CSV exports of your StockFlow KP data.',
        subject: 'StockFlow KP CSV Export',
        recipients: officerEmail != null ? [officerEmail] : [],
        attachmentPaths: attachments,
        isHTML: false,
      );

      await FlutterEmailSender.send(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV Export created. Sending via email...'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        
        if (!mounted) return;
        
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirm Restore', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'This will overwrite your current data with the selected backup. This action cannot be undone. Are you sure?',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: Text('Restore', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => _isLoading = true);
          final success = await DatabaseService().restoreDatabase(path);
          
          if (mounted) {
            setState(() => _isLoading = false);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Database restored successfully.'), backgroundColor: Colors.green),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to restore database'), backgroundColor: Colors.red),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Backup & Restore',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOptionCard(
                    title: 'Backup Data',
                    description: 'Create a copy of your local database and send it via email.',
                    icon: Icons.email_rounded,
                    color: const Color(0xFF4BB4FF),
                    onTap: _createBackup,
                  ),
                  const SizedBox(height: 20),
                  _buildOptionCard(
                    title: 'Export to CSV',
                    description: 'Export your sales, products, and customers to CSV files and send via email.',
                    icon: Icons.table_chart_rounded,
                    color: Colors.greenAccent,
                    onTap: _createCsvBackup,
                  ),
                  const SizedBox(height: 20),
                  _buildOptionCard(
                    title: 'Restore Data',
                    description: 'Restore your data from a previously saved backup file. Warning: This will replace current data.',
                    icon: Icons.restore_rounded,
                    color: Colors.orangeAccent,
                    onTap: _restoreBackup,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 13,
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
    );
  }
}