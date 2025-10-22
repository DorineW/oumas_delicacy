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
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'dart:ui';

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
  bool _isCopying = false;
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
        final isPeak = (i >= 12 && i <= 14) || (i >= 18 && i <= 20);
        final base = isPeak ? 1200 : 400;
        final variation = random.nextInt(300);
        final value = (base + variation + (i * 20)).toDouble();
        return _ChartPoint(label, value);
      });
    } else if (period == ReportPeriod.week) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return List.generate(7, (i) {
        final isWeekend = i >= 5;
        final base = isWeekend ? 8000 : 5000;
        final variation = random.nextInt(2000);
        final value = (base + variation + (i * 500)).toDouble();
        return _ChartPoint(days[i], value);
      });
    } else if (period == ReportPeriod.month) {
      final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
      return List.generate(daysInMonth, (i) {
        final label = '${i + 1}';
        final isWeekend = DateTime(date.year, date.month, i + 1).weekday >= 6;
        final base = isWeekend ? 6000 : 4000;
        final variation = random.nextInt(1500);
        final value = (base + variation + ((i % 7) * 200)).toDouble();
        return _ChartPoint(label, value);
      });
    } else {
      return List.generate(12, (i) {
        final monthName = DateFormat.MMM().format(DateTime(date.year, i + 1));
        final isHolidaySeason = i == 11;
        final base = isHolidaySeason ? 120000 : 80000;
        final variation = random.nextInt(30000);
        final value = (base + variation + (i * 5000)).toDouble();
        return _ChartPoint(monthName, value);
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
    
    int getCount(int base, int range) => base + random.nextInt(range);
    
    if (period == ReportPeriod.day) {
      return [
        _TopItem(menuItems[0], getCount(8, 4)),
        _TopItem(menuItems[1], getCount(6, 3)),
        _TopItem(menuItems[3], getCount(5, 2)),
        _TopItem(menuItems[2], getCount(4, 2)),
        _TopItem(menuItems[4], getCount(3, 2)),
      ];
    } else if (period == ReportPeriod.week) {
      return [
        _TopItem(menuItems[0], getCount(45, 20)),
        _TopItem(menuItems[4], getCount(35, 15)),
        _TopItem(menuItems[5], getCount(25, 10)),
        _TopItem(menuItems[1], getCount(20, 8)),
        _TopItem(menuItems[6], getCount(15, 5)),
      ];
    } else if (period == ReportPeriod.month) {
      return [
        _TopItem(menuItems[0], getCount(180, 50)),
        _TopItem(menuItems[4], getCount(140, 40)),
        _TopItem(menuItems[1], getCount(120, 30)),
        _TopItem(menuItems[5], getCount(100, 25)),
        _TopItem(menuItems[3], getCount(90, 20)),
      ];
    } else {
      return [
        _TopItem(menuItems[0], getCount(1500, 400)),
        _TopItem(menuItems[4], getCount(1200, 300)),
        _TopItem(menuItems[1], getCount(1000, 250)),
        _TopItem(menuItems[5], getCount(800, 200)),
        _TopItem(menuItems[6], getCount(600, 150)),
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
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        ),
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
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Select Month & Year',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppColors.darkText,
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Text('Year:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          items: years.map((y) => DropdownMenuItem(
                            value: y, 
                            child: Text(y.toString(), style: TextStyle(color: AppColors.darkText)),
                          )).toList(),
                          onChanged: (y) {
                            if (y == null) return;
                            setState(() => selectedYear = y);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Previous year',
                        onPressed: () => setState(() {
                          selectedYear = (selectedYear - 1);
                          if (selectedYear < years.first) selectedYear = years.first;
                        }),
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next year',
                        onPressed: () => setState(() {
                          selectedYear = (selectedYear + 1);
                          if (selectedYear > years.last) selectedYear = years.last;
                        }),
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Select Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkText)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: List.generate(12, (index) {
                    final m = index + 1;
                    final monthName = DateFormat.MMM().format(DateTime(0, m));
                    final isSelected = selectedMonth == m;
                    final isCurrentMonth = m == DateTime.now().month && selectedYear == DateTime.now().year;
                    
                    return GestureDetector(
                      onTap: () => setState(() => selectedMonth = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isCurrentMonth ? AppColors.primary.withOpacity(0.1) : AppColors.cardBackground),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.lightGray.withOpacity(0.4),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName,
                          style: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.darkText, 
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, 
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Select', style: TextStyle(fontWeight: FontWeight.w600)), // Fixed: removed TextWeight
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
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildMiniStat('TOTAL', compactFmt.format(totalRevenue)),
          Container(
            width: 1,
            height: 30,
            color: AppColors.darkText.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildMiniStat('PEAK', peakPoint.label),
          Container(
            width: 1,
            height: 30,
            color: AppColors.darkText.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildMiniStat('AVERAGE', compactFmt.format(averageRevenue)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getPeriodDisplayName() {
    switch (_period) {
      case ReportPeriod.day:
        return 'Today';
      case ReportPeriod.week:
        return 'This Week';
      case ReportPeriod.month:
        return 'This Month';
      case ReportPeriod.year:
        return 'This Year';
    }
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
              _period == ReportPeriod.week,
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
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
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
              : _period == ReportPeriod.week
                  ? 'Week of ${DateFormat.MMMMd().format(_selectedDate)}'
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
      return _GlassCard(
        child: SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading chart data...', style: TextStyle(color: AppColors.darkText.withOpacity(0.6))),
              ],
            ),
          ),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return _GlassCard(
        child: SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 64, color: AppColors.darkText.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text('No data available', style: TextStyle(fontSize: 16, color: AppColors.darkText.withOpacity(0.5))),
                const SizedBox(height: 8),
                Text('Try selecting a different period', style: TextStyle(color: AppColors.darkText.withOpacity(0.4))),
              ],
            ),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, size: 20, color: AppColors.darkText),
                    const SizedBox(width: 8),
                    Text('Sales Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_getPeriodDisplayName(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildChartHeader(),
          ),
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
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => AppColors.primary.withOpacity(0.9),
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final point = data[group.x.toInt()];
            return BarTooltipItem(
              '${point.label}\n',
              const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 12),
              children: [
                TextSpan(
                  text: currencyFmt.format(rod.toY),
                  style: TextStyle(color: AppColors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
      ),
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
                child: Text(txt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.darkText.withOpacity(0.6))),
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
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.darkText.withOpacity(0.6)), textAlign: TextAlign.center),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(color: AppColors.darkText.withOpacity(0.1), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: AppColors.darkText.withOpacity(0.2), width: 1)),
      barGroups: data.asMap().entries.map((entry) {
        final i = entry.key;
        final pt = entry.value;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pt.value,
              width: 16,
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.8), AppColors.primary.withOpacity(0.4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
        );
      }).toList(),
    ));
  }

  Widget _buildLineChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.3;
    final minY = 0.0;

    return LineChart(LineChartData(
      maxY: maxY,
      minY: minY,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => AppColors.primary.withOpacity(0.9),
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((touchedSpot) {
              final point = data[touchedSpot.x.toInt()];
              return LineTooltipItem(
                '${point.label}\n',
                const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: currencyFmt.format(touchedSpot.y),
                    style: TextStyle(
                      color: AppColors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
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
                child: Text(txt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.darkText.withOpacity(0.6))),
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.darkText.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.darkText.withOpacity(0.1),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: AppColors.darkText.withOpacity(0.2),
          width: 1,
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.primary.withOpacity(0.4),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.3),
                AppColors.primary.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
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
    // On Android we attempt to copy to the Downloads folder; explicit runtime permission requests are omitted here
    // to avoid depending on the permission_handler package — failures will be caught and reported to the user.
    // (If your app targets Android versions requiring MANAGE_EXTERNAL_STORAGE, consider adding permission handling.)
    // No explicit permission request performed.

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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sales Analytics"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadDataForCurrentSelection,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - (isLandscape ? 24 : 32)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(),
                  SizedBox(height: isLandscape ? 12 : 16),
                  _buildPeriodSelector(),
                  SizedBox(height: isLandscape ? 12 : 16),
                  _buildChartTypeSelector(),
                  SizedBox(height: isLandscape ? 12 : 16),
                  if (_lastSavedDir != null && Platform.isAndroid)
                    Padding(
                      padding: EdgeInsets.only(bottom: isLandscape ? 6 : 8),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: Text('Open Downloads', style: TextStyle(fontSize: isLandscape ? 12 : 14)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 16, vertical: isLandscape ? 8 : 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openDownloadsFolder,
                      ),
                    ),
                  _buildChartArea(),
                  SizedBox(height: isLandscape ? 12 : 16),
                  _buildTopItemsList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------
  // Build UI - FIXED stats cards layout
  // ---------------------------
  Widget _buildStatsCards() {
    if (_loading) {
      return Row(
        children: List.generate(3, (i) => 
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatsCard(
            title: 'Revenue',
            value: compactFmt.format(_totalRevenue),
            icon: Icons.monetization_on,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatsCard(
            title: 'Orders',
            value: '$_totalOrders',
            icon: Icons.shopping_cart,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatsCard(
            title: 'Avg Value',
            value: compactFmt.format(_totalOrders > 0 ? _totalRevenue / _totalOrders : 0),
            icon: Icons.trending_up,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.darkText.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    
    // Simple container like dashboard - no BackdropFilter
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isLandscape ? 6 : 10,
            offset: Offset(0, isLandscape ? 2 : 4),
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