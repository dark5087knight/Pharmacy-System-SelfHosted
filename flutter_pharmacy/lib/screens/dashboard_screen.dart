import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/charts.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _revenueSeries = [];
  List<Map<String, dynamic>> _categoryBreakdown = [];
  List<Map<String, dynamic>> _topSold = [];
  List<ActivityEvent> _recentActivity = [];

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
      final db = ApiService();
      final res = await db.request<Map<String, dynamic>>('dashboard');
      if (mounted) {
        setState(() {
          _stats = res['stats'] as Map<String, dynamic>;
          _revenueSeries = (res['revenueSeries'] as List).cast<Map<String, dynamic>>();
          _categoryBreakdown = (res['categoryBreakdown'] as List).cast<Map<String, dynamic>>();
          _topSold = (res['topSold'] as List).cast<Map<String, dynamic>>();
          _recentActivity = res['recentActivity'] as List<ActivityEvent>;
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
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard: $_errorMsg',
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
      );
    }


    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.layoutDashboard,
            title: context.tr('dash.overview'),
            subtitle: context.tr('dash.real_time_subtitle'),
            actions: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.foreground,
                foregroundColor: appColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {},
              icon: const Icon(LucideIcons.download, size: 14),
              label: Text(context.tr('dash.export_btn'), style: const TextStyle(fontSize: 12)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Metrics grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cols == 4 ? 2.2 : 2.5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StatCard(
                          label: context.tr('dash.stats.today_sales'),
                          value: '\$${(_stats['todayRevenue'] ?? 0.0).toStringAsFixed(2)}',
                          trend: const {'value': '8.2%', 'up': true},
                          icon: LucideIcons.shoppingBag,
                        ),
                        StatCard(
                          label: context.tr('dash.stats.monthly_sales'),
                          value: '\$${(_stats['monthRevenue'] ?? 0.0).toStringAsFixed(2)}',
                          trend: const {'value': '12.4%', 'up': true},
                          icon: LucideIcons.trendingUp,
                        ),
                        StatCard(
                          label: context.tr('dash.stats.est_profit'),
                          value: '\$${(_stats['profit'] ?? 0.0).toStringAsFixed(2)}',
                          hint: context.tr('dash.stats.profit_margin_hint'),
                          icon: LucideIcons.dollarSign,
                        ),
                        StatCard(
                          label: context.tr('dash.stats.expiry_alerts'),
                          value: '${_stats['expiringSoon'] ?? 0}',
                          hint: context.tr('dash.stats.expiry_hint'),
                          trend: {'value': '${_stats['expired'] ?? 0} ${context.tr('dash.stats.expired_hint')}', 'up': false},
                          icon: LucideIcons.calendar,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Main Charts Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 1100;

                    final leftColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Revenue Series Area Chart
                        Section(
                          title: context.tr('dash.timeline'),
                          children: MonoArea(
                            data: _revenueSeries,
                            xKey: 'day',
                            yKey: 'revenue',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Top sold table
                        Section(
                          title: context.tr('dash.top_products'),
                          children: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(color: appColors.border, width: 0.5),
                            ),
                            children: [
                              TableRow(
                                children: [
                                  _th(context.tr('dash.top_products.col_product'), appColors),
                                  _th(context.tr('dash.top_products.col_qty'), appColors),
                                  _th(context.tr('dash.top_products.col_revenue'), appColors),
                                ],
                              ),
                              ..._topSold.map((t) {
                                return TableRow(
                                  children: [
                                    _td(t['name']?.toString() ?? '', appColors),
                                    _td(t['qty']?.toString() ?? '0', appColors, mono: true),
                                    _td('\$${((t['revenue'] ?? 0.0) as num).toStringAsFixed(2)}', appColors, mono: true),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    );

                    final rightColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category mix pie chart
                        Section(
                          title: context.tr('dash.revenue_mix'),
                          children: MonoPie(data: _categoryBreakdown),
                        ),
                        const SizedBox(height: 20),

                        // Quick actions
                        Section(
                          title: context.tr('dash.quick_ops'),
                          children: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _actionBtn(context.tr('dash.quick.pos'), LucideIcons.shoppingCart, () {
                                workspace.openTab('pos');
                              }, appColors),
                              _actionBtn(context.tr('dash.quick.inventory'), LucideIcons.plus, () {
                                workspace.openTab('inventory');
                              }, appColors),
                              _actionBtn(context.tr('dash.quick.prescriptions'), LucideIcons.fileText, () {
                                workspace.openTab('prescriptions');
                              }, appColors),
                              _actionBtn(context.tr('dash.quick.warehouse'), LucideIcons.grid, () {
                                workspace.openTab('warehouse');
                              }, appColors),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Audit activity list
                        Section(
                          title: context.tr('dash.audit'),
                          children: Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _recentActivity.length,
                              itemBuilder: (context, idx) {
                                final a = _recentActivity[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 6,
                                        width: 6,
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        decoration: BoxDecoration(
                                          color: appColors.foreground,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a.message, style: const TextStyle(fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${a.actor} · ${_formatTime(a.at)}',
                                              style: TextStyle(fontSize: 10, color: appColors.mutedForeground),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: leftColumn),
                          const SizedBox(width: 20),
                          Expanded(flex: 1, child: rightColumn),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 20),
                          rightColumn,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return context.tr('time.days_ago', args: {'count': diff.inDays.toString()});
      if (diff.inHours > 0) return context.tr('time.hours_ago', args: {'count': diff.inHours.toString()});
      if (diff.inMinutes > 0) return context.tr('time.minutes_ago', args: {'count': diff.inMinutes.toString()});
      return context.tr('time.just_now');
    } catch (_) {
      return '';
    }
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

  Widget _td(String text, AppColors appColors, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        text,
        style: mono
            ? AppTheme.mono(fontSize: 12, color: appColors.foreground)
            : TextStyle(fontSize: 12.5, color: appColors.foreground),
      ),
    );
  }

  Widget _actionBtn(String text, IconData icon, VoidCallback onTap, AppColors appColors) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: appColors.background,
          border: Border.all(color: appColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: appColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
