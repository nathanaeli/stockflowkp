import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'create_sale_page.dart';

class ViewProformaInvoicePage extends StatefulWidget {
  const ViewProformaInvoicePage({super.key});

  @override
  State<ViewProformaInvoicePage> createState() =>
      _ViewProformaInvoicePageState();
}

class _ViewProformaInvoicePageState extends State<ViewProformaInvoicePage> {
  List<Map<String, dynamic>> _proformaInvoices = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadProformaInvoices();
  }

  Future<void> _loadProformaInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await DatabaseService().getAllProformaInvoices();
      if (mounted) {
        setState(() {
          _proformaInvoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load proforma invoices: $e')),
        );
      }
    }
  }

  Future<void> _deleteProformaInvoice(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Delete Proforma Invoice',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to delete this proforma invoice?',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteProformaInvoice(id);
        await _loadProformaInvoices(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proforma invoice deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showProformaDetails(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (_, controller) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1B32).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: _ProformaDetailsSheet(invoice: invoice),
                    ),
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Proforma Invoices',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadProformaInvoices,
          ),
        ],
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
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4BB4FF),
                      ),
                    )
                    : _proformaInvoices.isEmpty
                    ? _buildEmptyState()
                    : _buildInvoiceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.request_quote_outlined,
              size: 40,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Proforma Invoices',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first proforma invoice',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList() {
    return RefreshIndicator(
      onRefresh: _loadProformaInvoices,
      color: const Color(0xFF4BB4FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        itemCount: _proformaInvoices.length,
        itemBuilder: (context, index) {
          final invoice = _proformaInvoices[index];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final customerData = jsonDecode(invoice['customer_data'] as String);
    final itemsData = jsonDecode(invoice['items_data'] as String);
    final createdAt = DateTime.parse(invoice['created_at'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: () => _showProformaDetails(invoice),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.request_quote_rounded,
                      color: Color(0xFF4BB4FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerData['name'] ?? 'Walk-in Customer',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(
                          invoice['total_amount'] as double,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF4BB4FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${itemsData.length} items',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if ((invoice['note'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.note_alt_outlined,
                        color: Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          invoice['note'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showProformaDetails(invoice),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF4BB4FF,
                        ).withOpacity(0.2),
                        foregroundColor: const Color(0xFF4BB4FF),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        () => _deleteProformaInvoice(invoice['id'] as int),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProformaDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  _ProformaDetailsSheet({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final customerData = jsonDecode(invoice['customer_data'] as String);
    final itemsData = jsonDecode(invoice['items_data'] as String) as List;
    final createdAt = DateTime.parse(invoice['created_at'] as String);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Proforma Invoice Details',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF4BB4FF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Customer',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        customerData['name'] ?? 'Walk-in Customer',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (customerData['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          customerData['phone'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Items
                Text(
                  'Items',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                ...itemsData.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Qty: ${item['quantity']} × ${_currencyFormat.format(item['unit_price'] as double)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(item['subtotal'] as double),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4BB4FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4BB4FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4BB4FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(
                          invoice['total_amount'] as double,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF4BB4FF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if ((invoice['note'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Note',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      invoice['note'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  'Created: ${DateFormat('MMM d, yyyy • h:mm a').format(createdAt)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _generatePdf(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4BB4FF),
                      side: const BorderSide(color: Color(0xFF4BB4FF)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Generate PDF',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  CreateSalePage(proformaInvoice: invoice),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BB4FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Convert to Sale',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
            ),
      );

      final db = DatabaseService();
      final tenant = await db.getTenantAccount();

      final doc = pw.Document();

      final customerData = jsonDecode(invoice['customer_data'] as String);
      final itemsData = jsonDecode(invoice['items_data'] as String) as List;
      final createdAt = DateTime.parse(invoice['created_at'] as String);
      final totalAmount = invoice['total_amount'] as double;
      final note = invoice['note'] as String?;

      final primaryColor = PdfColor.fromInt(0xFF4BB4FF);
      final lightGrey = PdfColor.fromInt(0xFFF5F5F5);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          tenant?['company_name'] ?? 'Company Name',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (tenant?['address'] != null)
                          pw.Text(tenant!['address']),
                        if (tenant?['phone'] != null) pw.Text(tenant!['phone']),
                        if (tenant?['email'] != null) pw.Text(tenant!['email']),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'PROFORMA INVOICE',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Date: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                        ),
                        pw.Text(
                          'Time: ${DateFormat('h:mm a').format(createdAt)}',
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customerData['name'] ?? 'Walk-in Customer',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (customerData['phone'] != null)
                        pw.Text(customerData['phone']),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          'Item Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          'Qty',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Price',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                ...itemsData.map((item) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey200),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 4, child: pw.Text(item['name'])),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            item['quantity'].toString(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _currencyFormat.format(item['unit_price']),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _currencyFormat.format(item['subtotal']),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Amount: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _currencyFormat.format(totalAmount),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'Notes:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    note,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'This is a proforma invoice and not a valid tax invoice.',
                    style: const pw.TextStyle(
                      color: PdfColors.grey500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      Navigator.pop(context);
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Proforma_${DateFormat('yyyyMMdd_HHmm').format(createdAt)}',
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
