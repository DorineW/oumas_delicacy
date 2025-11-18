// lib/screens/admin/mpesa_management_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/colors.dart';

enum MPesaTab { transactions, dailySummary, monthlySummary, reconciliation, taxReports }
enum MPesaStatusFilter { all, completed, pending, failed }

class MPesaManagementScreen extends StatefulWidget {
  const MPesaManagementScreen({super.key});

  @override
  State<MPesaManagementScreen> createState() => _MPesaManagementScreenState();
}

class _MPesaManagementScreenState extends State<MPesaManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  
  MPesaStatusFilter _statusFilter = MPesaStatusFilter.all;
  DateTimeRange? _dateRange;
  
  final currencyFmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KSh ');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Default to last 7 days
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('M-Pesa Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Date range picker
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long, size: 18)),
            Tab(text: 'Daily Summary', icon: Icon(Icons.calendar_today, size: 18)),
            Tab(text: 'Monthly Stats', icon: Icon(Icons.bar_chart, size: 18)),
            Tab(text: 'Reconciliation', icon: Icon(Icons.check_circle, size: 18)),
            Tab(text: 'Tax Reports', icon: Icon(Icons.account_balance, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date range indicator
          if (_dateRange != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildDailySummaryTab(),
                _buildMonthlySummaryTab(),
                _buildReconciliationTab(),
                _buildTaxReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 1: TRANSACTIONS
  // ============================================
  Widget _buildTransactionsTab() {
    return Column(
      children: [
        // Status filter chips
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ...MPesaStatusFilter.values.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter.name.toUpperCase()),
                  selected: _statusFilter == filter,
                  onSelected: (selected) {
                    setState(() => _statusFilter = filter);
                  },
                ),
              )),
            ],
          ),
        ),
        
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final transactions = snapshot.data ?? [];
              
              if (transactions.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No transactions found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return _buildTransactionCard(tx);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final status = tx['status'] as String;
    final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
    final tax = (tx['tax_amount'] as num?)?.toDouble() ?? 0;
    final subtotal = (tx['subtotal_amount'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (tx['delivery_fee'] as num?)?.toDouble() ?? 0;
    final timestamp = DateTime.parse(tx['transaction_timestamp'] as String);
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          currencyFmt.format(amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tx['customer_name'] ?? 'Unknown'} • ${tx['phone_number']}'),
            Text(
              DateFormat('MMM d, y - h:mm a').format(timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Transaction ID', tx['transaction_id'] ?? 'N/A'),
                _buildDetailRow('Order ID', tx['order_short_id'] ?? 'Not linked'),
                const Divider(height: 24),
                _buildDetailRow('Subtotal', currencyFmt.format(subtotal)),
                _buildDetailRow('Delivery Fee', currencyFmt.format(deliveryFee)),
                _buildDetailRow('Tax (16%)', currencyFmt.format(tax)),
                const Divider(height: 24),
                _buildDetailRow('Total', currencyFmt.format(amount), isBold: true),
                if (tx['result_desc'] != null) ...[
                  const Divider(height: 24),
                  _buildDetailRow('Result', tx['result_desc']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 2: DAILY SUMMARY
  // ============================================
  Widget _buildDailySummaryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDailySummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final summaries = snapshot.data ?? [];
        
        if (summaries.isEmpty) {
          return const Center(child: Text('No data available'));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _buildDailySummaryCard(summary);
          },
        );
      },
    );
  }

  Widget _buildDailySummaryCard(Map<String, dynamic> summary) {
    final date = DateTime.parse(summary['transaction_date'] as String);
    final totalRevenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0;
    final taxCollected = (summary['total_tax_collected'] as num?)?.toDouble() ?? 0;
    final deliveryFees = (summary['total_delivery_fees'] as num?)?.toDouble() ?? 0;
    final successfulTx = summary['successful_transactions'] as int? ?? 0;
    final failedTx = summary['failed_transactions'] as int? ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, y').format(date),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildStatusBadge('✓ $successfulTx', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatusBadge('✗ $failedTx', Colors.red),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Revenue grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Revenue',
                    currencyFmt.format(totalRevenue),
                    Icons.payments,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Tax Collected',
                    currencyFmt.format(taxCollected),
                    Icons.account_balance,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Delivery Fees',
                    currencyFmt.format(deliveryFees),
                    Icons.local_shipping,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Customers',
                    '${summary['unique_customers'] ?? 0}',
                    Icons.people,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 3: MONTHLY SUMMARY
  // ============================================
  Widget _buildMonthlySummaryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMonthlySummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final summaries = snapshot.data ?? [];
        
        if (summaries.isEmpty) {
          return const Center(child: Text('No data available'));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _buildMonthlySummaryCard(summary);
          },
        );
      },
    );
  }

  Widget _buildMonthlySummaryCard(Map<String, dynamic> summary) {
    final yearMonth = summary['year_month'] as String;
    final totalRevenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0;
    final taxCollected = (summary['tax_collected'] as num?)?.toDouble() ?? 0;
    final taxPercentage = (summary['tax_percentage_of_revenue'] as num?)?.toDouble() ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime.parse('$yearMonth-01')),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Large revenue display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Revenue',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFmt.format(totalRevenue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tax and metrics grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        currencyFmt.format(taxCollected),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('Tax Collected', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${taxPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('Tax Rate', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // TAB 4: RECONCILIATION
  // ============================================
  Widget _buildReconciliationTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Reconciliation Coming Soon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Auto-reconciliation with M-Pesa statements',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 5: TAX REPORTS
  // ============================================
  Widget _buildTaxReportsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchTaxReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final report = snapshot.data ?? {};
        final totalTax = (report['total_tax'] as num?)?.toDouble() ?? 0;
        final totalRevenue = (report['total_revenue'] as num?)?.toDouble() ?? 0;
        final effectiveRate = (report['effective_rate'] as num?)?.toDouble() ?? 0;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Tax summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Tax Collection Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  currencyFmt.format(totalTax),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Total Tax Collected'),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 60, color: Colors.grey[300]),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${effectiveRate.toStringAsFixed(2)}%',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Effective Rate'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'From total revenue of ${currencyFmt.format(totalRevenue)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Export button
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement CSV/PDF export
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export feature coming soon')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Export Tax Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // DATA FETCHING METHODS
  // ============================================
  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    try {
      // Build base query
      var baseQuery = _supabase
          .from('mpesa_transactions_detailed')
          .select();
      
      // Apply status filter
      if (_statusFilter != MPesaStatusFilter.all) {
        baseQuery = baseQuery.eq('status', _statusFilter.name);
      }
      
      // Apply date range
      if (_dateRange != null) {
        baseQuery = baseQuery
            .gte('transaction_timestamp', _dateRange!.start.toIso8601String())
            .lte('transaction_timestamp', _dateRange!.end.toIso8601String());
      }
      
      // Execute query
      final response = await baseQuery
          .order('transaction_timestamp', ascending: false)
          .limit(100);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDailySummary() async {
    try {
      var baseQuery = _supabase
          .from('mpesa_daily_summary')
          .select();
      
      if (_dateRange != null) {
        baseQuery = baseQuery
            .gte('transaction_date', _dateRange!.start.toIso8601String().split('T')[0])
            .lte('transaction_date', _dateRange!.end.toIso8601String().split('T')[0]);
      }
      
      final response = await baseQuery
          .order('transaction_date', ascending: false)
          .limit(30);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching daily summary: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMonthlySummary() async {
    try {
      final response = await _supabase
          .from('mpesa_monthly_summary')
          .select()
          .order('month_start', ascending: false)
          .limit(12);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching monthly summary: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchTaxReport() async {
    try {
      var baseQuery = _supabase
          .from('mpesa_transactions')
          .select('tax_amount, amount')
          .eq('status', 'completed');
      
      if (_dateRange != null) {
        baseQuery = baseQuery
            .gte('transaction_timestamp', _dateRange!.start.toIso8601String())
            .lte('transaction_timestamp', _dateRange!.end.toIso8601String());
      }
      
      final response = await baseQuery;
      
      double totalTax = 0;
      double totalRevenue = 0;
      
      for (final row in response) {
        totalTax += (row['tax_amount'] as num?)?.toDouble() ?? 0;
        totalRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      
      final effectiveRate = totalRevenue > 0 ? (totalTax / totalRevenue * 100) : 0;
      
      return {
        'total_tax': totalTax,
        'total_revenue': totalRevenue,
        'effective_rate': effectiveRate,
      };
    } catch (e) {
      debugPrint('Error fetching tax report: $e');
      rethrow;
    }
  }

  // ============================================
  // UI HELPERS
  // ============================================
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }
}
