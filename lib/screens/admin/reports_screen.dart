// lib/screens/admin/reports_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/colors.dart';

enum ReportPeriod { day, week, month, year }
enum ChartType { bar, line }

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
  // Real data fetchers from Supabase
  // ---------------------------
  Future<List<_ChartPoint>> fetchSalesData(ReportPeriod period, DateTime date) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Calculate date range based on period
      DateTime startDate, endDate;
      
      if (period == ReportPeriod.day) {
        startDate = DateTime(date.year, date.month, date.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (period == ReportPeriod.week) {
        // Start of week (Monday)
        startDate = date.subtract(Duration(days: date.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
      } else if (period == ReportPeriod.month) {
        startDate = DateTime(date.year, date.month, 1);
        endDate = DateTime(date.year, date.month + 1, 1);
      } else {
        // Year
        startDate = DateTime(date.year, 1, 1);
        endDate = DateTime(date.year + 1, 1, 1);
      }
      
      // Fetch delivered orders in the date range
      final response = await supabase
          .from('orders')
          .select('id, order_date, total_amount, subtotal, delivery_fee, tax')
          .eq('status', 'delivered')
          .gte('order_date', startDate.toIso8601String())
          .lt('order_date', endDate.toIso8601String())
          .order('order_date', ascending: true);
      
      final orders = response as List<dynamic>;
      
      // Group orders by time period
      if (period == ReportPeriod.day) {
        // Group by hour (24 hours)
        final hourlyData = List.generate(24, (i) => _ChartPoint('${i.toString().padLeft(2, '0')}:00', 0.0));
        
        for (var order in orders) {
          final orderDate = DateTime.parse(order['order_date']);
          final hour = orderDate.hour;
          hourlyData[hour].value += (order['total_amount'] as num).toDouble();
        }
        
        return hourlyData;
      } else if (period == ReportPeriod.week) {
        // Group by day of week
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dailyData = List.generate(7, (i) => _ChartPoint(days[i], 0.0));
        
        for (var order in orders) {
          final orderDate = DateTime.parse(order['order_date']);
          final dayIndex = orderDate.weekday - 1; // Monday = 0
          dailyData[dayIndex].value += (order['total_amount'] as num).toDouble();
        }
        
        return dailyData;
      } else if (period == ReportPeriod.month) {
        // Group by day of month
        final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
        final dailyData = List.generate(daysInMonth, (i) => _ChartPoint('${i + 1}', 0.0));
        
        for (var order in orders) {
          final orderDate = DateTime.parse(order['order_date']);
          final day = orderDate.day - 1; // 0-indexed
          if (day < dailyData.length) {
            dailyData[day].value += (order['total_amount'] as num).toDouble();
          }
        }
        
        return dailyData;
      } else {
        // Group by month (12 months)
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthlyData = List.generate(12, (i) => _ChartPoint(months[i], 0.0));
        
        for (var order in orders) {
          final orderDate = DateTime.parse(order['order_date']);
          final month = orderDate.month - 1; // 0-indexed
          monthlyData[month].value += (order['total_amount'] as num).toDouble();
        }
        
        return monthlyData;
      }
    } catch (e) {
      debugPrint('❌ Error fetching sales data: $e');
      // Return empty data on error
      if (period == ReportPeriod.day) {
        return List.generate(24, (i) => _ChartPoint('${i.toString().padLeft(2, '0')}:00', 0.0));
      } else if (period == ReportPeriod.week) {
        return List.generate(7, (i) => _ChartPoint(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i], 0.0));
      } else if (period == ReportPeriod.month) {
        final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
        return List.generate(daysInMonth, (i) => _ChartPoint('${i + 1}', 0.0));
      } else {
        return List.generate(12, (i) => _ChartPoint(['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i], 0.0));
      }
    }
  }

  Future<List<_TopItem>> fetchTopItems(ReportPeriod period, DateTime date) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Calculate date range
      DateTime startDate, endDate;
      
      if (period == ReportPeriod.day) {
        startDate = DateTime(date.year, date.month, date.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (period == ReportPeriod.week) {
        startDate = date.subtract(Duration(days: date.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
      } else if (period == ReportPeriod.month) {
        startDate = DateTime(date.year, date.month, 1);
        endDate = DateTime(date.year, date.month + 1, 1);
      } else {
        startDate = DateTime(date.year, 1, 1);
        endDate = DateTime(date.year + 1, 1, 1);
      }
      
      // Fetch order items from delivered orders
      final response = await supabase
          .from('order_items')
          .select('title, quantity, order_id, orders!inner(status, order_date)')
          .gte('orders.order_date', startDate.toIso8601String())
          .lt('orders.order_date', endDate.toIso8601String())
          .eq('orders.status', 'delivered');
      
      final items = response as List<dynamic>;
      
      // Group by item title and sum quantities
      final Map<String, int> itemCounts = {};
      
      for (var item in items) {
        final title = item['title'] as String;
        final quantity = item['quantity'] as int;
        itemCounts[title] = (itemCounts[title] ?? 0) + quantity;
      }
      
      // Sort by count and take top 5
      final sortedItems = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedItems
          .take(5)
          .map((e) => _TopItem(e.key, e.value))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching top items: $e');
      return [];
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
      return const _GlassCard(
        child: Center(child: CircularProgressIndicator()),
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
    final perPointWidth = 60.0;
    final chartWidth = max(screenWidth - 32, _chartData.length * perPointWidth);

    Widget chart;
    if (_chartType == ChartType.bar) {
      chart = _buildBarChart(_chartData, chartWidth);
    } else {
      chart = _buildLineChart(_chartData, chartWidth);
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
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
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildLineChart(List<_ChartPoint> data, double chartWidth) {
    final maxY = (data.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.3;
    const minY = 0.0;

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
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
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
  double value; // Made mutable for aggregation
  _ChartPoint(this.label, this.value);
}

class _TopItem {
  final String name;
  final int count;
  _TopItem(this.name, this.count);
}