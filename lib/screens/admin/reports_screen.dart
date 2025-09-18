// lib/screens/admin/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sales Reports"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Weekly Sales"),
            const SizedBox(height: 12),
            _buildWeeklyChart(),
            const SizedBox(height: 24),
            _buildSectionTitle("Monthly Sales"),
            const SizedBox(height: 12),
            _buildMonthlyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
    );
  }

  /// Weekly Bar Chart
  Widget _buildWeeklyChart() {
    final weeklyData = [
      _ChartPoint('Mon', 12000),
      _ChartPoint('Tue', 15000),
      _ChartPoint('Wed', 10000),
      _ChartPoint('Thu', 17000),
      _ChartPoint('Fri', 22000),
      _ChartPoint('Sat', 25000),
      _ChartPoint('Sun', 18000),
    ];

    final maxY = (weeklyData.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  String txt = value >= 1000 ? 'K ${(value / 1000).toStringAsFixed(0)}' : value.toStringAsFixed(0);
                  return Text(
                    txt,
                    style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.8)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= weeklyData.length) return const SizedBox();
                  return Text(
                    weeklyData[idx].label,
                    style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.85)),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: weeklyData.asMap().entries.map((entry) {
            final i = entry.key;
            final pt = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: pt.value,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Monthly Line Chart
  Widget _buildMonthlyChart() {
    final monthlyData = [
      _ChartPoint('Jan', 120000),
      _ChartPoint('Feb', 135000),
      _ChartPoint('Mar', 110000),
      _ChartPoint('Apr', 150000),
      _ChartPoint('May', 170000),
      _ChartPoint('Jun', 190000),
    ];

    final maxY = (monthlyData.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  String txt = value >= 1000 ? 'K ${(value / 1000).toStringAsFixed(0)}' : value.toStringAsFixed(0);
                  return Text(
                    txt,
                    style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.8)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthlyData.length) return const SizedBox();
                  return Text(
                    monthlyData[idx].label,
                    style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.85)),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: monthlyData.asMap().entries
                  .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
                  .toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.15),
              ),
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple chart point model
class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint(this.label, this.value);
}
