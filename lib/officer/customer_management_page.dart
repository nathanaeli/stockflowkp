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
      _filteredCustomers =
          _customers.where((c) {
            final name = c['name']?.toString().toLowerCase() ?? '';
            final email = c['email']?.toString().toLowerCase() ?? '';
            final phone = c['phone']?.toString().toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                phone.contains(query);
          }).toList();
    }
  }

  Future<void> _syncCustomers() async {
    try {
      final syncService = SyncService();
      final token = await syncService.getAuthToken();
      if (token != null) {
        final response = await ApiService().getCustomers(token);
        if (response['success'] == true && response['data'] != null) {
          final customersList = response['data']['customers'] as List;
          if (customersList.isNotEmpty) {
            await DatabaseService().saveCustomers(customersList);
            if (mounted) _loadCustomers();
          }
        }
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF0A1B32),
                title: Text(
                  'Delete Customer?',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                ),
                content: Text(
                  'Are you sure you want to delete "${customer['name']}"?',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;
    setState(() => _isLoading = true);

    try {
      final serverId = customer['server_id'];
      final localId = customer['local_id'];

      if (serverId != null) {
        final syncService = SyncService();
        final token = await syncService.getAuthToken();
        final isConnected = await syncService.hasInternetConnection();

        if (token != null && isConnected) {
          await ApiService().deleteCustomer(serverId, token);
        } else if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: Deleted locally only.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await DatabaseService().deleteCustomer(localId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
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
        title: Text(
          'Customers',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
              // Search Field
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged:
                      (val) => setState(() {
                        _searchQuery = val;
                        _filterCustomers();
                      }),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4BB4FF),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final isSynced =
                                customer['sync_status'] ==
                                DatabaseService.statusSynced;

                            return Dismissible(
                              key: Key('customer_${customer['local_id']}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _deleteCustomer(customer);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                              child: Card(
                                color: Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => AddEditCustomerPage(
                                              customer: customer,
                                            ),
                                      ),
                                    );
                                    if (result == true) _loadCustomers();
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.2),
                                    child: Text(
                                      customer['name'][0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF4BB4FF),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    customer['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    customer['phone'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),

                                  // VISIBLE DELETE BUTTON ADDED HERE
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isSynced)
                                        const Icon(
                                          Icons.cloud_off,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => _deleteCustomer(customer),
                                      ),
                                    ],
                                  ),
                                ),
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
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditCustomerPage()),
          );
          if (result == true) _loadCustomers();
        },
        backgroundColor: const Color(0xFF4BB4FF),
        child: const Icon(Icons.add),
      ),
    );
  }
}
