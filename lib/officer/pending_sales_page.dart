import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class PendingSalesPage extends StatefulWidget {
  const PendingSalesPage({super.key});

  @override
  State<PendingSalesPage> createState() => _PendingSalesPageState();
}

class _PendingSalesPageState extends State<PendingSalesPage> {
  List<Map<String, dynamic>> _pendingSales = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadPendingSales();
  }

  Future<void> _loadPendingSales() async {
    setState(() => _isLoading = true);
    try {
      final sales = await DatabaseService().getPendingSales();
      // Enrich with customer names for display
      List<Map<String, dynamic>> enriched = [];
      final db = await DatabaseService().database;
      
      for (var sale in sales) {
        String customerName = AppLocalizations.of(context)?.walkInCustomer ?? 'Walk-in';
        if (sale['customer_id'] != null) {
          final cust = await db.query('customers', 
            columns: ['name'], 
            where: 'local_id = ? OR server_id = ?', 
            whereArgs: [sale['customer_id'], sale['customer_id']],
            limit: 1
          );
          if (cust.isNotEmpty) customerName = cust.first['name'] as String;
        }
        enriched.add({...sale, 'customer_name': customerName});
      }

      if (mounted) {
        setState(() {
          _pendingSales = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncSale(int index) async {
    final sale = _pendingSales[index];
    setState(() => _isSyncing = true);

    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      
      if (token == null) {
        throw Exception(AppLocalizations.of(context)?.notAuthenticated ?? 'Not authenticated');
      }

      final result = await syncService.syncSpecificSale(sale['local_id'], token);
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.saleSyncedSuccessfully ?? 'Sale synced successfully'), backgroundColor: Colors.green),
          );
          _loadPendingSales(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.syncFailedWithMessage(result['message']) ?? 'Sync failed: ${result['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.errorWithMessage(e.toString()) ?? 'Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncAll() async {
    if (_pendingSales.isEmpty) return;
    setState(() => _isSyncing = true);

    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      if (token == null) throw Exception(AppLocalizations.of(context)?.notAuthenticated ?? 'Not authenticated');

      int successCount = 0;
      for (var sale in _pendingSales) {
        final result = await syncService.syncSpecificSale(sale['local_id'], token);
        if (result['success'] == true) successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.syncedCountOfTotal(successCount, _pendingSales.length) ?? 'Synced $successCount of ${_pendingSales.length} sales'),
            backgroundColor: successCount == _pendingSales.length ? Colors.green : Colors.orange,
          ),
        );
        _loadPendingSales();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.errorWithMessage(e.toString()) ?? 'Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
          AppLocalizations.of(context)?.pendingSales ?? 'Pending Sales',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_pendingSales.isNotEmpty)
            IconButton(
              icon: _isSyncing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              onPressed: _isSyncing ? null : _syncAll,
              tooltip: AppLocalizations.of(context)?.syncAll ?? 'Sync All',
            ),
        ],
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
              : _pendingSales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)?.allSalesSynced ?? 'All sales are synced',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingSales.length,
                      itemBuilder: (context, index) {
                        final sale = _pendingSales[index];
                        final date = DateTime.parse(sale['created_at']);
                        final formattedDate = DateFormat('MMM d, h:mm a').format(date);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.upload_rounded, color: Colors.orange, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale['customer_name'] ?? (AppLocalizations.of(context)?.walkInCustomer ?? 'Walk-in'),
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currencyFormat.format(sale['total_amount']),
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: _isSyncing ? null : () => _syncSale(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4BB4FF).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)?.syncNow ?? 'Sync Now',
                                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4BB4FF), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}