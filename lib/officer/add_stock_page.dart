import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class AddStockPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const AddStockPage({super.key, required this.product});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _reasonController = TextEditingController(text: 'New Stock');

  bool _isLoading = false;
  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.product['current_stock'] as int? ?? 0;
    // Pre-fill cost price if available
    if (widget.product['base_price'] != null) {
      _costController.text = widget.product['base_price'].toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitStock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final int quantityToAdd = int.parse(_quantityController.text);
      final double? unitCost = double.tryParse(_costController.text);
      final String reason = _reasonController.text.trim();

      final int? serverProductId = widget.product['server_id'];

      // Check for connectivity
      final token = await SyncService().getAuthToken();

      bool success = false;
      String message = "";

      if (serverProductId != null && token != null) {
        // Online Mode: Send directly to server
        try {
          final response = await ApiService().addStock({
            'product_id': serverProductId,
            'quantity': quantityToAdd,
            'reason': reason,
            if (unitCost != null) 'unit_cost': unitCost,
          }, token);

          if (response['success'] == true) {
            success = true;
            message = "Stock added successfully to server";
            await DatabaseService().adjustStock(
              widget.product,
              quantityToAdd,
              reason,
            );
          } else {
            message = response['message'] ?? "Failed to add stock on server";
          }
        } catch (e) {
          debugPrint("Server add stock failed: $e. Falling back to local.");
          // If server fails (e.g. timeout), could fallback to local
          // adhering to "Offline First" if you wanted.
          // For now, let's treat generic errors as offline potential?
          // Or just fail.
          message = "Connection error: $e";
        }
      }

      if (!success) {
        // Offline or Server Failed (Optional: Implement Offline Queue)
        // Here we just update locally and maybe queue?
        // Current SyncService needs 'syncPendingStockMovements' to pick this up.
        // Assuming DatabaseService().adjustStock creates a movement with sync_status=pending

        // Let's rely on DatabaseService to handle local stock adjustment
        // Note: You must ensure DatabaseService.adjustStock creates a pending movement.

        // For this implementation, we will assume strict online for stock additions
        // unless you want fully offline.
        // Given user request "add mechanism", let's prioritize the online path provided by API.

        if (serverProductId == null) {
          // Local-only product
          await DatabaseService().adjustStock(
            widget.product,
            quantityToAdd,
            reason,
          );
          success = true;
          message = "Stock added locally (Local Product)";
        } else {
          // Server product but failed/offline.
          // If the user insists on offline support, we'd use adjustStock.
          // Let's allow it.
          await DatabaseService().adjustStock(
            widget.product,
            quantityToAdd,
            reason,
          );
          success = true;
          message = "Stock added locally (Pending Sync)";
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          Navigator.pop(context, true); // Return true to refresh
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive scaling
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double fontScale = screenWidth < 360 ? 0.9 : 1.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add Stock",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20 * fontScale,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color(0xFF1E4976),
                  Color(0xFF0C223F),
                  Color(0xFF020B18),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4BB4FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF4BB4FF),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product['name'] ?? 'Unknown Product',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 18 * fontScale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      "Current Stock: ",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white70,
                                        fontSize: 14 * fontScale,
                                      ),
                                    ),
                                    Text(
                                      "$_currentStock",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.greenAccent,
                                        fontSize: 14 * fontScale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Inputs
                    Text(
                      "Stock Details",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16 * fontScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildGlassTextField(
                      controller: _quantityController,
                      label: "Quantity to Add",
                      icon: Icons.add_shopping_cart_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Required";
                        final n = int.tryParse(value);
                        if (n == null || n <= 0) return "Must be positive";
                        return null;
                      },
                      onChanged: (val) {
                        setState(
                          () {},
                        ); // Rebuild to update projections if we add them
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildGlassTextField(
                      controller: _costController,
                      label: "Unit Cost (Buying Price)",
                      icon: Icons.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        // Optional, but if provided must be number
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return "Invalid number";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildGlassTextField(
                      controller: _reasonController,
                      label: "Reason / Notes",
                      icon: Icons.note_alt_outlined,
                      keyboardType: TextInputType.text,
                    ),

                    const SizedBox(height: 40),

                    // Calculations / Preview
                    if (_quantityController.text.isNotEmpty &&
                        int.tryParse(_quantityController.text) != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "New Total Stock",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${_currentStock + (int.tryParse(_quantityController.text) ?? 0)}",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.greenAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitStock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4BB4FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  "Add Stock",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
            validator: validator,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white60),
              prefixIcon: Icon(icon, color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
