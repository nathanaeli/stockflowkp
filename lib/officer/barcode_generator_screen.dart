import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

class BarcodeGeneratorScreen extends StatefulWidget {
  const BarcodeGeneratorScreen({super.key});

  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  final TextEditingController _quantityController = TextEditingController(
    text: '50',
  );
  bool _isGenerating = false;
  List<String> _generatedBarcodes = [];
  bool _showPreview = false;
  final Uuid _uuid = const Uuid();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _generateBarcodes() async {
    final quantity = int.tryParse(_quantityController.text);

    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    if (quantity < 1 || quantity > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be between 1 and 200')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedBarcodes = [];
    });

    // Generate unique barcode numbers using UUID
    final barcodes = <String>[];
    for (int i = 0; i < quantity; i++) {
      // Generate a unique barcode by taking first 12 characters of UUID and converting to uppercase
      final uuid = _uuid.v4().replaceAll('-', '').toUpperCase();
      final barcode = uuid.substring(0, 12);
      barcodes.add(barcode);
    }

    setState(() {
      _generatedBarcodes = barcodes;
      _isGenerating = false;
      _showPreview = true;
    });
  }

  Future<void> _generateAndSavePdf() async {
    if (_generatedBarcodes.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final pdf = pw.Document();

      // Create pages with barcodes (3 per row, 10 per page for better print quality)
      const int barcodesPerRow = 3;
      const int rowsPerPage = 10;
      const int barcodesPerPage = barcodesPerRow * rowsPerPage;

      for (
        int pageStart = 0;
        pageStart < _generatedBarcodes.length;
        pageStart += barcodesPerPage
      ) {
        final pageBarcodes = _generatedBarcodes.sublist(
          pageStart,
          (pageStart + barcodesPerPage) > _generatedBarcodes.length
              ? _generatedBarcodes.length
              : pageStart + barcodesPerPage,
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'StockFlowKp Barcode Generator',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              'Generated: ${DateTime.now().toString().split('.')[0]}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey300,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'Page ${pageStart ~/ barcodesPerPage + 1}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Barcodes
                  ..._buildPdfRows(pageBarcodes, barcodesPerRow),
                  // Footer
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Barcodes: ${_generatedBarcodes.length}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Generated by StockFlowKp App',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/stockflowkp_barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Open the PDF instead of sharing
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Professional PDF generated and opened!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  List<pw.Widget> _buildPdfRows(List<String> barcodes, int perRow) {
    final rows = <pw.Widget>[];

    for (int i = 0; i < barcodes.length; i += perRow) {
      final rowBarcodes = barcodes.sublist(
        i,
        (i + perRow) > barcodes.length ? barcodes.length : i + perRow,
      );

      rows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children:
              rowBarcodes
                  .map((barcode) => _buildPdfBarcodeItem(barcode))
                  .toList(),
        ),
      );

      if (i + perRow < barcodes.length) {
        rows.add(pw.SizedBox(height: 20));
      }
    }

    return rows;
  }

  pw.Widget _buildPdfBarcodeItem(String barcode) {
    return pw.Container(
      width: 180,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: 80,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.BarcodeWidget(
              barcode: Barcode.code128(),
              data: barcode,
              width: 160,
              height: 70,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text(
              barcode,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fontScale = size.width < 360 ? 0.85 : (size.width < 600 ? 0.95 : 1.0);
    final isSmallScreen = size.width < 400;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Barcode Generator',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18 * fontScale,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_generatedBarcodes.isNotEmpty)
            _buildGlassIconButton(
              icon: Icons.picture_as_pdf_rounded,
              onTap: _isGenerating ? null : _generateAndSavePdf,
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input Section
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.settings_rounded,
                                    color: Color(0xFF4BB4FF),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Barcode Generation Settings',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14 * fontScale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _quantityController,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 14 * fontScale,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Quantity (1-200)',
                                      hintText:
                                          'Number of barcodes to generate',
                                      labelStyle: GoogleFonts.plusJakartaSans(
                                        color: Colors.white70,
                                        fontSize: 13 * fontScale,
                                      ),
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        color: Colors.white38,
                                        fontSize: 13 * fontScale,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.only(
                                          left: 12,
                                          right: 8,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4BB4FF,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.format_list_numbered_rounded,
                                          color: Color(0xFF4BB4FF),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4BB4FF),
                                    Color(0xFF1E88E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4BB4FF,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isGenerating ? null : _generateBarcodes,
                                icon:
                                    _isGenerating
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 18,
                                        ),
                                label: Text(
                                  _isGenerating
                                      ? 'Generating...'
                                      : 'Generate Barcodes',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14 * fontScale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
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

                const SizedBox(height: 20),

                // Preview Section
                if (_showPreview && _generatedBarcodes.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Generated Barcodes (${_generatedBarcodes.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14 * fontScale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: _generateAndSavePdf,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4BB4FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4BB4FF).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 14,
                                color: Color(0xFF4BB4FF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Export PDF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11 * fontScale,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4BB4FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        height: size.height * 0.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: GridView.builder(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    size.width > 600
                                        ? 4
                                        : (size.width > 400 ? 3 : 2),
                                crossAxisSpacing: isSmallScreen ? 10 : 16,
                                mainAxisSpacing: isSmallScreen ? 10 : 16,
                                childAspectRatio: 0.9,
                              ),
                          itemCount: _generatedBarcodes.length,
                          itemBuilder: (context, index) {
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 500),
                              child: _buildBarcodeItem(
                                _generatedBarcodes[index],
                                fontScale,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeItem(String barcode, double fontScale) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: barcode,
                    width: double.infinity,
                    height: 40,
                    color: Colors.white,
                    drawText: false,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BB4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  barcode,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9 * fontScale,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
