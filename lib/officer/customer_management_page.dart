import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'add_edit_customer_page.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _syncCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await DatabaseService().getAllCustomers();
    if (mounted) {
      setState(() {
        _customers = customers;
        _filterCustomers();
        _isLoading = false;
      });
    }
  }

  void _filterCustomers() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = _customers;
    } else {
      _filteredCustomers = _customers.where((c) {
        final name = c['name']?.toString().toLowerCase() ?? '';
        final email = c['email']?.toString().toLowerCase() ?? '';
        final phone = c['phone']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    }
  }

  Future<void> _syncCustomers() async {
    try {
      final token = await SyncService().getAuthToken();
      if (token != null) {
        final response = await ApiService().getCustomers(token);
        if (response['success'] == true && response['data'] != null) {
          final customers = response['data']['customers'] as List;
          await DatabaseService().saveCustomers(customers);
          _loadCustomers();
        }
      }
    } catch (e) {
      print('Customer sync failed: $e');
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
        title: Text('Customers', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _filterCustomers();
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF)))
                    : _filteredCustomers.isEmpty
                        ? Center(child: Text('No customers found', style: GoogleFonts.plusJakartaSans(color: Colors.white54)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = _filteredCustomers[index];
                              final isSynced = customer['sync_status'] == DatabaseService.statusSynced;
                              return Card(
                                color: Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AddEditCustomerPage(customer: customer)),
                                    );
                                    if (result == true) _loadCustomers();
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF4BB4FF).withOpacity(0.2),
                                    child: Text(
                                      (customer['name'] as String)[0].toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF4BB4FF), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(customer['name'], style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    [customer['phone'], customer['email']].where((e) => e != null && e.toString().isNotEmpty).join(' • '),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  trailing: !isSynced
                                      ? const Icon(Icons.cloud_off, color: Colors.orange, size: 16)
                                      : null,
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditCustomerPage()));
          if (result == true) _loadCustomers();
        },
        backgroundColor: const Color(0xFF4BB4FF),
        child: const Icon(Icons.add),
      ),
    );
  }
}