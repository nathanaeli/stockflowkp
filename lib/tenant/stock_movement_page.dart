import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StockMovementPage extends StatefulWidget {
  final List<dynamic> movements;
  final String productName;

  const StockMovementPage({
    Key? key,
    required this.movements,
    required this.productName,
  }) : super(key: key);

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  late List<dynamic> _filteredMovements;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _filteredMovements = widget.movements;
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(2020);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: _selectedDateRange,
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

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filterMovements();
      });
    }
  }

  void _filterMovements() {
    if (_selectedDateRange == null) {
      _filteredMovements = widget.movements;
    } else {
      _filteredMovements = widget.movements.where((m) {
        final dateStr = m['created_at']?.toString();
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr);
          // Include the entire end day
          final end = _selectedDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(seconds: 1))) && date.isBefore(end);
        } catch (_) {
          return false;
        }
      }).toList();
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDateRange = null;
      _filteredMovements = widget.movements;
    });
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
          'Stock Movements',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_selectedDateRange == null ? Icons.calendar_month_rounded : Icons.edit_calendar_rounded, color: Colors.white),
            onPressed: _pickDateRange,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.productName,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
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
              if (_selectedDateRange != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt_rounded, color: Color(0xFF4BB4FF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        onPressed: _clearFilter,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _filteredMovements.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredMovements.length,
                        itemBuilder: (context, index) {
                          return _buildMovementCard(_filteredMovements[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_vert_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No stock movements recorded',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementCard(Map<String, dynamic> movement) {
    final type = movement['type']?.toString().toLowerCase() ?? '';
    final isPositive = (movement['quantity_change']?.toString().startsWith('+') ?? false) || 
                       (double.tryParse(movement['quantity_change']?.toString() ?? '0') ?? 0) > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(type).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(type),
                  color: _getStatusColor(type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDateTime(movement['created_at']),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    movement['quantity_change']?.toString() ?? '0',
                    style: GoogleFonts.plusJakartaSans(
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Quantity',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailColumn('Previous', movement['previous_quantity']?.toString() ?? '-'),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
                _buildDetailColumn('New', movement['new_quantity']?.toString() ?? '-'),
              ],
            ),
          ),
          if (movement['reason'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Reason: ${movement['reason']}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                'By: ${movement['user_name'] ?? 'System'}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String type) {
    if (type.contains('in') || type.contains('add') || type.contains('return')) return Colors.greenAccent;
    if (type.contains('out') || type.contains('remove') || type.contains('sale')) return Colors.redAccent;
    return Colors.blueAccent;
  }

  IconData _getStatusIcon(String type) {
    if (type.contains('in') || type.contains('add')) return Icons.add_circle_outline_rounded;
    if (type.contains('out') || type.contains('remove')) return Icons.remove_circle_outline_rounded;
    if (type.contains('sale')) return Icons.sell_outlined;
    return Icons.swap_vert_rounded;
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}