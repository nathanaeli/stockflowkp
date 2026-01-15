import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:stockflowkp/l10n/app_localizations.dart';
import 'package:stockflowkp/services/database_service.dart';

class SalesAnalyticsPage extends StatefulWidget {
  const SalesAnalyticsPage({super.key});

  @override
  State<SalesAnalyticsPage> createState() => _SalesAnalyticsPageState();
}

class _SalesAnalyticsPageState extends State<SalesAnalyticsPage> {
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _compareSalesData = [];
  List<Map<String, dynamic>> _categorySales = [];
  List<Map<String, dynamic>> _topProducts = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  late DateTimeRange _selectedDateRange;
  DateTimeRange? _compareDateRange;
  bool _isComparing = false;
  int? _selectedCategoryId;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService().getSalesStatsByDateRange(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );
      
      final categoryData = await DatabaseService().getSalesByCategory(_selectedDateRange);
      final topProductsData = await DatabaseService().getTopSellingProducts(_selectedDateRange, categoryId: _selectedCategoryId);

      List<Map<String, dynamic>> compareData = [];
      if (_isComparing && _compareDateRange != null) {
        compareData = await DatabaseService().getSalesStatsByDateRange(
          _compareDateRange!.start,
          _compareDateRange!.end,
        );
      }
      
      // Fill in missing days for the last 7 days
      final List<Map<String, dynamic>> fullData = [];
      final List<Map<String, dynamic>> fullCompareData = [];
      final daysDifference = _selectedDateRange.end.difference(_selectedDateRange.start).inDays;
      
      for (int i = 0; i <= daysDifference; i++) {
        final date = _selectedDateRange.start.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        final existingEntry = data.firstWhere(
          (element) => element['sale_date'] == dateStr,
          orElse: () => {'sale_date': dateStr, 'total_amount': 0.0, 'count': 0},
        );
        
        fullData.add({
          'date': date,
          'day_name': DateFormat('E').format(date),
          'full_date': DateFormat('MMM d').format(date),
          'total': (existingEntry['total_amount'] as num?)?.toDouble() ?? 0.0,
          'count': (existingEntry['count'] as num?)?.toInt() ?? 0,
        });

        if (_isComparing && _compareDateRange != null) {
           final compareDate = _compareDateRange!.start.add(Duration(days: i));
           final compareDateStr = DateFormat('yyyy-MM-dd').format(compareDate);
           final existingCompareEntry = compareData.firstWhere(
             (element) => element['sale_date'] == compareDateStr,
             orElse: () => {'sale_date': compareDateStr, 'total_amount': 0.0, 'count': 0},
           );

           fullCompareData.add({
             'date': compareDate,
             'day_name': DateFormat('E').format(compareDate),
             'full_date': DateFormat('MMM d').format(compareDate),
             'total': (existingCompareEntry['total_amount'] as num?)?.toDouble() ?? 0.0,
             'count': (existingCompareEntry['count'] as num?)?.toInt() ?? 0,
           });
        }
      }

      if (mounted) {
        setState(() {
          _salesData = fullData;
          _compareSalesData = fullCompareData;
          _categorySales = categoryData;
          _topProducts = topProductsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTopProducts() async {
    final topProductsData = await DatabaseService().getTopSellingProducts(_selectedDateRange, categoryId: _selectedCategoryId);
    if (mounted) {
      setState(() {
        _topProducts = topProductsData;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadData();
    }
  }

  Future<void> _selectCompareDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _compareDateRange ?? DateTimeRange(
        start: _selectedDateRange.start.subtract(const Duration(days: 7)),
        end: _selectedDateRange.start.subtract(const Duration(days: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orangeAccent,
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
        _compareDateRange = picked;
        _isComparing = true;
      });
      _loadData();
    }
  }

  void _toggleCompare() {
    setState(() {
      _isComparing = !_isComparing;
      if (_isComparing && _compareDateRange == null) {
        final duration = _selectedDateRange.end.difference(_selectedDateRange.start);
        _compareDateRange = DateTimeRange(
          start: _selectedDateRange.start.subtract(duration).subtract(const Duration(days: 1)),
          end: _selectedDateRange.start.subtract(const Duration(days: 1)),
        );
      }
    });
    _loadData();
  }

  Future<void> _exportExcel() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Report'];
      
      // Add headers
      sheetObject.appendRow([
        TextCellValue('Date'), 
        TextCellValue('Day'), 
        TextCellValue('Sales Count'), 
        TextCellValue('Total Revenue')
      ]);
      
      // Add data
      for (var item in _salesData) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(item['date'])),
          TextCellValue(item['day_name']),
          IntCellValue(item['count']),
          DoubleCellValue(item['total']),
        ]);
      }
      
      // Save
      final fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      
      // Write the file
      await file.writeAsBytes(fileBytes!);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sales exported successfully to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations.errorExportingExcel}: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportReport() async {
    final localizations = AppLocalizations.of(context)!;
    final doc = pw.Document();
    final font = await PdfGoogleFonts.plusJakartaSansRegular();
    final boldFont = await PdfGoogleFonts.plusJakartaSansBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sales Summary Report', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                    pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: pw.TextStyle(font: font, fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(localizations.last7DaysPerformance, style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E4976)),
                cellStyle: pw.TextStyle(font: font),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>[localizations.date, localizations.day, localizations.salesCount, localizations.totalRevenue],
                  ..._salesData.map((item) => [
                    DateFormat('MMM d').format(item['date'] as DateTime),
                    item['day_name'] as String,
                    item['count'].toString(),
                    _currencyFormat.format(item['total']),
                  ]),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Revenue: ${_currencyFormat.format(_salesData.fold(0.0, (sum, item) => sum + (item['total'] as double)))}',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalRevenue = _salesData.fold(0, (sum, item) => sum + (item['total'] as double));
    final int totalSales = _salesData.fold(0, (sum, item) => sum + (item['count'] as int));
    
    double compareTotalRevenue = 0.0;
    if (_isComparing) {
      compareTotalRevenue = _compareSalesData.fold(0, (sum, item) => sum + (item['total'] as double));
    }

    // Calculate max value for chart scaling considering both datasets
    double maxVal = _salesData.fold(0.0, (max, item) => (item['total'] as double) > max ? (item['total'] as double) : max);
    if (_isComparing) {
      final double compareMax = _compareSalesData.fold(0.0, (max, item) => (item['total'] as double) > max ? (item['total'] as double) : max);
      if (compareMax > maxVal) maxVal = compareMax;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.salesAnalytics,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.last7DaysOverview,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildIconButton(Icons.picture_as_pdf_rounded, Colors.redAccent, _exportReport),
                    const SizedBox(width: 8),
                    _buildIconButton(Icons.table_view_rounded, Colors.greenAccent, _exportExcel),
                  ],
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                // Date Range Selectors
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4BB4FF).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Color(0xFF4BB4FF), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${DateFormat('MMM d').format(_selectedDateRange.start)} - ${DateFormat('MMM d').format(_selectedDateRange.end)}",
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Compare Toggle
                    GestureDetector(
                      onTap: _toggleCompare,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isComparing ? Colors.orangeAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isComparing ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                        ),
                        child: Icon(Icons.compare_arrows_rounded, color: _isComparing ? Colors.orangeAccent : Colors.white54, size: 20),
                      ),
                    ),
                  ],
                ),
                if (_isComparing) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectCompareDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("${AppLocalizations.of(context)!.vs} ", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12)),
                        Text(
                          _compareDateRange != null 
                            ? "${DateFormat('MMM d').format(_compareDateRange!.start)} - ${DateFormat('MMM d').format(_compareDateRange!.end)}"
                            : AppLocalizations.of(context)!.selectRange,
                          style: GoogleFonts.plusJakartaSans(color: Colors.orangeAccent, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Colors.orangeAccent, size: 16),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _isLoading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF4BB4FF))))
              : Column(
                  children: [
                    // Summary Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              AppLocalizations.of(context)!.totalRevenue,
                              _currencyFormat.format(totalRevenue),
                              Icons.attach_money_rounded,
                              const Color(0xFF4BB4FF),
                              compareValue: _isComparing ? _currencyFormat.format(compareTotalRevenue) : null,
                              isComparing: _isComparing,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              AppLocalizations.of(context)!.totalSales,
                              totalSales.toString(),
                              Icons.shopping_bag_rounded,
                              Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Graph Container
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 300,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.revenueTrend,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_upward_rounded, color: Colors.green, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)!.weekly,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: _salesData.map((data) {
                                  final double heightFactor = maxVal > 0 ? (data['total'] as double) / maxVal : 0.0;
                                  return _buildBar(
                                    data['day_name'],
                                    heightFactor,
                                    data['total'] as double,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent List Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        AppLocalizations.of(context)!.dailyBreakdown,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),

        SliverToBoxAdapter(
          child: _isLoading 
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.salesByCategory,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCategoryPieChart(),
                      const SizedBox(height: 24),

                      Text(
                        _selectedCategoryId != null ? AppLocalizations.of(context)!.topProductsSelectedCategory : AppLocalizations.of(context)!.topSellingProducts,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTopProductsList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),

        // List Items
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Reverse order for list (newest first)
                final item = _salesData[_salesData.length - 1 - index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4BB4FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['day_name'],
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF4BB4FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(item['date']),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "${item['count']} ${AppLocalizations.of(context)!.salesCount}",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currencyFormat.format(item['total']),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: _salesData.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPieChart() {
    if (_categorySales.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(child: Text(AppLocalizations.of(context)!.noCategoryDataAvailable, style: GoogleFonts.plusJakartaSans(color: Colors.white54))),
      );
    }

    final double totalRevenue = _categorySales.fold(0, (sum, item) => sum + (item['total'] as num).toDouble());
    final List<Color> colors = [
      const Color(0xFF4BB4FF),
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.redAccent,
      Colors.tealAccent,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;

                      if (event is FlTapUpEvent) {
                        final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < _categorySales.length) {
                          final cat = _categorySales[index];
                          final catId = cat['category_id'] as int?;
                          // Toggle selection
                          _selectedCategoryId = (_selectedCategoryId == catId) ? null : catId;
                          _loadTopProducts();
                        }
                      }
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(_categorySales.length, (i) {
                  final cat = _categorySales[i];
                  final value = (cat['total'] as num).toDouble();
                  final percentage = totalRevenue > 0 ? (value / totalRevenue * 100).toStringAsFixed(1) : '0.0';
                  final color = colors[i % colors.length];
                  final isSelected = _selectedCategoryId == cat['category_id'];
                  final isTouched = i == _touchedIndex;
                  final double radius = isSelected || isTouched ? 60 : 50;
                  
                  return PieChartSectionData(
                    color: color,
                    value: value,
                    title: '$percentage%',
                    radius: radius,
                    titleStyle: GoogleFonts.plusJakartaSans(
                      fontSize: isSelected || isTouched ? 12 : 10, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(_categorySales.length, (i) {
              final cat = _categorySales[i];
              final name = cat['name'] ?? AppLocalizations.of(context)!.uncategorized;
              final value = (cat['total'] as num).toDouble();
              final color = colors[i % colors.length];
              final isSelected = _selectedCategoryId == cat['category_id'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isSelected ? 16 : 12, 
                      height: isSelected ? 16 : 12, 
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14))),
                    Text(_currencyFormat.format(value), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(child: Text(AppLocalizations.of(context)!.noSalesDataAvailable, style: GoogleFonts.plusJakartaSans(color: Colors.white54))),
      );
    }

    return Column(
      children: _topProducts.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        final isLast = index == _topProducts.length - 1;

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index < 3 ? const Color(0xFF4BB4FF).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    color: index < 3 ? const Color(0xFF4BB4FF) : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? AppLocalizations.of(context)!.unknownProduct,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product['total_qty']} ${AppLocalizations.of(context)!.unitsSold}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _currencyFormat.format(product['total_revenue']),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {String? compareValue, bool isComparing = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isComparing && compareValue != null) ...[
            const SizedBox(height: 4),
            Text(
              "${AppLocalizations.of(context)!.vs} $compareValue",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(String label, double heightFactor, double value, {double? compareHeightFactor, double? compareValue}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Primary Bar
            Column(
              children: [
                if (heightFactor > 0.1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      NumberFormat.compact().format(value),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 9),
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: heightFactor),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  builder: (context, val, _) {
                    return Container(
                      width: compareHeightFactor != null ? 12 : 30,
                      height: 150 * val,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            const Color(0xFF4BB4FF).withOpacity(0.3),
                            const Color(0xFF4BB4FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(compareHeightFactor != null ? 4 : 8),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            // Comparison Bar
            if (compareHeightFactor != null) ...[
              const SizedBox(width: 4),
              Column(
                children: [
                  if (compareHeightFactor > 0.1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        NumberFormat.compact().format(compareValue),
                        style: GoogleFonts.plusJakartaSans(color: Colors.orangeAccent.withOpacity(0.7), fontSize: 9),
                      ),
                    ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: compareHeightFactor),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutQuart,
                    builder: (context, val, _) {
                      return Container(
                        width: 12,
                        height: 150 * val,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.orangeAccent.withOpacity(0.3),
                              Colors.orangeAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}