import 'dart:io';
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stockflowkp/services/database_service.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  bool _isLoading = true;
  List<FlSpot> _spots = [];
  double _maxSales = 0;
  double _totalRevenue = 0;
  int _totalSalesCount = 0;
  List<String> _bottomTitles = [];
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _categorySales = [];
  List<Map<String, dynamic>> _filteredSales = [];

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
    final dbService = DatabaseService();
    final sales = await dbService.getAllSales();
    final categoryData = await dbService.getSalesByCategory(_selectedDateRange);

    if (sales.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Aggregate sales by date
    final Map<String, double> dailySales = {};
    double totalRev = 0;
    int filteredCount = 0;
    final List<Map<String, dynamic>> currentFilteredSales = [];

    // Sort sales by date first to ensure order
    final sortedSales = List<Map<String, dynamic>>.from(sales);
    sortedSales.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateA.compareTo(dateB);
    });

    for (var sale in sortedSales) {
      final dateStr = sale['created_at'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      if (_selectedDateRange != null) {
        final start = DateUtils.dateOnly(_selectedDateRange!.start);
        final end = DateUtils.dateOnly(
          _selectedDateRange!.end,
        ).add(const Duration(days: 1));
        if (date.isBefore(start) ||
            date.isAfter(end) ||
            date.isAtSameMomentAs(end)) {
          continue;
        }
      }

      currentFilteredSales.add(sale);
      final dateKey = DateFormat('MM/dd').format(date);
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;

      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + amount;
      totalRev += amount;
      filteredCount++;
    }

    // Prepare spots for chart
    final List<FlSpot> spots = [];
    final List<String> titles = [];
    double maxVal = 0;
    int index = 0;

    dailySales.forEach((key, value) {
      spots.add(FlSpot(index.toDouble(), value));
      titles.add(key);
      if (value > maxVal) maxVal = value;
      index++;
    });

    if (mounted) {
      setState(() {
        _spots = spots;
        _bottomTitles = titles;
        _maxSales = maxVal == 0 ? 100 : maxVal * 1.2; // Add buffer
        _totalRevenue = totalRev;
        _totalSalesCount = filteredCount;
        _categorySales = categoryData;
        _filteredSales = currentFilteredSales;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    if (_filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<List<dynamic>> rows = [];

      // Add Header
      rows.add([
        'Date',
        'Sale ID',
        'Customer ID',
        'Total Amount',
        'Discount',
        'Payment Status',
        'Is Loan',
        'Sync Status',
      ]);

      // Add Data
      for (var sale in _filteredSales) {
        final date =
            DateTime.tryParse(sale['created_at'] ?? '') ?? DateTime.now();
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(date),
          sale['server_id'] ?? 'LOC-${sale['local_id']}',
          sale['customer_id'] ?? 'Walk-in',
          sale['total_amount'],
          sale['discount_amount'],
          sale['payment_status'],
          (sale['is_loan'] == 1 || sale['is_loan'] == true) ? 'Yes' : 'No',
          (sale['sync_status'] == 1) ? 'Synced' : 'Pending',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final fileName =
          'sales_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final path = '${directory.path}/$fileName';

      final file = File(path);
      await file.writeAsString(csvData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
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
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF0A1B32),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [Color(0xFF1E4976), Color(0xFF0A1B32), Color(0xFF020B18)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sales Report',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
            onPressed: _pickDateRange,
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
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedDateRange != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedDateRange = null);
                                    _loadData();
                                  },
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(
                                      color: Color(0xFF4BB4FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Revenue',
                                'TZS ${_currencyFormat.format(_totalRevenue)}',
                                Icons.attach_money_rounded,
                                const Color(0xFF4BB4FF),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryCard(
                                'Transactions',
                                '$_totalSalesCount',
                                Icons.receipt_long_rounded,
                                Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Chart Section
                        Text(
                          'Daily Sales Trend',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 300,
                          padding: const EdgeInsets.only(
                            right: 20,
                            top: 20,
                            bottom: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child:
                              _spots.isEmpty
                                  ? Center(
                                    child: Text(
                                      'No data available',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  )
                                  : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine:
                                            (value) => FlLine(
                                              color: Colors.white10,
                                              strokeWidth: 1,
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index >= 0 &&
                                                  index <
                                                      _bottomTitles.length) {
                                                // Show every nth label if too many
                                                if (_bottomTitles.length > 7 &&
                                                    index %
                                                            (_bottomTitles
                                                                    .length ~/
                                                                5) !=
                                                        0)
                                                  return const SizedBox();
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    _bottomTitles[index],
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      minX: 0,
                                      maxX: (_spots.length - 1).toDouble(),
                                      minY: 0,
                                      maxY: _maxSales,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: _spots,
                                          isCurved: true,
                                          color: const Color(0xFF4BB4FF),
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: const Color(
                                              0xFF4BB4FF,
                                            ).withOpacity(0.2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),

                        const SizedBox(height: 30),
                        Text(
                          'Sales by Category',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildCategoryPieChart(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
        ),
      ),
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
        child: Center(
          child: Text(
            'No category data available',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

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
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(_categorySales.length, (i) {
                  final cat = _categorySales[i];
                  final value = (cat['total'] as num).toDouble();
                  final percentage = (value / _totalRevenue * 100)
                      .toStringAsFixed(1);
                  final color = colors[i % colors.length];

                  return PieChartSectionData(
                    color: color,
                    value: value,
                    title: '$percentage%',
                    radius: 50,
                    titleStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
              final name = cat['name'] ?? 'Uncategorized';
              final value = (cat['total'] as num).toDouble();
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      'TZS ${_currencyFormat.format(value)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
