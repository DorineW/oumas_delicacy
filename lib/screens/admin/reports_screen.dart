// lib/screens/admin/reports_screen.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/Pdf.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../constants/colors.dart';

enum ReportPeriod { day, month, year }
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

  final currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: 'Ksh ');

  bool _loading = false;

  // --- new state for copying and downloads button ---
  bool _isCopying = false;
  String _copyProgressMessage = '';
  String? _lastSavedDir; // path to downloads folder used for last save

  @override
  void initState() {
    super.initState();
    _loadDataForCurrentSelection();
  }

  Future<void> _loadDataForCurrentSelection() async {
    setState(() => _loading = true);
    _chartData = await fetchSalesData(_period, _selectedDate);
    _topItems = await fetchTopItems(_period, _selectedDate);
    setState(() => _loading = false);
  }

  // ---------------------------
  // Placeholder data fetchers
  // ---------------------------
  Future<List<_ChartPoint>> fetchSalesData(ReportPeriod period, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (period == ReportPeriod.day) {
      return List.generate(24, (i) {
        final label = '${i.toString().padLeft(2, '0')}:00';
        final base = 500 + (date.day % 5) * 50;
        final value = base + (i * 150) + ((i % 6) == 0 ? 1200 : 0);
        return _ChartPoint(label, value.toDouble());
      });
    } else if (period == ReportPeriod.month) {
      final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
      return List.generate(daysInMonth, (i) {
        final label = '${i + 1}';
        final value = 3000 + ((i + date.month) * 200) + ((i % 5) * 300);
        return _ChartPoint(label, value.toDouble());
      });
    } else {
      return List.generate(12, (i) {
        final monthName = DateFormat.MMM().format(DateTime(date.year, i + 1));
        final value = 80000 + ((i + date.year % 7) * 5000);
        return _ChartPoint(monthName, value.toDouble());
      });
    }
  }

  Future<List<_TopItem>> fetchTopItems(ReportPeriod period, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final seed = date.day + date.month;
    if (period == ReportPeriod.day) {
      return [
        _TopItem('Ugali Nyama Choma', 5 + (seed % 6)),
        _TopItem('Samosa', 4 + (seed % 4)),
        _TopItem('Tea', 3 + (seed % 3)),
        _TopItem('Chapati', 2 + (seed % 2)),
      ];
    } else if (period == ReportPeriod.month) {
      return [
        _TopItem('Ugali Nyama Choma', 60 + (seed % 40)),
        _TopItem('Pilau Beef Fry', 45 + (seed % 30)),
        _TopItem('Beef Burger', 30 + (seed % 20)),
        _TopItem('Samosa', 20 + (seed % 15)),
      ];
    } else {
      return [
        _TopItem('Ugali Nyama Choma', 700 + (seed % 200)),
        _TopItem('Pilau Beef Fry', 560 + (seed % 150)),
        _TopItem('Samosa', 420 + (seed % 140)),
        _TopItem('Beef Burger', 300 + (seed % 120)),
      ];
    }
  }

  // ---------------------------
  // Date pickers and month picker
  // ---------------------------
  Future<void> _pickDate() async {
    if (_period == ReportPeriod.day) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        await _loadDataForCurrentSelection();
      }
    } else if (_period == ReportPeriod.month) {
      final picked = await _showMonthPicker(context, _selectedDate);
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, 1));
        await _loadDataForCurrentSelection();
      }
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2018),
        lastDate: DateTime.now(),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, 1, 1));
        await _loadDataForCurrentSelection();
      }
    }
  }

  Future<DateTime?> _showMonthPicker(BuildContext context, DateTime initialDate) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(11, (i) => currentYear - 5 + i);
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Pick month & year',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppColors.darkText,
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Year:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: selectedYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (y) {
                        if (y == null) return;
                        setState(() => selectedYear = y);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Previous year',
                      onPressed: () => setState(() {
                        selectedYear = (selectedYear - 1);
                        if (selectedYear < years.first) selectedYear = years.first;
                      }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next year',
                      onPressed: () => setState(() {
                        selectedYear = (selectedYear + 1);
                        if (selectedYear > years.last) selectedYear = years.last;
                      }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: List.generate(12, (index) {
                    final m = index + 1;
                    final monthName = DateFormat.MMM().format(DateTime(0, m));
                    final isSelected = selectedMonth == m;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedMonth = m;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.lightGray.withOpacity(0.6)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName,
                          style: TextStyle(color: isSelected ? AppColors.white : AppColors.darkText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkText),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                        child: const Text('Select'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------------------------
  // UI sections
  // ---------------------------
  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Expanded(
          child: ToggleButtons(
            isSelected: [
              _period == ReportPeriod.day,
              _period == ReportPeriod.month,
              _period == ReportPeriod.year
            ],
            onPressed: (i) async {
              setState(() {
                _period = ReportPeriod.values[i];
              });
              await _loadDataForCurrentSelection();
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: AppColors.white,
            fillColor: AppColors.primary,
            color: AppColors.darkText,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Day')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Month')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Year')),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_period == ReportPeriod.day
              ? DateFormat.yMMMd().format(_selectedDate)
              : _period == ReportPeriod.month
                  ? DateFormat.yMMM().format(_selectedDate)
                  : DateFormat.y().format(_selectedDate)),
        ),
      ],
    );
  }

  Widget _buildChartTypeSelector() {
    return Row(
      children: [
        const Text('Chart: ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        DropdownButton<ChartType>(
          value: _chartType,
          items: ChartType.values
              .map((ct) => DropdownMenuItem(
                    value: ct,
                    child: Text(ct.name.toUpperCase()),
                  ))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() => _chartType = val);
          },
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: (_isCopying || _loading) ? null : _onExportPressed,
          icon: const Icon(Icons.download),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
        ),
      ],
    );
  }

  Widget _buildChartArea() {
    if (_loading) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGray),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_chartData.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGray),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('No data for this period')),
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

    return Container(
      height: 320,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightGray),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.white,
      ),
      child: _chartType == ChartType.pie 
          ? chart 
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: chartWidth, child: chart),
            ),
    );
  }

  Widget _buildBarChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: maxY / 4,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox();
              final txt = value >= 1000 ? 'K ${(value / 1000).toStringAsFixed(0)}' : value.toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(txt, style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.85))),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox();
              final label = data[idx].label;
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  label, 
                  style: TextStyle(fontSize: 10, color: AppColors.darkText.withOpacity(0.9)),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true, border: Border.all(color: AppColors.lightGray.withOpacity(0.3))),
      barGroups: data.asMap().entries.map((entry) {
        final i = entry.key;
        final pt = entry.value;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pt.value, 
              width: 18, 
              borderRadius: BorderRadius.circular(6), 
              color: AppColors.primary,
            ),
          ],
        );
      }).toList(),
    ));
  }

  Widget _buildLineChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2;

    return LineChart(LineChartData(
      maxY: maxY,
      minY: 0,
      lineTouchData: LineTouchData(enabled: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 56, 
            interval: maxY / 4, 
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox();
              final txt = value >= 1000 ? 'K ${(value / 1000).toStringAsFixed(0)}' : value.toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(txt, style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.85))),
              );
            }
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox();
              final label = data[idx].label;
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  label, 
                  style: TextStyle(fontSize: 10, color: AppColors.darkText.withOpacity(0.9)),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true, border: Border.all(color: AppColors.lightGray.withOpacity(0.3))),
      lineBarsData: [
        LineChartBarData(
          spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.12)),
          dotData: FlDotData(show: true),
        ),
      ],
    ));
  }

  Widget _buildPieChart(List<_ChartPoint> data) {
    final total = data.fold<double>(0, (p, e) => p + e.value);

    if (total <= 0 || data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text('No data to display', style: TextStyle(color: AppColors.darkText))),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 320.0;
      final chartSize = min(max(availableHeight * 0.56, 120.0), 240.0);
      final centerSpace = chartSize * 0.22;

      // reduce the slice radius slightly so the chart won't paint outside its box
      final sliceRadius = (chartSize / 2) - 16;

      final sections = data.asMap().entries.map((entry) {
        final idx = entry.key;
        final e = entry.value;
        final percent = (e.value / total) * 100;
        final color = Colors.primaries[idx % Colors.primaries.length];
        return PieChartSectionData(
          value: e.value,
          title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
          color: color,
          radius: sliceRadius.clamp(40.0, chartSize / 2),
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        );
      }).toList();

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // clip to match outer container
          child: SizedBox(
            height: chartSize + 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0), // inner padding to avoid bleed
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: centerSpace,
                        sectionsSpace: 4,
                        pieTouchData: PieTouchData(enabled: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final e = entry.value;
                        final percent = (e.value / total) * 100;
                        final color = Colors.primaries[idx % Colors.primaries.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.label,
                                  style: TextStyle(fontSize: 12, color: AppColors.darkText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${percent.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTopItemsList() {
    if (_loading) return const SizedBox.shrink();

    if (_topItems.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No top items found.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Most sold items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
        const SizedBox(height: 8),
        ..._topItems.map((t) => ListTile(
              tileColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(t.name),
              trailing: Text('${t.count}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
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
      final csv = _buildCsv();
      final csvFilename = 'report_${_period.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final csvFile = await _saveFile(csvFilename, csv.codeUnits);

      final pdfBytes = await _buildPdfBytes();
      final pdfFilename = 'report_${_period.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfFile = await _saveFile(pdfFilename, pdfBytes);

      await _showExportOptions(context, csvFile, pdfFile);
    } catch (e, st) {
      debugPrint('Export prepare error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to prepare report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showExportOptions(BuildContext ctx, File csvFile, File pdfFile) {
    return showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Export Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save to Downloads'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                    onPressed: () async {
                      Navigator.pop(c);
                      await _saveFilesToDownloads([csvFile, pdfFile]);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkText),
                    onPressed: () {
                      Navigator.pop(c);
                      _shareFiles([csvFile, pdfFile]);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // NEW: Preview PDF button
            Row(children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('Preview PDF'),
                  onPressed: () async {
                    Navigator.pop(c);
                    await _previewPdf();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('You can both save and share. If saving fails, files remain in temporary folder.', 
                 style: TextStyle(color: AppColors.darkText.withOpacity(0.75), fontSize: 12)),
          ]),
        );
      },
    );
  }

  // Show a fullscreen modal with PdfPreview from the printing package
  Future<void> _previewPdf() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('PDF Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.white,
                      child: PdfPreview(
                        canChangePageFormat: false,
                        allowPrinting: true,
                        allowSharing: false,
                        build: (format) async => await _buildPdfBytes(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareFiles(List<File> files) async {
    try {
      final csvFile = files[0];
      final pdfFile = files[1];
      final csvBytes = await csvFile.readAsBytes();
      final pdfBytes = await pdfFile.readAsBytes();

      final xfiles = [
        XFile.fromData(csvBytes, name: p.basename(csvFile.path), mimeType: 'text/csv'),
        XFile.fromData(pdfBytes, name: p.basename(pdfFile.path), mimeType: 'application/pdf'),
      ];

      await Share.shareXFiles(xfiles, text: 'Sales report - ${_period.name.toUpperCase()} (${_selectedDate.toIso8601String()})');
    } catch (e, st) {
      debugPrint('Share error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share report: $e')));
      }
    }
  }

  Future<void> _saveFilesToDownloads(List<File> files) async {
    if (!mounted) return;

    // Request permission on Android
    if (Platform.isAndroid) {
      final perm = await Permission.manageExternalStorage.request();
      if (!perm.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission is required to save to Downloads')));
        }
        return;
      }
    }

    // show copying dialog
    _showCopyingDialog();

    final savedPaths = <String>[];
    try {
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        _updateCopyProgress('Copying ${p.basename(f.path)} (${i + 1}/${files.length})...');
        final copied = await _copyToDownloads(f);
        savedPaths.add(copied.path);
      }

      // set last saved dir to parent of first copied file (common Downloads folder)
      if (savedPaths.isNotEmpty) {
        final parent = File(savedPaths.first).parent.path;
        setState(() => _lastSavedDir = parent);
      }

      // close copying dialog
      _closeCopyingDialog();

      final msg = 'Files saved to Downloads folder';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg), 
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Open',
              onPressed: _openDownloadsFolder,
            ),
          )
        );
      }
    } catch (e, st) {
      debugPrint('Save to downloads error: $e\n$st');
      _closeCopyingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save to Downloads: $e')));
      }
    } finally {
      setState(() {
        _isCopying = false;
        _copyProgressMessage = '';
      });
    }
  }

  // show modal dialog with progress indicator
  void _showCopyingDialog() {
    if (!mounted) return;
    setState(() => _isCopying = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: AppColors.cardBackground,
            content: Row(
              children: [
                const SizedBox(width: 8),
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text(_copyProgressMessage.isEmpty ? 'Preparing files...' : _copyProgressMessage)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateCopyProgress(String message) {
    if (!mounted) return;
    setState(() => _copyProgressMessage = message);
  }

  void _closeCopyingDialog() {
    if (!mounted) return;
    try {
      Navigator.of(context, rootNavigator: true).pop(); // close dialog
    } catch (_) {}
  }

  Future<File> _copyToDownloads(File src) async {
    try {
      if (Platform.isAndroid) {
        // Try to get the Downloads directory
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final dest = File('${downloadsDir.path}/${p.basename(src.path)}');
          await src.copy(dest.path);
          return dest;
        }
        
        // Fallback for Android
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsPath = '${externalDir.path}/Download';
          final downloadsDir = Directory(downloadsPath);
          if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
          final dest = File('${downloadsDir.path}/${p.basename(src.path)}');
          await src.copy(dest.path);
          return dest;
        }
      } else {
        // For iOS and other platforms
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dest = File('${downloads.path}/${p.basename(src.path)}');
          await src.copy(dest.path);
          return dest;
        }
      }
    } catch (e) {
      debugPrint('copyToDownloads exception: $e');
    }

    // Fallback to temporary directory
    final tempDir = await getTemporaryDirectory();
    final dest = File('${tempDir.path}/${p.basename(src.path)}');
    await src.copy(dest.path);
    return dest;
  }

  // Open the downloads directory (Android-only). Uses open_filex to ask OS to open folder.
  Future<void> _openDownloadsFolder() async {
    if (_lastSavedDir == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Downloads folder to open')));
      }
      return;
    }
    try {
      await OpenFilex.open(_lastSavedDir!);
    } catch (e, st) {
      debugPrint('Open downloads error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open Downloads folder on this device')));
      }
    }
  }

  // ---------------------------
  // Helpers to build/save CSV & PDF
  // ---------------------------
  String _buildCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Label,Value');
    for (var p in _chartData) {
      buffer.writeln('"${p.label}",${p.value.toStringAsFixed(2)}');
    }
    buffer.writeln();
    buffer.writeln('Most sold items');
    buffer.writeln('Item,Count');
    for (var t in _topItems) {
      buffer.writeln('"${t.name}",${t.count}');
    }
    return buffer.toString();
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    final header = 'Report - ${_period.name.toUpperCase()} ${DateFormat.yMMMd().format(_selectedDate)}';
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(children: [
            pw.Text(header, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Sales data', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Label', 'Value'],
              data: _chartData.map((e) => [e.label, currencyFmt.format(e.value)]).toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Top sold items', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(headers: ['Item', 'Count'], data: _topItems.map((t) => [t.name, t.count.toString()]).toList()),
          ]);
        },
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sales Reports"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle("Select Period & Date"),
          const SizedBox(height: 8),
          _buildPeriodSelector(),
          const SizedBox(height: 12),
          _buildChartTypeSelector(),
          const SizedBox(height: 8),
          // show Open Downloads button after a successful save (Android-only)
          if (_lastSavedDir != null && Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open Downloads folder'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkText),
                      onPressed: _openDownloadsFolder,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _buildSectionTitle("Sales Chart"),
          const SizedBox(height: 8),
          _buildChartArea(),
          const SizedBox(height: 12),
          _buildTopItemsList(),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText));
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