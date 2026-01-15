import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:stockflowkp/services/sale_service.dart';

class SaleDetailsPage extends StatefulWidget {
  final Map<String, dynamic> sale;

  const SaleDetailsPage({super.key, required this.sale});

  @override
  State<SaleDetailsPage> createState() => _SaleDetailsPageState();
}

class _SaleDetailsPageState extends State<SaleDetailsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  late Map<String, dynamic> _sale;

  @override
  void initState() {
    super.initState();
    _sale = Map.from(widget.sale);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final db = await DatabaseService().database;
      final items = await db.query(
        'sale_items',
        where: 'sale_local_id = ?',
        whereArgs: [_sale['local_id']],
      );

      List<Map<String, dynamic>> enrichedItems = [];
      for (var item in items) {
        final products = await db.query(
          'products',
          where: 'local_id = ?',
          whereArgs: [item['product_local_id']],
        );

        String productName = AppLocalizations.of(context)!.unknownProduct;
        if (products.isNotEmpty) {
          productName = products.first['name'] as String;
        }

        enrichedItems.add({
          ...item,
          'product_name': productName,
        });
      }

      // Load customer information if not already available
      if (_sale['customer_id'] != null && _sale['customer_name'] == null) {
        final customerRes = await db.query(
          'customers',
          where: 'server_id = ? OR local_id = ?',
          whereArgs: [_sale['customer_id'], _sale['customer_id']],
          limit: 1,
        );

        if (customerRes.isNotEmpty) {
          final customer = customerRes.first;
          _sale = {
            ..._sale,
            'customer_name': customer['name'] as String?,
            'customer_phone': customer['phone'] as String?,
            'customer_address': customer['address'] as String?,
            'customer_email': customer['email'] as String?,
          };
        }
      }

      if (mounted) {
        setState(() {
          _items = enrichedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sale items: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromApi({bool showLoading = true}) async {
    if (_sale['server_id'] == null) return;

    if (showLoading) setState(() => _isLoading = true);
    try {
      final result = await SaleService().getItemsBySaleId(_sale['server_id']);
      if (result['success'] == true && result['data'] != null) {
        final apiSale = result['data']['sale'];
        final items = result['data']['sale_items'] as List;
        final mappedItems = items.map((item) => {
          'product_name': item['product']['name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'subtotal': item['total'],
          'server_id': item['id'],
          'discount_amount': item['discount_amount'],
        }).toList();

        if (mounted) {
          setState(() {
            _items = List<Map<String, dynamic>>.from(mappedItems);
            if (apiSale != null) {
              _sale = {
                ..._sale,
                ...apiSale,
                'server_id': apiSale['id'],
                // Include customer information from API if available
                'customer_name': apiSale['customer']?['name'],
                'customer_phone': apiSale['customer']?['phone'],
                'customer_address': apiSale['customer']?['address'],
                'customer_email': apiSale['customer']?['email'],
              };
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted && showLoading) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('API load failed: $e');
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  // ======================= PREMIUM PDF GENERATION =======================
  Future<Uint8List> _generatePdf(PdfPageFormat format, AppLocalizations localizations) async {
    final doc = pw.Document();

    // Fetch Tenant Details from tenant_account table
    final db = await DatabaseService().database;
    final tenantRes = await db.query(
      'tenant_account', 
      orderBy: 'local_id DESC',
      limit: 1
    );
    
    Map<String, dynamic> tenant = {};
    if (tenantRes.isNotEmpty) {
      tenant = tenantRes.first;
      debugPrint('Tenant account loaded: ${tenant['company_name']}');
    } else {
      debugPrint('No tenant account found, using defaults');
    }

    // Use tenant account information for company details
    final companyName = (tenant['company_name'] as String?)?.trim().isNotEmpty == true 
        ? tenant['company_name'] as String 
        : 'StockflowKP';
    final companyAddress = (tenant['address'] as String?)?.trim().isNotEmpty == true 
        ? tenant['address'] as String 
        : '';
    final companyPhone = (tenant['phone'] as String?)?.trim().isNotEmpty == true 
        ? tenant['phone'] as String 
        : '';
    final companyEmail = (tenant['email'] as String?)?.trim().isNotEmpty == true 
        ? tenant['email'] as String 
        : '';
    final logoPath = (tenant['logo'] as String?)?.trim().isNotEmpty == true 
        ? tenant['logo'] as String 
        : null;

    pw.ImageProvider? logoImage;
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final file = File(logoPath);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          logoImage = pw.MemoryImage(imageBytes);
        }
      } catch (e) {
        debugPrint('Error loading logo for PDF: $e');
      }
    }

    final invoiceNum = _sale['invoice_number']?.toString() ?? _sale['server_id']?.toString() ?? "LOC-${_sale['local_id']}";
    final date = DateTime.tryParse(_sale['created_at'] ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final timeStr = DateFormat('HH:mm').format(date);
    final total = (_sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final discount = (_sale['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = total + discount;

    // Use customer information from the sale object (loaded in _loadItems)
    String customerName = localizations.walkInCustomer;
    String customerInfo = localizations.cashSale;

    if (_sale['customer_name'] != null) {
      customerName = _sale['customer_name'] as String;
      
      final List<String> details = [];
      if (_sale['customer_phone'] != null && (_sale['customer_phone'] as String).isNotEmpty) {
        details.add(_sale['customer_phone'] as String);
      }
      if (_sale['customer_address'] != null && (_sale['customer_address'] as String).isNotEmpty) {
        details.add(_sale['customer_address'] as String);
      }
      
      if (details.isNotEmpty) {
        customerInfo = details.join(' • ');
      } else {
        customerInfo = 'Registered Customer';
      }
    } else if (_sale['customer_id'] != null) {
      // Fallback: Try to fetch customer info if not already loaded
      try {
        final customerRes = await db.query(
          'customers',
          where: 'server_id = ? OR local_id = ?',
          whereArgs: [_sale['customer_id'], _sale['customer_id']],
          limit: 1,
        );

        if (customerRes.isNotEmpty) {
          final customer = customerRes.first;
          customerName = customer['name'] as String? ?? localizations.customer;
          
          final List<String> details = [];
          if (customer['phone'] != null && (customer['phone'] as String).isNotEmpty) {
            details.add(customer['phone'] as String);
          }
          if (customer['address'] != null && (customer['address'] as String).isNotEmpty) {
            details.add(customer['address'] as String);
          }
          
          if (details.isNotEmpty) {
            customerInfo = details.join(' • ');
          } else {
            customerInfo = localizations.registeredCustomer;
          }
        }
      } catch (e) {
        debugPrint('Error fetching customer info for PDF: $e');
      }
    }

    // Define custom colors to match Material design
    final pdfBlue900 = PdfColor.fromInt(0xFF0D47A1);
    final pdfBlue800 = PdfColor.fromInt(0xFF1565C0);
    final pdfBlue700 = PdfColor.fromInt(0xFF1976D2);
    final pdfBlue200 = PdfColor.fromInt(0xFF90CAF9);
    final pdfBlue50 = PdfColor.fromInt(0xFFE3F2FD);
    final pdfGrey900 = PdfColor.fromInt(0xFF212121);
    final pdfGrey800 = PdfColor.fromInt(0xFF424242);
    final pdfGrey700 = PdfColor.fromInt(0xFF616161);
    final pdfGrey600 = PdfColor.fromInt(0xFF757575);
    final pdfGrey400 = PdfColor.fromInt(0xFFBDBDBD);
    final pdfGrey300 = PdfColor.fromInt(0xFFE0E0E0);
    final pdfGrey200 = PdfColor.fromInt(0xFFEEEEEE);
    final pdfGrey50 = PdfColor.fromInt(0xFFFAFAFA);
    final pdfGrey25 = PdfColor.fromInt(0xFFF8F9FA);
    final pdfRed700 = PdfColor.fromInt(0xFFD32F2F);
    final pdfWhite70 = PdfColor.fromInt(0xB3FFFFFF);

    PdfColor withOpacity(PdfColor color, double opacity) {
      return PdfColor(color.red, color.green, color.blue, opacity);
    }

    doc.addPage(
      pw.Page(
        pageFormat: format.copyWith(marginLeft: 40, marginRight: 40, marginTop: 30, marginBottom: 30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 100,
                          height: 100,
                          margin: const pw.EdgeInsets.only(bottom: 12),
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(12),
                            boxShadow: [
                              pw.BoxShadow(
                                color: pdfGrey400,
                                blurRadius: 8,
                                offset: const PdfPoint(0, 4),
                              ),
                            ],
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 12,
                            verticalRadius: 12,
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ),
                      pw.Text(companyName,
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pdfBlue900)),
                      pw.SizedBox(height: 8),
                      if (companyAddress.isNotEmpty) ...[
                        pw.Text(companyAddress, style: pw.TextStyle(fontSize: 11, color: pdfGrey700)),
                        pw.SizedBox(height: 4),
                      ],
                      if (companyPhone.isNotEmpty || companyEmail.isNotEmpty) ...[
                        pw.Row(
                          children: [
                            if (companyPhone.isNotEmpty) 
                              pw.Text("${localizations.tel} $companyPhone", style: pw.TextStyle(fontSize: 11, color: pdfGrey700)),
                            if (companyPhone.isNotEmpty && companyEmail.isNotEmpty)
                              pw.SizedBox(width: 16),
                            if (companyEmail.isNotEmpty) 
                              pw.Text("${localizations.emailLabel} $companyEmail", style: pw.TextStyle(fontSize: 11, color: pdfBlue700)),
                          ],
                        ),
                      ],
                    ],
                  ),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [pdfBlue900, pdfBlue800],
                        begin: pw.Alignment.topLeft,
                        end: pw.Alignment.bottomRight,
                      ),
                      borderRadius: pw.BorderRadius.circular(12),
                      boxShadow: [
                        pw.BoxShadow(
                          color: withOpacity(pdfBlue900, 0.3),
                          blurRadius: 12,
                          offset: const PdfPoint(0, 6),
                        ),
                      ],
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("INVOICE",
                            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.SizedBox(height: 16),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text("No: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdfWhite70)),
                            pw.Text(invoiceNum, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text("Date: ", style: pw.TextStyle(color: pdfWhite70)),
                            pw.Text(dateStr, style: pw.TextStyle(fontSize: 14, color: PdfColors.white)),
                            pw.SizedBox(width: 12),
                            pw.Text(timeStr, style: pw.TextStyle(fontSize: 12, color: pdfWhite70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 35),

              // Bill To
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: pdfGrey50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: pdfGrey200),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(width: 6, height: 24, color: pdfBlue900, margin: const pw.EdgeInsets.only(right: 12)),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(localizations.billTo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                          pw.SizedBox(height: 6),
                          pw.Text(customerName, style: pw.TextStyle(fontSize: 12)),
                          pw.Text(customerInfo, style: pw.TextStyle(fontSize: 11, color: pdfGrey600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 35),
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  boxShadow: [pw.BoxShadow(color: pdfGrey300, blurRadius: 8, offset: const PdfPoint(0, 2))],
                  border: pw.Border.all(color: pdfGrey200),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(color: pdfGrey200, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(5),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(colors: [pdfBlue900, pdfBlue800]),
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(10)),
                      ),
                      children: [
                        _tableHeader(localizations.itemDescription, isRight: false),
                        _tableHeader(localizations.qty, isRight: false),
                        _tableHeader(localizations.unitPrice, isRight: false),
                        _tableHeader(localizations.total, isRight: true),
                      ],
                    ),
                    ..._items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final isEven = entry.key % 2 == 0;

                      final String description = (item['product_name'] as String?)?.trim() ?? localizations.unnamedItem;
                      final String qtyStr = ((item['quantity'] as num?)?.toInt() ?? 0).toString();
                      final String unitPriceStr = _currencyFormat.format((item['unit_price'] as num?)?.toDouble() ?? 0.0);
                      final String subtotalStr = _currencyFormat.format((item['subtotal'] as num?)?.toDouble() ?? 0.0);

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: isEven ? pdfGrey25 : PdfColors.white),
                        children: [
                          _tableCell(description, padding: 14),
                          _tableCell(qtyStr, alignment: pw.Alignment.center),
                          _tableCell(unitPriceStr, alignment: pw.Alignment.centerRight),
                          _tableCell(subtotalStr, alignment: pw.Alignment.centerRight, bold: true),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(height: 35),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 280,
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(colors: [pdfBlue50, PdfColors.white]),
                      border: pw.Border.all(color: pdfBlue900, width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                      boxShadow: [pw.BoxShadow(color: withOpacity(pdfBlue200, 0.4), blurRadius: 12, offset: const PdfPoint(0, 4))],
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (discount > 0) ...[
                          _totalRow(localizations.subtotal, _currencyFormat.format(subtotal), color: pdfGrey800, valueColor: pdfGrey900),
                          _totalRow(localizations.discount, "-${_currencyFormat.format(discount)}", color: pdfRed700, valueColor: pdfRed700),
                          pw.Divider(color: pdfGrey400, thickness: 1.5),
                          pw.SizedBox(height: 8),
                        ],
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: pw.BoxDecoration(
                            color: withOpacity(pdfBlue900, 0.1),
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: withOpacity(pdfBlue900, 0.3)),
                          ),
                          child: pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text(
      localizations.totalAmountPdf,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
        color: PdfColors.white, // White color
        letterSpacing: 1.2,
      ),
    ),
    pw.Text(
      "TZS ${_currencyFormat.format(total)}",
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 15,
        color: PdfColors.white, // White color
        letterSpacing: 0.5,
      ),
    ),
  ],
)

                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer with Company Contact Information
              pw.Divider(color: pdfGrey300),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(localizations.thankYouChoosing(companyName),
                            style: pw.TextStyle(fontSize: 15, color: pdfBlue900, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        if (companyAddress.isNotEmpty) ...[
                          pw.Text("$companyAddress", 
                              style: pw.TextStyle(fontSize: 10, color: pdfGrey700)),
                          pw.SizedBox(height: 4),
                        ],
                        if (companyPhone.isNotEmpty || companyEmail.isNotEmpty) ...[
                          pw.Row(
                            children: [
                              if (companyPhone.isNotEmpty) 
                                pw.Text("$companyPhone", 
                                    style: pw.TextStyle(fontSize: 10, color: pdfGrey700)),
                              if (companyPhone.isNotEmpty && companyEmail.isNotEmpty)
                                pw.SizedBox(width: 16),
                              if (companyEmail.isNotEmpty) 
                                pw.Text("$companyEmail", 
                                    style: pw.TextStyle(fontSize: 10, color: pdfBlue700)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(localizations.generatedOn(DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())),
                          style: pw.TextStyle(fontSize: 9, color: pdfGrey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // Helper Widgets
  pw.Widget _tableHeader(String text, {bool isRight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: pw.Text(text.toUpperCase(),
          textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11.5)),
    );
  }

  pw.Widget _tableCell(String text,
      {double padding = 12, pw.Alignment? alignment, bool bold = false, PdfColor? color}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(padding),
      child: pw.Text(text,
          textAlign: alignment == null ? pw.TextAlign.left : null,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

 pw.Widget _totalRow(
  String label,
  String value, {
  PdfColor? color,
  PdfColor? valueColor,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 13,
            color: color ?? PdfColors.white, // default white
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: valueColor ?? PdfColors.white, // default white
          ),
        ),
      ],
    ),
  );
}



  Future<void> _printPdf() async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => _generatePdf(format, AppLocalizations.of(context)!),
    );
  }

  Future<void> _emailPdf() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await _generatePdf(PdfPageFormat.a4, AppLocalizations.of(context)!);
      final invoiceNum = _sale['invoice_number']?.toString() ?? _sale['server_id']?.toString() ?? "LOC-${_sale['local_id']}";

      List<String>? emails;
      if (_sale['customer_id'] != null) {
        final db = await DatabaseService().database;
        final results = await db.query(
          'customers',
          columns: ['email'],
          where: 'server_id = ? OR local_id = ?',
          whereArgs: [_sale['customer_id'], _sale['customer_id']],
          limit: 1,
        );
        if (results.isNotEmpty && results.first['email'] != null) {
          final email = results.first['email'].toString();
          if (email.isNotEmpty) emails = [email];
        }
      }

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice_$invoiceNum.pdf',
        subject: 'Invoice $invoiceNum',
        body: '${AppLocalizations.of(context)!.dearCustomer},\n\n${AppLocalizations.of(context)!.invoiceEmailBody}',
        emails: emails,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSharingInvoice.replaceAll('{error}', e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInvoiceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0A1B32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF4BB4FF).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF4BB4FF)),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context)!.invoiceReady, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Invoice #${_sale['invoice_number']?.toString() ?? _sale['server_id']?.toString() ?? "LOC-${_sale['local_id']}"}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _printPdf();
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: Text(AppLocalizations.of(context)!.printInvoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _emailPdf();
                  },
                  icon: const Icon(Icons.email_rounded),
                  label: Text(AppLocalizations.of(context)!.emailInvoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4BB4FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.close, style: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final date = DateTime.tryParse(sale['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
    final isLoan = sale['is_loan'] == 1 || sale['is_loan'] == true;
    final discount = (sale['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B32),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(AppLocalizations.of(context)!.saleDetails, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (sale['server_id'] != null)
            IconButton(icon: const Icon(Icons.cloud_sync_rounded, color: Colors.white), onPressed: _loadFromApi, tooltip: AppLocalizations.of(context)!.refresh),
          IconButton(icon: const Icon(Icons.receipt_long_rounded, color: Colors.white), onPressed: _showInvoiceDialog, tooltip: AppLocalizations.of(context)!.invoice),
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
              : RefreshIndicator(
                  onRefresh: () => _loadFromApi(showLoading: false),
                  color: const Color(0xFF4BB4FF),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sale #${sale['invoice_number']?.toString() ?? sale['server_id']?.toString() ?? "LOC-${sale['local_id']}"}',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white54),
                                      const SizedBox(width: 6),
                                      Text(formattedDate, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isLoan ? Colors.orange : Colors.green).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isLoan ? AppLocalizations.of(context)!.loan : AppLocalizations.of(context)!.paid,
                                  style: GoogleFonts.plusJakartaSans(color: isLoan ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Customer Info
                        if (sale['customer_name'] != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, color: Color(0xFF4BB4FF), size: 24),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context)!.customer.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                    Text(sale['customer_name'], style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.itemsPurchased, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
                            Text(AppLocalizations.of(context)!.itemsCount(_items.length.toString()), style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                                ((item['quantity'] as num? ?? 0) * (item['unit_price'] as num? ?? 0));
                            final itemDiscount = (item['discount_amount'] as num?)?.toDouble() ?? 0.0;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF4BB4FF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF4BB4FF)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['product_name'] ?? AppLocalizations.of(context)!.unknownProduct, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w500)),
                                        Text('${item['quantity']} × ${_currencyFormat.format(item['unit_price'])}',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11)),
                                        if (itemDiscount > 0)
                                          Text('Discount: -${_currencyFormat.format(itemDiscount)}',
                                              style: GoogleFonts.plusJakartaSans(color: Colors.greenAccent, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Text(_currencyFormat.format(subtotal),
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Summary
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [const Color.fromARGB(255, 38, 38, 39).withOpacity(0.1), Colors.transparent]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              if (discount > 0) ...[
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(AppLocalizations.of(context)!.subtotal, style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                                  Text('TZS ${_currencyFormat.format(total + discount)}', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                                ]),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(AppLocalizations.of(context)!.discount, style: GoogleFonts.plusJakartaSans(color: Colors.greenAccent)),
                                  Text('- TZS ${_currencyFormat.format(discount)}', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                                ]),
                                const Divider(color: Colors.white10, height: 24),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(AppLocalizations.of(context)!.totalAmount, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('TZS ${_currencyFormat.format(total)}',
                                      style: GoogleFonts.plusJakartaSans(color: const Color.fromARGB(255, 145, 152, 156), fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}