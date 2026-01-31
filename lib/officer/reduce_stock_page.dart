import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sync_service.dart';

class ReduceStockPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ReduceStockPage({super.key, required this.product});

  @override
  State<ReduceStockPage> createState() => _ReduceStockPageState();
}

class _ReduceStockPageState extends State<ReduceStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedReason = 'damaged';

  bool _isLoading = false;
  int _currentStock = 0;

  final List<Map<String, String>> _reasons = [
    {'value': 'damaged', 'label': 'Damaged Goods'},
    {'value': 'lost', 'label': 'Lost / Stolen'},
    {'value': 'expired', 'label': 'Expired'},
    {'value': 'destroyed', 'label': 'Destroyed'},
    {'value': 'returned_to_supplier', 'label': 'Returned to Supplier'},
  ];

  @override
  void initState() {
    super.initState();
    _currentStock = widget.product['current_stock'] as int? ?? 0;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReduction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final int quantityToReduce = int.parse(_quantityController.text);
      if (quantityToReduce > _currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot reduce more than current stock"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final String notes = _notesController.text.trim();
      final int? serverProductId = widget.product['server_id'];
      final int? dukaId = widget.product['duka_id'];

      // Check for connectivity
      final token = await SyncService().getAuthToken();

      bool success = false;
      String message = "";

      // Calculate adjusted quantity (negative for reduction)
      final int adjustedQuantity = -quantityToReduce;

      if (serverProductId != null && dukaId != null && token != null) {
        // Online Mode: Send directly to server
        try {
          final response = await ApiService().reduceStock({
            'product_id': serverProductId,
            'duka_id': dukaId,
            'quantity': quantityToReduce,
            'type': _selectedReason,
            'notes': notes,
          }, token);

          if (response['success'] == true) {
            success = true;
            message = "Stock reduced on server";

            // Update local consistent with server
            await DatabaseService().adjustStock(
              widget.product,
              adjustedQuantity,
              "$_selectedReason: $notes",
            );
          } else {
            message = response['message'] ?? "Failed to reduce stock on server";
          }
        } catch (e) {
          debugPrint("Server reduce stock failed: $e. Falling back to local.");
          message = "Connection error: $e";
        }
      }

      if (!success) {
        // Fallback or Local-Only
        await DatabaseService().adjustStock(
          widget.product,
          adjustedQuantity,
          "$_selectedReason: $notes",
        );
        success = true;
        message = "Stock reduced locally (Pending Sync)";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) Navigator.pop(context, true);
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
    // Scaling
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
          "Reduce Stock",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20 * fontScale,
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
                colors: [
                  Color(0xFF3E1E1E),
                  Color(0xFF2F0F0F),
                  Color(0xFF180505),
                ], // Reddish tint for danger zone
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
                    // Product card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product['name'] ?? 'Unknown',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Current Stock: $_currentStock",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    Text(
                      "Reduction Reason",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReason,
                          dropdownColor: const Color(0xFF1E0F0F),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.white,
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          items:
                              _reasons
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r['value'],
                                      child: Text(r['label']!),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedReason = val);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildGlassTextField(
                      controller: _quantityController,
                      label: "Quantity to Remove",
                      icon: Icons.remove_circle_outline_rounded,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Required";
                        if (int.tryParse(val) == null || int.parse(val) <= 0) {
                          return "Must be > 0";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildGlassTextField(
                      controller: _notesController,
                      label: "Notes (Optional)",
                      icon: Icons.edit_note_rounded,
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitReduction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                  "Confirm Reduction",
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
