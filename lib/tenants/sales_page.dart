import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesPage extends StatefulWidget {
  final int? dukaId;

  const SalesPage({super.key, this.dukaId});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _sales = [];
  List<dynamic> _filteredSales = [];
  String? _token;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _dbService.getUserData();
      if (userData != null && userData['data'] != null) {
        _token = userData['data']['token'];
        final response = await _apiService.getTenantSales(
          _token!,
          dukaId: widget.dukaId,
        );

        if (mounted) {
          setState(() {
            _sales = response['data'] ?? [];
            _filteredSales = _sales;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "User session not found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load sales: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _filterSales() {
    setState(() {
      _filteredSales =
          _sales.where((sale) {
            final matchesSearch =
                (sale['invoice_no']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (sale['customer_name']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (sale['duka_name']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
            return matchesSearch;
          }).toList();
    });
  }

  String _formatCurrency(dynamic amount) {
    final formatter = NumberFormat.currency(symbol: 'Tsh ', decimalDigits: 0);
    return formatter.format(amount ?? 0);
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.greenAccent;
        break;
      case 'partial':
        color = Colors.orangeAccent;
        break;
      case 'unpaid':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double _calculateTotalSales() {
    double total = 0;
    for (var sale in _filteredSales) {
      total += (sale['total_amount'] as num? ?? 0).toDouble();
    }
    return total;
  }

  double _calculateTotalPaid() {
    double total = 0;
    for (var sale in _filteredSales) {
      // If we don't have paid_amount, we can estimate somewhat or just use total_amount if status is paid
      // But typically API returns enough info. Let's rely on payment_status or assume fully paid if 'paid'.
      // Better strategy if api doesn't give 'paid_amount':
      // Paid = Total - Remaining.
      final totalAmount = (sale['total_amount'] as num? ?? 0).toDouble();
      final remaining = (sale['remaining_balance'] as num? ?? 0).toDouble();
      total += (totalAmount - remaining);
    }
    return total;
  }

  double _calculateTotalUnpaid() {
    double total = 0;
    for (var sale in _filteredSales) {
      total += (sale['remaining_balance'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Map<String, double> _calculateSalesByDuka() {
    final Map<String, double> summary = {};
    for (var sale in _filteredSales) {
      final duka = sale['duka_name']?.toString() ?? 'Unknown Duka';
      final amount = (sale['total_amount'] as num? ?? 0).toDouble();
      summary[duka] = (summary[duka] ?? 0) + amount;
    }
    return summary;
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final dukaName = "All Dukas";

    // Define custom colors
    final baseColor = PdfColors.blue900;
    final accentColor = PdfColors.blue600;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (pw.Context context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
            ),
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by StockFlow',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: baseColor, width: 2),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Sales Report',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: baseColor,
                        ),
                      ),
                      pw.Text(
                        'Duka: $dukaName',
                        style: pw.TextStyle(fontSize: 14, color: accentColor),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Time: ${DateFormat('HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfSummaryCard(
                  'Total Sales',
                  _formatCurrency(_calculateTotalSales()),
                  baseColor,
                ),
                _buildPdfSummaryCard(
                  'Unpaid Amount',
                  _formatCurrency(_calculateTotalUnpaid()),
                  PdfColors.red700,
                ),
                _buildPdfSummaryCard(
                  'Collected',
                  _formatCurrency(_calculateTotalPaid()),
                  PdfColors.green700,
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Sales Table
            pw.Table.fromTextArray(
              context: context,
              headers: ['Date', 'Invoice', 'Customer', 'Items', 'Total'],
              data:
                  _filteredSales.map((sale) {
                    final itemsCount = (sale['products'] as List).length;
                    return [
                      sale['sale_date'] != null
                          ? DateFormat(
                            'MMM dd\nHH:mm',
                          ).format(DateTime.parse(sale['sale_date']))
                          : '-',
                      sale['invoice_no'] ?? '-',
                      sale['customer_name'] ?? '-',
                      itemsCount.toString(),
                      _formatCurrency(sale['total_amount']),
                    ];
                  }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(color: baseColor),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 8,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
            ),

            pw.SizedBox(height: 20),

            // Duka Summary Table
            pw.Text(
              "Sales Summary by Duka",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: baseColor,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Duka Name',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Total Sales',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Data
                ..._calculateSalesByDuka().entries.map((entry) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.key,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(entry.value),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Sales_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4BB4FF),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search and Actions Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterSales();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search invoice, customer...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _filteredSales.isEmpty ? null : _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14, // Match TextField height approx
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.picture_as_pdf, size: 22),
              ),
            ],
          ),
        ),

        // Sales List
        Expanded(
          child:
              _filteredSales.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No sales records found",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = _filteredSales[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: ExpansionTile(
                          collapsedIconColor: Colors.white54,
                          iconColor: const Color(0xFF4BB4FF),
                          tilePadding: const EdgeInsets.all(12),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sale['invoice_no'] ?? 'N/A',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sale['sale_date'] != null
                                        ? DateFormat(
                                          'MMM dd, yyyy HH:mm',
                                        ).format(
                                          DateTime.parse(sale['sale_date']),
                                        )
                                        : 'Unknown Date',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCurrency(sale['total_amount']),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF4BB4FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusChip(
                                    sale['payment_status'] ?? 'Unknown',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "${sale['customer_name']} • ${sale['duka_name']}",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  ...(sale['products'] as List).map<Widget>((
                                    item,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "${item['quantity']}x ${item['name']}",
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(item['total']),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  if ((sale['remaining_balance'] ?? 0) > 0) ...[
                                    const Divider(color: Colors.white10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Remaining Balance",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(
                                            sale['remaining_balance'],
                                          ),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
