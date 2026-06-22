import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/charts.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  List<Sale> _sales = [];
  List<PurchaseOrder> _po = [];
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final s = await _db.request<List<Sale>>('sales');
      final p = await _db.request<List<PurchaseOrder>>('purchase-orders');
      final sup = await _db.request<List<Supplier>>('suppliers');
      if (mounted) {
        setState(() {
          _sales = s;
          _po = p;
          _suppliers = sup;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load financial data: $_errorMsg',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSales = _sales.fold<double>(0, (sum, s) => sum + s.total);
    final totalCost = _po.where((p) => p.status == 'received').fold<double>(0, (sum, p) => sum + p.total);
    final accountsPayable = _suppliers.fold<double>(0, (sum, s) => sum + s.outstandingBalance);

    final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
    final todaySales = _sales
        .where((s) => s.createdAt.startsWith(todayPrefix))
        .fold<double>(0.0, (sum, s) => sum + s.total);
    final estimatedProfit = totalSales * 0.28;

    final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final List<Map<String, dynamic>> timelineData = [];
    
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = monthNames[date.month - 1];
      final monthPrefix = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      final double rev = _sales.where((s) => s.createdAt.startsWith(monthPrefix)).fold(0.0, (sum, s) => sum + s.total);
      final double exp = _po.where((p) => p.status == 'received' && p.createdAt.startsWith(monthPrefix)).fold(0.0, (sum, p) => sum + p.total);
      
      timelineData.add({
        'month': '$monthName ${date.year.toString().substring(2)}',
        'revenue': rev,
        'expenses': exp,
      });
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.wallet,
            title: context.tr('fin.title'),
            subtitle: context.tr('fin.subtitle'),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 700 ? 3 : 1);
                    final ratio = cols == 5 ? 1.8 : (cols == 3 ? 2.2 : 3.0);
                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: ratio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StatCard(
                          label: context.tr('dash.stats.today_sales'),
                          value: todaySales.toIQD(),
                          trend: const {'value': '8.2%', 'up': true},
                          icon: LucideIcons.shoppingBag,
                        ),
                        StatCard(
                          label: context.tr('fin.card.revenue'),
                          value: totalSales.toIQD(),
                          trend: const {'value': '15.6%', 'up': true},
                          icon: LucideIcons.trendingUp,
                        ),
                        StatCard(
                          label: context.tr('dash.stats.est_profit'),
                          value: estimatedProfit.toIQD(),
                          hint: context.tr('dash.stats.profit_margin_hint'),
                          icon: LucideIcons.wallet,
                        ),
                        StatCard(
                          label: context.tr('fin.card.inventory_cost'),
                          value: totalCost.toIQD(),
                          hint: context.tr('fin.card.hint_po'),
                          icon: LucideIcons.package,
                        ),
                        StatCard(
                          label: context.tr('fin.card.payable'),
                          value: accountsPayable.toIQD(),
                          hint: context.tr('fin.card.hint_due'),
                          trend: {'value': context.tr('fin.card.trend_high'), 'up': false},
                          icon: LucideIcons.dollarSign,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Cash Flow Chart
                Section(
                  title: context.tr('fin.chart.title'),
                  children: MonoLine(
                    data: timelineData,
                    xKey: 'month',
                    lines: [
                      {'key': 'revenue', 'label': context.tr('fin.chart.revenue')},
                      {'key': 'expenses', 'label': context.tr('fin.chart.expenses')},
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Recent sales transaction list
                Section(
                  title: context.tr('fin.transactions'),
                  children: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1.5),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: appColors.border, width: 0.5),
                    ),
                    children: [
                      TableRow(
                        children: [
                          _th(context.tr('fin.col.invoice'), appColors),
                          _th(context.tr('fin.col.patient'), appColors),
                          _th(context.tr('fin.col.payment'), appColors),
                          _th(context.tr('fin.col.ledger_sum'), appColors),
                          _th(context.tr('fin.col.posting_status'), appColors),
                        ],
                      ),
                      ..._sales.take(6).map((s) {
                        return TableRow(
                          children: [
                            _td(s.invoiceNumber, appColors, isMono: true),
                            _td(s.customerId ?? context.tr('fin.anonymous'), appColors),
                            _td(s.paymentMethod.toUpperCase(), appColors),
                            _td(s.total.toIQD(), appColors, isMono: true),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: StatusBadge(
                                text: s.status == 'completed' ? context.tr('status.completed') : context.tr('status.pending'),
                                variant: s.status == 'completed' ? BadgeVariant.success : BadgeVariant.warning,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: appColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _td(String text, AppColors appColors, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        text,
        style: isMono
            ? AppTheme.mono(fontSize: 12, color: appColors.foreground)
            : TextStyle(fontSize: 12.5, color: appColors.foreground),
      ),
    );
  }
}
