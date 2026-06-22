import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
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
  List<Map<String, dynamic>> _topSold = [];

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
          _topSold = (res['topSold'] as List).cast<Map<String, dynamic>>();
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
                                    _td(((t['revenue'] ?? 0.0) as num).toIQD(), appColors, mono: true),
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
                        // Expiry Alerts Card
                        StatCard(
                          label: context.tr('dash.stats.expiry_alerts'),
                          value: '${_stats['expiringSoon'] ?? 0}',
                          hint: context.tr('dash.stats.expiry_hint'),
                          trend: {'value': '${_stats['expired'] ?? 0} ${context.tr('dash.stats.expired_hint')}', 'up': false},
                          icon: LucideIcons.calendar,
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
