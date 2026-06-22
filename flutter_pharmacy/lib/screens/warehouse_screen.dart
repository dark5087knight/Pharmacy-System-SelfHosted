import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  List<Medicine> _medicines = [];
  
  final String _selectedWarehouse = 'Main';
  String? _selectedRack;
  String? _selectedShelf;
  int _activeWarehouseTab = 0; // Active tab on narrow screens

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() async {
    try {
      final meds = await _db.request<List<Medicine>>('medicines');
      if (mounted) {
        setState(() {
          _medicines = meds;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Medicine> _getCellMedicines(String rack, String shelf) {
    return _medicines
        .where((m) =>
            m.location.warehouse == _selectedWarehouse &&
            m.location.rack == rack &&
            m.location.shelf == shelf)
        .toList();
  }

  double _getCellIntensity(String rack, String shelf) {
    final cellMeds = _getCellMedicines(rack, shelf);
    final totalQty = cellMeds.fold<int>(0, (sum, m) => sum + m.quantity);
    return (totalQty / 800.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final racks = List.generate(12, (i) => 'R${i + 1}');
    final shelves = List.generate(8, (i) => 'S${i + 1}');

    final bool isWide = MediaQuery.of(context).size.width >= 1100;

    Widget mainGrid = _buildLayoutGrid(context, racks, shelves, appColors);
    Widget auditPanel = _buildAuditPanel(context, appColors);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.warehouse,
            title: context.tr('wh.title'),
            subtitle: '${context.tr('wh.subtitle')} · $_selectedWarehouse ${context.tr('wh.warehouse')}',
          ),
          if (!isWide) ...[
            // Tab Toggle for narrow screens
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton(0, context.tr('wh.tab_layout'), appColors),
                  const SizedBox(width: 8),
                  _buildTabButton(1, context.tr('wh.tab_audit'), appColors),
                ],
              ),
            ),
          ],
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: mainGrid,
                        ),
                      ),
                      Container(
                        width: 360,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: appColors.border),
                          ),
                        ),
                        child: auditPanel,
                      ),
                    ],
                  )
                : IndexedStack(
                    index: _activeWarehouseTab,
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: mainGrid,
                      ),
                      auditPanel,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, AppColors appColors) {
    final bool isActive = _activeWarehouseTab == index;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? appColors.foreground : appColors.surface1,
        foregroundColor: isActive ? appColors.background : appColors.mutedForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isActive ? appColors.foreground : appColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
      onPressed: () {
        setState(() {
          _activeWarehouseTab = index;
        });
      },
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLayoutGrid(BuildContext context, List<String> racks, List<String> shelves, AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appColors.surface1,
            border: Border.all(color: appColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('wh.tab_layout'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: appColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 50),
                        ...racks.map((r) => Container(
                          width: 55,
                          height: 30,
                          alignment: Alignment.center,
                          child: Text(
                            r,
                            style: AppTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: appColors.mutedForeground,
                            ),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...shelves.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 55,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                s,
                                style: AppTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: appColors.mutedForeground,
                                ),
                              ),
                            ),
                            ...racks.map((r) {
                              final cellMeds = _getCellMedicines(r, s);
                              final intensity = _getCellIntensity(r, s);
                              final isSelected = _selectedRack == r && _selectedShelf == s;

                              return DragTarget<Medicine>(
                                onWillAcceptWithDetails: (details) => true,
                                onAcceptWithDetails: (details) async {
                                  final m = details.data;
                                  final newLoc = Location(rack: r, shelf: s, warehouse: _selectedWarehouse);
                                  final updatedMed = m.copyWith(location: newLoc);

                                  // Optimistic Update
                                  setState(() {
                                    final idx = _medicines.indexWhere((x) => x.id == m.id);
                                    if (idx != -1) {
                                      _medicines[idx] = updatedMed;
                                    }
                                  });

                                  try {
                                    await _db.updateMedicine(updatedMed);
                                  } catch (err) {
                                    debugPrint(err.toString());
                                    _fetchData(); // Rollback on error
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovered = candidateData.isNotEmpty;
                                  final cellColor = Color.lerp(
                                    appColors.surface1,
                                    appColors.foreground,
                                    intensity * 0.75,
                                  )!;

                                  final textColor = intensity > 0.5 
                                      ? appColors.background 
                                      : appColors.mutedForeground;

                                  final cellBorderColor = isSelected
                                      ? appColors.foreground
                                      : (isHovered ? appColors.success : appColors.border);

                                  final borderWidth = (isSelected || isHovered) ? 2.0 : 1.0;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRack = r;
                                        _selectedShelf = s;
                                        if (MediaQuery.of(context).size.width < 1100) {
                                          _activeWarehouseTab = 1;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 55,
                                      height: 55,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: cellColor,
                                        border: Border.all(
                                          color: cellBorderColor,
                                          width: borderWidth,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      alignment: Alignment.center,
                                      child: cellMeds.isNotEmpty
                                          ? Text(
                                              '${cellMeds.length}',
                                              style: AppTheme.mono(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    context.tr('wh.low'),
                    style: TextStyle(fontSize: 10, color: appColors.mutedForeground),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 8,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [appColors.surface1, appColors.foreground],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('wh.high'),
                    style: TextStyle(fontSize: 10, color: appColors.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditPanel(BuildContext context, AppColors appColors) {
    final String? rack = _selectedRack;
    final String? shelf = _selectedShelf;
    final bool hasSelection = rack != null && shelf != null;
    final List<Medicine> selectedMeds = hasSelection ? _getCellMedicines(rack, shelf) : [];
    final int totalQty = selectedMeds.fold<int>(0, (sum, m) => sum + m.quantity);

    return Container(
      padding: const EdgeInsets.all(20),
      color: appColors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasSelection ? '$rack / $shelf' : context.tr('wh.select_cell'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: appColors.foreground,
                ),
              ),
              if (hasSelection)
                StatusBadge(
                  text: context.tr('wh.cell_audit_badge'),
                  variant: BadgeVariant.muted,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasSelection)
            Expanded(
              child: Center(
                child: Text(
                  context.tr('wh.click_hint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: appColors.mutedForeground,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              context.tr('wh.cell_totals', args: {
                'meds': selectedMeds.length.toString(),
                'qty': totalQty.toString(),
              }),
              style: TextStyle(
                fontSize: 11,
                color: appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: selectedMeds.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('wh.empty_shelf'),
                        style: TextStyle(
                          fontSize: 12,
                          color: appColors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: selectedMeds.length,
                      separatorBuilder: (context, index) => Divider(
                        color: appColors.border,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final m = selectedMeds[index];
                        final card = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m.brand} · Batch: ${m.batchNumber}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: appColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${m.quantity} ${m.unit}s',
                                    style: AppTheme.mono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (m.controlled)
                                    StatusBadge(
                                      text: context.tr('wh.ctrl_badge'),
                                      variant: BadgeVariant.danger,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );

                        return Draggable<Medicine>(
                          data: m,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: appColors.foreground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  color: appColors.background,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: card,
                          ),
                          child: card,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
