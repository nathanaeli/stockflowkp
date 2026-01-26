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
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/sync_service.dart';
import 'package:barcode_widget/barcode_widget.dart';

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
  Map<String, dynamic>? _tenant;

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

        enrichedItems.add({...item, 'product_name': productName});
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

      // Load Tenant Details
      final tenantRes = await db.query('tenant_account', limit: 1);
      final tenant = tenantRes.isNotEmpty ? tenantRes.first : null;

      if (mounted) {
        setState(() {
          _items = enrichedItems;
          _tenant = tenant;
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
        final mappedItems =
            items
                .map(
                  (item) => {
                    'product_name': item['product']['name'],
                    'product_id': item['product']['id'],
                    'quantity': item['quantity'],
                    'unit_price': item['unit_price'],
                    'subtotal': item['total'],
                    'server_id': item['id'],
                    'discount_amount': item['discount_amount'],
                  },
                )
                .toList();

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
  Future<Uint8List> _generatePdf(
    PdfPageFormat format,
    AppLocalizations localizations,
  ) async {
    final doc = pw.Document();

    // Fetch Tenant Details from tenant_account table
    final db = await DatabaseService().database;
    final tenantRes = await db.query(
      'tenant_account',
      orderBy: 'local_id DESC',
      limit: 1,
    );

    Map<String, dynamic> tenant = {};
    if (tenantRes.isNotEmpty) {
      tenant = tenantRes.first;
      debugPrint('Tenant account loaded: ${tenant['company_name']}');
    } else {
      debugPrint('No tenant account found, using defaults');
    }

    // Use tenant account information for company details
    final companyName =
        (tenant['company_name'] as String?)?.trim().isNotEmpty == true
            ? tenant['company_name'] as String
            : 'StockflowKP';
    final companyAddress =
        (tenant['address'] as String?)?.trim().isNotEmpty == true
            ? tenant['address'] as String
            : '';
    final companyPhone =
        (tenant['phone'] as String?)?.trim().isNotEmpty == true
            ? tenant['phone'] as String
            : '';
    final companyEmail =
        (tenant['email'] as String?)?.trim().isNotEmpty == true
            ? tenant['email'] as String
            : '';
    final logoPath =
        (tenant['logo'] as String?)?.trim().isNotEmpty == true
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

    final invoiceNum =
        _sale['invoice_number']?.toString() ??
        _sale['server_id']?.toString() ??
        "LOC-${_sale['local_id']}";
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
      if (_sale['customer_phone'] != null &&
          (_sale['customer_phone'] as String).isNotEmpty) {
        details.add(_sale['customer_phone'] as String);
      }
      if (_sale['customer_address'] != null &&
          (_sale['customer_address'] as String).isNotEmpty) {
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
          if (customer['phone'] != null &&
              (customer['phone'] as String).isNotEmpty) {
            details.add(customer['phone'] as String);
          }
          if (customer['address'] != null &&
              (customer['address'] as String).isNotEmpty) {
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
        pageFormat: format.copyWith(
          marginLeft: 40,
          marginRight: 40,
          marginTop: 30,
          marginBottom: 30,
        ),
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
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfBlue900,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (companyAddress.isNotEmpty) ...[
                        pw.Text(
                          companyAddress,
                          style: pw.TextStyle(fontSize: 11, color: pdfGrey700),
                        ),
                        pw.SizedBox(height: 4),
                      ],
                      if (companyPhone.isNotEmpty ||
                          companyEmail.isNotEmpty) ...[
                        pw.Row(
                          children: [
                            if (companyPhone.isNotEmpty)
                              pw.Text(
                                "${localizations.tel} $companyPhone",
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: pdfGrey700,
                                ),
                              ),
                            if (companyPhone.isNotEmpty &&
                                companyEmail.isNotEmpty)
                              pw.SizedBox(width: 16),
                            if (companyEmail.isNotEmpty)
                              pw.Text(
                                "${localizations.emailLabel} $companyEmail",
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: pdfBlue700,
                                ),
                              ),
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
                        pw.Text(
                          "INVOICE",
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text(
                              "No: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: pdfWhite70,
                              ),
                            ),
                            pw.Text(
                              invoiceNum,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text(
                              "Date: ",
                              style: pw.TextStyle(color: pdfWhite70),
                            ),
                            pw.Text(
                              dateStr,
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Text(
                              timeStr,
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: pdfWhite70,
                              ),
                            ),
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
                    pw.Container(
                      width: 6,
                      height: 24,
                      color: pdfBlue900,
                      margin: const pw.EdgeInsets.only(right: 12),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            localizations.billTo,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            customerName,
                            style: pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            customerInfo,
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: pdfGrey600,
                            ),
                          ),
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
                  boxShadow: [
                    pw.BoxShadow(
                      color: pdfGrey300,
                      blurRadius: 8,
                      offset: const PdfPoint(0, 2),
                    ),
                  ],
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
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [pdfBlue900, pdfBlue800],
                        ),
                        borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(10),
                        ),
                      ),
                      children: [
                        _tableHeader(
                          localizations.itemDescription,
                          isRight: false,
                        ),
                        _tableHeader(localizations.qty, isRight: false),
                        _tableHeader(localizations.unitPrice, isRight: false),
                        _tableHeader(localizations.total, isRight: true),
                      ],
                    ),
                    ..._items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final isEven = entry.key % 2 == 0;

                      final String description =
                          (item['product_name'] as String?)?.trim() ??
                          localizations.unnamedItem;
                      final String qtyStr =
                          ((item['quantity'] as num?)?.toInt() ?? 0).toString();
                      final String unitPriceStr = _currencyFormat.format(
                        (item['unit_price'] as num?)?.toDouble() ?? 0.0,
                      );
                      final String subtotalStr = _currencyFormat.format(
                        (item['subtotal'] as num?)?.toDouble() ?? 0.0,
                      );

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? pdfGrey25 : PdfColors.white,
                        ),
                        children: [
                          _tableCell(description, padding: 14),
                          _tableCell(qtyStr, alignment: pw.Alignment.center),
                          _tableCell(
                            unitPriceStr,
                            alignment: pw.Alignment.centerRight,
                          ),
                          _tableCell(
                            subtotalStr,
                            alignment: pw.Alignment.centerRight,
                            bold: true,
                          ),
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
                      gradient: pw.LinearGradient(
                        colors: [pdfBlue50, PdfColors.white],
                      ),
                      border: pw.Border.all(color: pdfBlue900, width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                      boxShadow: [
                        pw.BoxShadow(
                          color: withOpacity(pdfBlue200, 0.4),
                          blurRadius: 12,
                          offset: const PdfPoint(0, 4),
                        ),
                      ],
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (discount > 0) ...[
                          _totalRow(
                            localizations.subtotal,
                            _currencyFormat.format(subtotal),
                            color: pdfGrey800,
                            valueColor: pdfGrey900,
                          ),
                          _totalRow(
                            localizations.discount,
                            "-${_currencyFormat.format(discount)}",
                            color: pdfRed700,
                            valueColor: pdfRed700,
                          ),
                          pw.Divider(color: pdfGrey400, thickness: 1.5),
                          pw.SizedBox(height: 8),
                        ],
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: pw.BoxDecoration(
                            color: withOpacity(pdfBlue900, 0.1),
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(
                              color: withOpacity(pdfBlue900, 0.3),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
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
                          ),
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
                        pw.Text(
                          localizations.thankYouChoosing(companyName),
                          style: pw.TextStyle(
                            fontSize: 15,
                            color: pdfBlue900,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        if (companyAddress.isNotEmpty) ...[
                          pw.Text(
                            "$companyAddress",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: pdfGrey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                        ],
                        if (companyPhone.isNotEmpty ||
                            companyEmail.isNotEmpty) ...[
                          pw.Row(
                            children: [
                              if (companyPhone.isNotEmpty)
                                pw.Text(
                                  "$companyPhone",
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: pdfGrey700,
                                  ),
                                ),
                              if (companyPhone.isNotEmpty &&
                                  companyEmail.isNotEmpty)
                                pw.SizedBox(width: 16),
                              if (companyEmail.isNotEmpty)
                                pw.Text(
                                  "$companyEmail",
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: pdfBlue700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        localizations.generatedOn(
                          DateFormat(
                            'dd MMM yyyy HH:mm',
                          ).format(DateTime.now()),
                        ),
                        style: pw.TextStyle(fontSize: 9, color: pdfGrey600),
                      ),
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
      child: pw.Text(
        text.toUpperCase(),
        textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 11.5,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    double padding = 12,
    pw.Alignment? alignment,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.all(padding),
      child: pw.Text(
        text,
        textAlign: alignment == null ? pw.TextAlign.left : null,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
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
      onLayout:
          (PdfPageFormat format) async =>
              _generatePdf(format, AppLocalizations.of(context)!),
    );
  }

  Future<void> _emailPdf() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await _generatePdf(
        PdfPageFormat.a4,
        AppLocalizations.of(context)!,
      );
      final invoiceNum =
          _sale['invoice_number']?.toString() ??
          _sale['server_id']?.toString() ??
          "LOC-${_sale['local_id']}";

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
        body:
            '${AppLocalizations.of(context)!.dearCustomer},\n\n${AppLocalizations.of(context)!.invoiceEmailBody}',
        emails: emails,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.errorSharingInvoice.replaceAll('{error}', e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInvoiceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4BB4FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 40,
                      color: Color(0xFF4BB4FF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.invoiceReady,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invoice #${_sale['invoice_number']?.toString() ?? _sale['server_id']?.toString() ?? "LOC-${_sale['local_id']}"}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.close,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _editSale() async {
    // 1. Pick Date
    final currentTimestamp = _sale['created_at'];
    DateTime initialDate = DateTime.now();
    if (currentTimestamp != null) {
      initialDate = DateTime.tryParse(currentTimestamp) ?? DateTime.now();
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
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

    if (pickedDate == null) return;

    // 2. Pick Time
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
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

    if (pickedTime == null) return;

    // 3. Combine
    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 4. Update
    setState(() => _isLoading = true);
    try {
      final token = await SyncService().getAuthToken();
      if (token == null && _sale['server_id'] != null) {
        throw Exception('Not authenticated');
      }

      final formattedDate = newDateTime.toIso8601String();

      // 4a. Update Server if it's a synced sale
      if (_sale['server_id'] != null) {
        // Construct items payload
        final itemsPayload =
            _items.map((item) {
              return {
                'product_id': item['product_id'] ?? item['server_product_id'],
                'quantity': item['quantity'],
                'unit_price': item['unit_price'],
                'discount_amount': item['discount_amount'] ?? 0,
                'total': item['subtotal'] ?? 0,
              };
            }).toList();

        final updateData = {
          'created_at': formattedDate,
          'customer_id': _sale['customer_id'],
          'total_amount': _sale['total_amount'],
          'discount_amount': _sale['discount_amount'],
          'items': itemsPayload,
          'is_loan': _sale['is_loan'] == 1 || _sale['is_loan'] == true,
        };

        await ApiService().updateSale(_sale['server_id'], updateData, token!);

        // Update local DB by server_id
        final db = await DatabaseService().database;
        await db.update(
          'sales',
          {'created_at': formattedDate},
          where: 'server_id = ?',
          whereArgs: [_sale['server_id']],
        );
      } else {
        // 4b. Update Local only by local_id
        final db = await DatabaseService().database;
        await db.update(
          'sales',
          {'created_at': formattedDate},
          where: 'local_id = ?',
          whereArgs: [_sale['local_id']],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale date updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _sale['created_at'] = formattedDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A1B32),
            title: const Text('Delete Sale'),
            content: const Text(
              'Are you sure you want to delete this sale? This action cannot be undone.',
            ), // meaningful message
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
    );

    if (confirmed == true) {
      _deleteSale();
    }
  }

  Future<void> _deleteSale() async {
    setState(() => _isLoading = true);
    try {
      final token =
          await SyncService()
              .getAuthToken(); // Assuming static or singleton access
      if (token != null && _sale['server_id'] != null) {
        await ApiService().deleteSale(_sale['server_id'], token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to list
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final date = DateTime.tryParse(sale['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(date);
    final isLoan = sale['is_loan'] == 1 || sale['is_loan'] == true;
    final discount = (sale['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    // In checkout: finalTotal = totalAmount - discount.
    // In SaleDetails previous: total was displayed as totalAmount.
    // Let's assume 'total_amount' in DB is the final payable for simple display, or we calculate.
    // Usually total_amount in DB is final. Let's Stick to what was there: "TZS currencyFormat(total)"
    // But wait, the previous UI showed "Subtotal", "Discount", "Total".
    // If I look at the ticket, it just shows "TZS 10,000.00". This is likely the Grand Total.

    final invoiceNum =
        sale['invoice_number']?.toString() ??
        sale['server_id']?.toString() ??
        "LOC-${sale['local_id']}";
    final customerName = sale['customer_name'] ?? 'Walk-in Customer';
    // tenant name? We don't have it easily here without querying tenant_account again or passing it.
    // The previous code didn't show tenant name. I'll use "Stockflow" as placeholder or "Store".

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B32), // Matches app system color
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
        actions: [
          if (sale['server_id'] != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: _editSale,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _confirmDelete,
              tooltip: 'Delete',
            ),
            IconButton(
              icon: const Icon(Icons.cloud_sync_rounded, color: Colors.white),
              onPressed: () => _loadFromApi(showLoading: true),
              tooltip: 'Refresh',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            onPressed: _showInvoiceDialog,
            tooltip: 'Invoice',
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
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4BB4FF)),
                  )
                  : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipPath(
                            clipper: TicketClipper(),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 360),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header
                                  const SizedBox(height: 24),
                                  // Logoish
                                  if (_tenant != null &&
                                      _tenant!['logo'] != null &&
                                      (_tenant!['logo'] as String).isNotEmpty)
                                    // TODO: Load image from path if available, else fallback
                                    // For now, let's stick to the text representation but using tenant name
                                    Container()
                                  else
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF4BB4FF),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            (_tenant?['company_name']
                                                        as String?)
                                                    ?.toUpperCase() ??
                                                "STOCKFLOW",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF4BB4FF),
                                              fontSize: 14,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  // Tenant Details (Phone, Address)
                                  if (_tenant != null) ...[
                                    if (_tenant!['phone'] != null &&
                                        (_tenant!['phone'] as String)
                                            .isNotEmpty)
                                      Text(
                                        "${_tenant!['phone']}",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    if (_tenant!['address'] != null &&
                                        (_tenant!['address'] as String)
                                            .isNotEmpty)
                                      Text(
                                        "${_tenant!['address']}",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    const SizedBox(height: 4),
                                  ],

                                  Text(
                                    "The business that listens", // Motto or slogan
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8,
                                      color: const Color(0xFF4BB4FF),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(
                                    color: Colors.black12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 16),

                                  // RISITI Circle
                                  Text(
                                    "RECEIPT", // RISITI
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.black87,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4BB4FF,
                                        ).withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons
                                          .receipt_outlined, // or check/transfer icon
                                      color: Color(0xFF4BB4FF),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Amount
                                  Text(
                                    "TZS ${_currencyFormat.format(total)}",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Details Table
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildTicketRow("Type", "Sale"),
                                        const SizedBox(height: 12),
                                        _buildTicketRow(
                                          "From",
                                          (_tenant?['company_name']
                                                  as String?) ??
                                              "StockflowKP",
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTicketRow("To", customerName),
                                        const SizedBox(height: 16),

                                        // Itemized List Header
                                        const Divider(color: Colors.black12),
                                        const SizedBox(height: 8),
                                        _buildTicketRow(
                                          "Description",
                                          "Qty  Amt",
                                          isHeader: true,
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(color: Colors.black12),
                                        const SizedBox(height: 8),

                                        // Items List
                                        ..._items.map((item) {
                                          final name =
                                              item['product_name'] ?? 'Unknown';
                                          final qty = item['quantity'] ?? 0;
                                          final price = item['subtotal'] ?? 0.0;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    name,
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          color: Colors.black87,
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    "$qty x ${_currencyFormat.format(price)}",
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          color: Colors.black87,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),

                                        const SizedBox(height: 8),
                                        const Divider(color: Colors.black12),
                                        const SizedBox(height: 8),

                                        // Subtotals
                                        if (discount > 0) ...[
                                          _buildTicketRow(
                                            "Subtotal",
                                            _currencyFormat.format(
                                              total + discount,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildTicketRow(
                                            "Discount",
                                            "-${_currencyFormat.format(discount)}",
                                            valueColor: Colors.red,
                                          ),
                                          const SizedBox(height: 12),
                                        ],

                                        _buildTicketRow(
                                          "Total Payable",
                                          _currencyFormat.format(total),
                                          isHeader: true,
                                        ),
                                        const SizedBox(height: 16),

                                        _buildTicketRow("Ref No", invoiceNum),
                                        const SizedBox(height: 12),
                                        _buildTicketRow("Date", formattedDate),
                                        const SizedBox(height: 12),
                                        _buildTicketRow(
                                          "Status",
                                          isLoan
                                              ? "Pending (Loan)"
                                              : "Completed",
                                          valueColor:
                                              isLoan
                                                  ? Colors.orange
                                                  : Colors.green,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  // Footer Message
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4BB4FF,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Thank you for your business!",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0A1B32),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                ],
                              ),
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

  Widget _buildTicketRow(
    String label,
    String value, {
    Color? valueColor,
    bool isHeader = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isHeader ? Colors.black87 : Colors.black38,
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: valueColor ?? (isHeader ? Colors.black : Colors.black87),
              fontSize: isHeader ? 14 : 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.addOval(
      Rect.fromCircle(center: Offset(0, size.height / 3.5), radius: 12),
    ); // Left notch
    path.addOval(
      Rect.fromCircle(
        center: Offset(size.width, size.height / 3.5),
        radius: 12,
      ),
    ); // Right notch
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
