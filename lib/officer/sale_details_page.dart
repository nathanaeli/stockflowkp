import 'dart:ui';

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
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  final GlobalKey _receiptKey = GlobalKey();
  late Map<String, dynamic> _sale;
  Map<String, dynamic>? _tenant;

  @override
  void initState() {
    super.initState();
    _sale = Map.from(widget.sale);
    _loadItems();

    // Auto-refresh from API if it's a synced sale to ensure latest data and no duplicates
    if (_sale['server_id'] != null) {
      _loadFromApi(showLoading: false);
    }
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
      // Use a map to deduplicate: product_id + scanned_item_id as key
      // Prefer items with server_id (synced items)
      Map<String, Map<String, dynamic>> uniqueItems = {};

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

        final enriched = {...item, 'product_name': productName};
        final key =
            "${item['product_local_id']}_${item['product_item_local_id'] ?? 0}";

        if (!uniqueItems.containsKey(key) ||
            (item['server_id'] != null &&
                uniqueItems[key]!['server_id'] == null)) {
          uniqueItems[key] = enriched;
        }
      }

      enrichedItems = uniqueItems.values.toList();

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

  // ======================= RECEIPT SHARING & PRINTING =======================

  Future<Uint8List?> _captureReceipt() async {
    try {
      // Find the render boundary
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture image
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing receipt: $e');
      return null;
    }
  }

  Future<Uint8List> _buildPdfFromImage(Uint8List imageBytes) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> _printPdf() async {
    setState(() => _isLoading = true);
    try {
      final imageBytes = await _captureReceipt();
      if (imageBytes == null) {
        throw Exception("Failed to capture receipt image");
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => _buildPdfFromImage(imageBytes),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _emailPdf() async {
    setState(() => _isLoading = true);
    try {
      final imageBytes = await _captureReceipt();
      if (imageBytes == null) {
        throw Exception("Failed to capture receipt image");
      }

      final bytes = await _buildPdfFromImage(imageBytes);

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

  Future<void> _sharePdf() async {
    setState(() => _isLoading = true);
    try {
      final imageBytes = await _captureReceipt();
      if (imageBytes == null) {
        throw Exception("Failed to capture receipt image");
      }

      final bytes = await _buildPdfFromImage(imageBytes);

      final invoiceNum =
          _sale['invoice_number']?.toString() ??
          _sale['server_id']?.toString() ??
          "LOC-${_sale['local_id']}";

      // Save to temporary file to share via SharePlus
      final tempDir = await getTemporaryDirectory();
      final file =
          await File('${tempDir.path}/invoice_$invoiceNum.pdf').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice $invoiceNum',
        text:
            'Hello, please find attached the invoice for your purchase at ${_tenant?['company_name'] ?? 'our store'}.',
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
                        _sharePdf();
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: Text(AppLocalizations.of(context)!.shareInvoice),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4BB4FF),
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
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.white,
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
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF0A1B32),
            ),
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
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF0A1B32),
            ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            color: const Color(0xFF0A1B32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tooltip: AppLocalizations.of(context)!.shareInvoice,
            onSelected: (value) {
              switch (value) {
                case 'print':
                  _printPdf();
                  break;
                case 'email':
                  _emailPdf();
                  break;
                case 'share':
                  _sharePdf();
                  break;
                case 'whatsapp':
                  _sharePdf(); // share_plus handles WhatsApp selection
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.greenAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.shareViaWhatsApp,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.share_rounded,
                          color: Color(0xFF4BB4FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.shareInvoice,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'email',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.emailInvoice,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.print_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.printInvoice,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          RepaintBoundary(
                            key: _receiptKey,
                            child: ClipPath(
                              clipper: TicketClipper(),
                              child: Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              (_tenant?['company_name']
                                                          as String?)
                                                      ?.toUpperCase() ??
                                                  "STOCKFLOW",
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFF4BB4FF,
                                                    ),
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
                                                item['product_name'] ??
                                                'Unknown';
                                            final qty = item['quantity'] ?? 0;
                                            final price =
                                                item['subtotal'] ?? 0.0;
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
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          "$qty x ${_currencyFormat.format(item['unit_price'] ?? 0.0)}",
                                                          style:
                                                              GoogleFonts.plusJakartaSans(
                                                                color:
                                                                    Colors
                                                                        .black54,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                        Text(
                                                          _currencyFormat
                                                              .format(price),
                                                          style:
                                                              GoogleFonts.plusJakartaSans(
                                                                color:
                                                                    Colors
                                                                        .black87,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ],
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
                                          _buildTicketRow(
                                            "Date",
                                            formattedDate,
                                          ),
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
