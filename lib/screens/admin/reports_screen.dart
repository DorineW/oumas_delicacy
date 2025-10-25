// lib/screens/admin/reports_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../constants/colors.dart';

enum ReportPeriod { day, week, month, year }
enum ChartType { bar, line, pie }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.day;
  ChartType _chartType = ChartType.bar;
  DateTime _selectedDate = DateTime.now();

  List<_ChartPoint> _chartData = [];
  List<_TopItem> _topItems = [];
  double _totalRevenue = 0;
  int _totalOrders = 0;

  final currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: 'Ksh ');
  final compactFmt = NumberFormat.compactCurrency(locale: 'en_US', symbol: 'Ksh ');

  bool _loading = false;
  String _copyProgressMessage = '';
  String? _lastSavedDir;

  @override
  void initState() {
    super.initState();
    _loadDataForCurrentSelection();
  }

  Future<void> _loadDataForCurrentSelection() async {
    setState(() => _loading = true);
    _chartData = await fetchSalesData(_period, _selectedDate);
    _topItems = await fetchTopItems(_period, _selectedDate);
    _totalRevenue = _chartData.fold(0, (sum, point) => sum + point.value);
    _totalOrders = _topItems.fold(0, (sum, item) => sum + item.count);
    setState(() => _loading = false);
  }

  // ---------------------------
  // Enhanced data fetchers
  // ---------------------------
  Future<List<_ChartPoint>> fetchSalesData(ReportPeriod period, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    final random = Random(date.millisecondsSinceEpoch);
    
    if (period == ReportPeriod.day) {
      return List.generate(24, (i) {
        final label = '${i.toString().padLeft(2, '0')}:00';
        final value = 500.0 + random.nextDouble() * 2000;
        return _ChartPoint(label, value);
      });
    } else if (period == ReportPeriod.week) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return List.generate(7, (i) {
        final value = 5000.0 + random.nextDouble() * 15000;
        return _ChartPoint(days[i], value);
      });
    } else if (period == ReportPeriod.month) {
      final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
      return List.generate(daysInMonth, (i) {
        final label = '${i + 1}';
        final value = 1000.0 + random.nextDouble() * 5000;
        return _ChartPoint(label, value);
      });
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return List.generate(12, (i) {
        final value = 50000.0 + random.nextDouble() * 100000;
        return _ChartPoint(months[i], value);
      });
    }
  }

  Future<List<_TopItem>> fetchTopItems(ReportPeriod period, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final random = Random(date.millisecondsSinceEpoch);
    
    final menuItems = [
      'Ugali Nyama Choma', 'Samosa', 'Tea', 'Chapati', 'Pilau Beef Fry',
      'Beef Burger', 'Chicken Curry', 'Rice Beans', 'Fish Fillet', 'Fruit Salad'
    ];
    
    if (period == ReportPeriod.day) {
      return [
        _TopItem(menuItems[0], 45 + random.nextInt(20)),
        _TopItem(menuItems[1], 38 + random.nextInt(15)),
        _TopItem(menuItems[2], 32 + random.nextInt(12)),
        _TopItem(menuItems[3], 28 + random.nextInt(10)),
        _TopItem(menuItems[4], 22 + random.nextInt(8)),
      ];
    } else if (period == ReportPeriod.week) {
      return [
        _TopItem(menuItems[0], 280 + random.nextInt(50)),
        _TopItem(menuItems[1], 245 + random.nextInt(45)),
        _TopItem(menuItems[2], 210 + random.nextInt(40)),
        _TopItem(menuItems[3], 185 + random.nextInt(35)),
        _TopItem(menuItems[4], 150 + random.nextInt(30)),
      ];
    } else if (period == ReportPeriod.month) {
      return [
        _TopItem(menuItems[0], 980 + random.nextInt(200)),
        _TopItem(menuItems[1], 845 + random.nextInt(180)),
        _TopItem(menuItems[2], 720 + random.nextInt(150)),
        _TopItem(menuItems[3], 640 + random.nextInt(130)),
        _TopItem(menuItems[4], 560 + random.nextInt(110)),
      ];
    } else {
      return [
        _TopItem(menuItems[0], 11500 + random.nextInt(2000)),
        _TopItem(menuItems[1], 10200 + random.nextInt(1800)),
        _TopItem(menuItems[2], 8900 + random.nextInt(1500)),
        _TopItem(menuItems[3], 7800 + random.nextInt(1300)),
        _TopItem(menuItems[4], 6700 + random.nextInt(1100)),
      ];
    }
  }

  // ---------------------------
  // Enhanced date pickers
  // ---------------------------
  Future<void> _pickDate() async {
    if (_period == ReportPeriod.day || _period == ReportPeriod.week) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
        });
        _loadDataForCurrentSelection();
      }
    } else if (_period == ReportPeriod.month) {
      final picked = await _showMonthPicker(context, _selectedDate);
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
        });
        _loadDataForCurrentSelection();
      }
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        setState(() {
          _selectedDate = DateTime(picked.year, 1, 1);
        });
        _loadDataForCurrentSelection();
      }
    }
  }

  Future<DateTime?> _showMonthPicker(BuildContext context, DateTime initialDate) async {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);

    DateTime? result;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Month'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  items: years.map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
                  onChanged: (value) => setDialogState(() => selectedYear = value!),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final month = i + 1;
                    final isSelected = selectedMonth == month;
                    return ChoiceChip(
                      label: Text(_getMonthName(month)),
                      selected: isSelected,
                      onSelected: (_) => setDialogState(() => selectedMonth = month),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  result = DateTime(selectedYear, selectedMonth, 1);
                  Navigator.pop(ctx);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ---------------------------
  // NEW: Enhanced UI helper methods
  // ---------------------------
  Widget _buildChartHeader() {
    if (_chartData.isEmpty) return const SizedBox();
    
    final totalRevenue = _chartData.fold<double>(0, (sum, point) => sum + point.value);
    final peakPoint = _chartData.reduce((a, b) => a.value > b.value ? a : b);
    final averageRevenue = totalRevenue / _chartData.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Peak', compactFmt.format(peakPoint.value)),
          _buildMiniStat('Average', compactFmt.format(averageRevenue)),
          _buildMiniStat('Total', compactFmt.format(totalRevenue)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---------------------------
  // UI sections
  // ---------------------------
  Widget _buildPeriodSelector() {
    return Column(
      children: [
        Row(
          children: ReportPeriod.values.map((p) {
            final selected = _period == p;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(p.name.toUpperCase()),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _period = p;
                    });
                    _loadDataForCurrentSelection();
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(DateFormat.yMMMd().format(_selectedDate)),
          onPressed: _pickDate,
        ),
      ],
    );
  }

  Widget _buildChartTypeSelector() {
    return Row(
      children: ChartType.values.map((t) {
        final selected = _chartType == t;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(t.name.toUpperCase()),
              selected: selected,
              onSelected: (_) => setState(() => _chartType = t),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartArea() {
    if (_loading) {
      return _GlassCard(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_chartData.isEmpty) {
      return _GlassCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 60, color: AppColors.darkText.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No data available', style: TextStyle(color: AppColors.darkText.withOpacity(0.5))),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final perPointWidth = _chartType == ChartType.pie ? 80.0 : 60.0;
    final chartWidth = max(screenWidth - 32, _chartData.length * perPointWidth);

    Widget chart;
    if (_chartType == ChartType.bar) {
      chart = _buildBarChart(_chartData, chartWidth);
    } else if (_chartType == ChartType.line) {
      chart = _buildLineChart(_chartData, chartWidth);
    } else {
      chart = _buildPieChart(_chartData);
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: _chartType == ChartType.pie
                ? chart
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: chartWidth, child: chart),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // UPDATED: Enhanced Bar Chart
  // ---------------------------
  Widget _buildBarChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2;

    return BarChart(BarChartData(
      maxY: maxY,
      barGroups: data.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.value,
              color: AppColors.primary,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) => Text(
              compactFmt.format(value),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= data.length) return const SizedBox();
              return Text(data[value.toInt()].label, style: const TextStyle(fontSize: 10));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildLineChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.3;
    final minY = 0.0;

    return LineChart(LineChartData(
      maxY: maxY,
      minY: minY,
      lineBarsData: [
        LineChartBarData(
          spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) => Text(compactFmt.format(value), style: const TextStyle(fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= data.length) return const SizedBox();
              return Text(data[value.toInt()].label, style: const TextStyle(fontSize: 10));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildPieChart(List<_ChartPoint> data) {
    final total = data.fold<double>(0, (p, e) => p + e.value);

    if (total <= 0 || data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return LayoutBuilder(builder: (context, constraints) {
      return PieChart(PieChartData(
        sections: data.map((point) {
          final percentage = (point.value / total) * 100;
          return PieChartSectionData(
            value: point.value,
            title: '${percentage.toStringAsFixed(1)}%',
            color: Colors.primaries[data.indexOf(point) % Colors.primaries.length],
            radius: 100,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ));
    });
  }

  Widget _buildTopItemsList() {
    if (_loading) return const SizedBox.shrink();

    if (_topItems.isEmpty) {
      return const Center(child: Text('No top items'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Selling Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._topItems.map((item) => ListTile(
          leading: CircleAvatar(child: Text('${_topItems.indexOf(item) + 1}')),
          title: Text(item.name),
          trailing: Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ],
    );
  }

  // ---------------------------
  // EXPORT / SAVE / SHARE logic
  // ---------------------------

  Future<void> _onExportPressed() async {
    setState(() => _loading = true);
    try {
      final csvFile = await _saveFile('report.csv', _buildCsv().codeUnits);
      final pdfFile = await _saveFile('report.pdf', await _buildPdfBytes());
      await _showExportOptions(context, csvFile, pdfFile);
    } catch (e, st) {
      debugPrint('Export error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showExportOptions(BuildContext ctx, File csvFile, File pdfFile) {
    return showModalBottomSheet(
      context: ctx,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Files'),
              onTap: () {
                Navigator.pop(context);
                _shareFiles([csvFile, pdfFile]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Save to Downloads'),
              onTap: () {
                Navigator.pop(context);
                _saveFilesToDownloads([csvFile, pdfFile]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_red_eye),
              title: const Text('Preview PDF'),
              onTap: () {
                Navigator.pop(context);
                _previewPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show a fullscreen modal with PdfPreview from the printing package
  Future<void> _previewPdf() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: PdfPreview(build: (format) => _buildPdfBytes()),
      ),
    );
  }

  Future<void> _shareFiles(List<File> files) async {
    try {
      final xfiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(xfiles, text: 'Sales report - ${_period.name.toUpperCase()} (${_selectedDate.toIso8601String()})');
    } catch (e, st) {
      debugPrint('Share error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _saveFilesToDownloads(List<File> files) async {
    if (!mounted) return;

    _showCopyingDialog();

    final savedPaths = <String>[];
    try {
      for (final file in files) {
        _updateCopyProgress('Copying ${p.basename(file.path)}...');
        final dest = await _copyToDownloads(file);
        savedPaths.add(dest.path);
      }

      _closeCopyingDialog();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${files.length} file(s) saved'),
          action: SnackBarAction(
            label: 'Open Folder',
            onPressed: _openDownloadsFolder,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Save error: $e\n$st');
      _closeCopyingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // show modal dialog with progress indicator
  void _showCopyingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_copyProgressMessage),
          ],
        ),
      ),
    );
  }

  void _updateCopyProgress(String message) {
    if (!mounted) return;
    setState(() => _copyProgressMessage = message);
  }

  void _closeCopyingDialog() {
    if (!mounted) return;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  Future<File> _copyToDownloads(File src) async {
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final dest = File('${dir.path}/${p.basename(src.path)}');
          await src.copy(dest.path);
          _lastSavedDir = dir.path;
          return dest;
        }
      }
    } catch (e) {
      debugPrint('Copy to downloads error: $e');
    }

    final tempDir = await getTemporaryDirectory();
    final dest = File('${tempDir.path}/${p.basename(src.path)}');
    await src.copy(dest.path);
    return dest;
  }

  Future<void> _openDownloadsFolder() async {
    if (_lastSavedDir == null) return;
    try {
      await OpenFilex.open(_lastSavedDir!);
    } catch (e, st) {
      debugPrint('Open folder error: $e\n$st');
    }
  }

  // ---------------------------
  // Helpers to build/save CSV & PDF
  // ---------------------------
  String _buildCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Label,Value');
    for (var p in _chartData) {
      buffer.writeln('${p.label},${p.value}');
    }
    buffer.writeln();
    buffer.writeln('Most sold items');
    buffer.writeln('Item,Count');
    for (var t in _topItems) {
      buffer.writeln('${t.name},${t.count}');
    }
    return buffer.toString();
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    final header = 'Report - ${_period.name.toUpperCase()} ${DateFormat.yMMMd().format(_selectedDate)}';
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(header, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Total Revenue: ${currencyFmt.format(_totalRevenue)}'),
            pw.Text('Total Orders: $_totalOrders'),
            pw.SizedBox(height: 20),
            pw.Text('Top Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ..._topItems.map((item) => pw.Text('${item.name}: ${item.count}')),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<File> _saveFile(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ---------------------------
  // Build UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _onExportPressed,
            tooltip: 'Export',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLandscape ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 16),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildChartTypeSelector(),
            const SizedBox(height: 16),
            _buildChartArea(),
            const SizedBox(height: 24),
            _buildTopItemsList(),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Build UI - FIXED stats cards layout
  // ---------------------------
  Widget _buildStatsCards() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatsCard(
            title: 'Revenue',
            value: compactFmt.format(_totalRevenue),
            icon: Icons.attach_money,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatsCard(
            title: 'Orders',
            value: '$_totalOrders',
            icon: Icons.receipt,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// Helper widget class - UPDATED to match dashboard style
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      padding: EdgeInsets.all(isLandscape ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Simple chart point model
class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint(this.label, this.value);
}

class _TopItem {
  final String name;
  final int count;
  _TopItem(this.name, this.count);
}