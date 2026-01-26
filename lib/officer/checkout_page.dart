import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CheckoutPage extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? customer;
  final String initialNote;

  const CheckoutPage({
    super.key,
    required this.totalAmount,
    required this.cartItems,
    this.customer,
    this.initialNote = '',
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late TextEditingController _discountController;
  late TextEditingController _noteController;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  bool _isLoan = false;
  DateTime? _selectedDate;
  double _discount = 0.0;
  bool _isOrderSummaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _discountController = TextEditingController();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double finalTotal = (widget.totalAmount - _discount).clamp(
      0.0,
      double.infinity,
    );

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
          'Checkout',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
                  Color(0xFF0A1B32),
                  Color(0xFF020B18),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Amount Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Payable',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(finalTotal),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Discount: -${_currencyFormat.format(_discount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Customer Info Summary
                  Row(
                    children: [
                      Text(
                        'Customer',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (widget.customer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4BB4FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF4BB4FF).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: Color(0xFF4BB4FF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.customer!['name'] ?? 'Unknown',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Walk-in Customer',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Order Summary (Expandable)
                  _buildOrderSummary(),

                  const SizedBox(height: 24),

                  // Form Fields
                  _buildSectionTitle('Transaction Details'),
                  const SizedBox(height: 12),

                  // Date Picker
                  _buildDateField(context),
                  const SizedBox(height: 16),

                  // Discount Field
                  _buildTextField(
                    controller: _discountController,
                    label: 'Discount Amount',
                    icon: Icons.discount_outlined,
                    isNumeric: true,
                    onChanged: (val) {
                      final d = double.tryParse(val) ?? 0.0;
                      setState(() => _discount = d);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Note Field
                  _buildTextField(
                    controller: _noteController,
                    label: 'Sale Note / Comment',
                    icon: Icons.note_alt_outlined,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 24),

                  // Loan Checkbox
                  _buildLoanCheckbox(),

                  const SizedBox(height: 40),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFF4BB4FF).withOpacity(0.4),
                      ),
                      child: Text(
                        'Confirm Sale',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Order Summary (${widget.cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int))} items)',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              height: 1,
              color: Colors.white10,
              margin: const EdgeInsets.only(bottom: 12),
            ),
            ...widget.cartItems.map((item) {
              final name = item['name'] ?? 'Unknown Item';
              final qty = item['quantity'] ?? 0;
              final subtotal = item['subtotal'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'x$qty',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currencyFormat.format(subtotal),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_today,
            color: Colors.white70,
            size: 20,
          ),
        ),
        title: Text(
          _selectedDate == null
              ? 'Today, ${DateFormat('h:mm a').format(DateTime.now())}'
              : DateFormat('MMM d, yyyy - h:mm a').format(_selectedDate!),
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
        ),
        subtitle: Text(
          _selectedDate == null ? 'Tap to change date' : 'Custom date selected',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF4BB4FF),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0A1B32),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF0A1B32),
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            // ignore: use_build_context_synchronously
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(
                _selectedDate ?? DateTime.now(),
              ),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF4BB4FF),
                      onPrimary: Colors.white,
                      surface: Color(0xFF0A1B32),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              setState(() {
                _selectedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }
          }
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumeric = false,
    Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
          isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.white54),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildLoanCheckbox() {
    return Container(
      decoration: BoxDecoration(
        color:
            _isLoan
                ? Colors.orange.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLoan ? Colors.orange.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Mark as Loan',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _isLoan
              ? 'Payment will be marked as pending'
              : 'Requires customer selection',
          style: GoogleFonts.plusJakartaSans(
            color: _isLoan ? Colors.orange : Colors.white54,
            fontSize: 12,
          ),
        ),
        value: _isLoan,
        onChanged: (val) {
          setState(() => _isLoan = val);
        },
        activeColor: Colors.orange,
        activeTrackColor: Colors.orange.withOpacity(0.3),
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  void _handleConfirm() {
    if (_discount > widget.totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount cannot exceed total amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isLoan) {
      if (widget.customer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a customer for loan sales.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (widget.customer!['server_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This customer is not synced. Please sync before creating a loan.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Return the results
    Navigator.pop(context, {
      'confirmed': true,
      'discount': _discount,
      'note': _noteController.text.trim(),
      'date': _selectedDate,
      'isLoan': _isLoan,
    });
  }
}
