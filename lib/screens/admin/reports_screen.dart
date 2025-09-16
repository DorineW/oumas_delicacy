// lib/screens/admin/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'Last 7 days';
  bool _showBarChart = true; // Toggle between bar chart and line chart
  late List<SalesData> _chartData;
  double _todayRevenue = 0.0;
  int _todayOrders = 0;
  String _mostSoldItem = '';

  @override
  void initState() {
    super.initState();
    _updateData();
  }

  void _updateData() {
    setState(() {
      switch (_selectedPeriod) {
        case 'Today':
          _chartData = [
            SalesData('6 AM', 450),
            SalesData('9 AM', 820),
            SalesData('12 PM', 1560),
            SalesData('3 PM', 980),
            SalesData('6 PM', 1230),
            SalesData('9 PM', 750),
          ];
          _todayRevenue = 5790;
          _todayOrders = 23;
          _mostSoldItem = 'UGALI NYAMA CHOMA';
          break;
        case 'Last 7 days':
          _chartData = [
            SalesData('Mon', 2450),
            SalesData('Tue', 3120),
            SalesData('Wed', 2780),
            SalesData('Thu', 3560),
            SalesData('Fri', 4230),
            SalesData('Sat', 5120),
            SalesData('Sun', 3870),
          ];
          _todayRevenue = 25130;
          _todayOrders = 112;
          _mostSoldItem = 'PILAU FISH';
          break;
        case 'Last 30 days':
          _chartData = [
            SalesData('Week 1', 15680),
            SalesData('Week 2', 17820),
            SalesData('Week 3', 19250),
            SalesData('Week 4', 21530),
          ];
          _todayRevenue = 74280;
          _todayOrders = 485;
          _mostSoldItem = 'CHIPS BEEF';
          break;
        case 'This year':
          _chartData = [
            SalesData('Jan', 42560),
            SalesData('Feb', 47820),
            SalesData('Mar', 51230),
            SalesData('Apr', 48970),
            SalesData('May', 53210),
            SalesData('Jun', 59840),
            SalesData('Jul', 61250),
            SalesData('Aug', 58730),
            SalesData('Sep', 54320),
            SalesData('Oct', 59870),
            SalesData('Nov', 62450),
            SalesData('Dec', 67830),
          ];
          _todayRevenue = 668080;
          _todayOrders = 542;
          _mostSoldItem = 'SOUTHERN CHICKEN LARGE';
          break;
        default:
          _chartData = [];
      }
    });
  }

  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(_chartData.length, (index) {
      final data = _chartData[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.amount,
            color: AppColors.primary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxValue() * 1.1, // Slightly above max value for background
              color: AppColors.cardBackground,
            ),
          ),
        ],
      );
    });
  }

  List<FlSpot> _generateLineSpots() {
    return List.generate(_chartData.length, (index) {
      return FlSpot(index.toDouble(), _chartData[index].amount);
    });
  }

  double _getMaxValue() {
    return _chartData.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index >= 0 && index < _chartData.length) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 4,
        child: Text(
          _chartData[index].period,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.darkText,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text(
        'Ksh ${value.toInt()}',
        style: TextStyle(
          fontSize: 10,
          color: AppColors.darkText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sales Reports"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Sales Overview",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _selectedPeriod,
                    items: ['Today', 'Last 7 days', 'Last 30 days', 'This year']
                        .map((period) => DropdownMenuItem(
                              value: period,
                              child: Text(period),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriod = value!;
                        _updateData();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Today's Highlights
              Card(
                color: AppColors.cardBackground,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Summary",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.darkText),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Revenue", style: TextStyle(color: AppColors.darkText)),
                          Text("Ksh ${_todayRevenue.toStringAsFixed(2)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Orders", style: TextStyle(color: AppColors.darkText)),
                          Text("$_todayOrders",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Most Sold", style: TextStyle(color: AppColors.darkText)),
                          Text(_mostSoldItem,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Sales Chart
              Card(
                color: AppColors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Sales Chart",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.darkText),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              _showBarChart ? Icons.show_chart : Icons.bar_chart,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                _showBarChart = !_showBarChart;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _showBarChart
                            ? BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  barGroups: _generateBarGroups(),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                      color: AppColors.lightGray,
                                      width: 1,
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: AppColors.lightGray.withOpacity(0.3),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: _bottomTitleWidgets,
                                        reservedSize: 30,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: _leftTitleWidgets,
                                        reservedSize: 40,
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: AppColors.lightGray.withOpacity(0.3),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                      color: AppColors.lightGray,
                                      width: 1,
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _generateLineSpots(),
                                      isCurved: true,
                                      color: AppColors.primary,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppColors.primary.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: _bottomTitleWidgets,
                                        reservedSize: 30,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: _leftTitleWidgets,
                                        reservedSize: 40,
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Summary Card
              Card(
                color: AppColors.cardBackground,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Revenue",
                              style: TextStyle(color: AppColors.darkText)),
                          Text(
                              "Ksh ${_chartData.fold<double>(0, (sum, item) => sum + item.amount).toStringAsFixed(2)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Orders",
                              style: TextStyle(color: AppColors.darkText)),
                          Text("${_todayOrders * (_selectedPeriod == 'Last 7 days' ? 16 : _selectedPeriod == 'Last 30 days' ? 70 : _selectedPeriod == 'This year' ? 365 : 1)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Average Order Value",
                              style: TextStyle(color: AppColors.darkText)),
                          Text(
                              "Ksh ${(_chartData.fold<double>(0, (sum, item) => sum + item.amount) / (_todayOrders * (_selectedPeriod == 'Last 7 days' ? 16 : _selectedPeriod == 'Last 30 days' ? 70 : _selectedPeriod == 'This year' ? 365 : 1))).toStringAsFixed(2)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Top Selling Items",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  _TopItemTile(name: "UGALI NYAMA CHOMA", sales: 24, revenue: 210*24),
                  _TopItemTile(name: "PILAU FISH", sales: 18, revenue: 310*18),
                  _TopItemTile(name: "CHIPS BEEF", sales: 32, revenue: 210*32),
                  _TopItemTile(name: "SOUTHERN CHICKEN LARGE", sales: 28, revenue: 250*28),
                  _TopItemTile(name: "MEAT PIE", sales: 15, revenue: 150*15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SalesData {
  final String period;
  final double amount;

  SalesData(this.period, this.amount);
}

class _TopItemTile extends StatelessWidget {
  final String name;
  final int sales;
  final double revenue;

  const _TopItemTile({
    required this.name,
    required this.sales,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            name[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.darkText),
        ),
        subtitle: Text("$sales sold",
            style: TextStyle(color: AppColors.darkText)),
        trailing: Text(
          "Ksh ${revenue.toStringAsFixed(2)}",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.darkText),
        ),
      ),
    );
  }
}