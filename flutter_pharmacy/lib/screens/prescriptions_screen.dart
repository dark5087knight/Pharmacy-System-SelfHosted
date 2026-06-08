import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/data_table.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  List<Prescription> _prescriptions = [];
  List<Customer> _customers = [];
  List<Medicine> _medicines = [];

  String _statusFilter = 'all'; // all, pending, validated, fulfilled, expired
  Prescription? _activeRx; // detail view for validation
  final Set<String> _verifiedItems = {}; // checkbox validation state
  int _activeRxTab = 0; // Active tab on narrow screens

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
      final rx = await _db.request<List<Prescription>>('prescriptions');
      final cust = await _db.request<List<Customer>>('customers');
      final meds = await _db.request<List<Medicine>>('medicines');
      if (mounted) {
        setState(() {
          _prescriptions = rx;
          _customers = cust;
          _medicines = meds;
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


  List<Prescription> _getFilteredRx() {
    return _prescriptions.where((rx) {
      if (_statusFilter != 'all' && rx.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  String _getCustomerName(String id) {
    final c = _customers.firstWhere((c) => c.id == id, orElse: () => Customer(
      id: '', name: 'Walk-in Patient', phone: '', email: '', loyaltyPoints: 0, membershipLevel: 'bronze', allergies: [], balance: 0, totalSpent: 0, visits: 0, notes: '',
    ));
    return c.name;
  }

  List<String> _getCustomerAllergies(String id) {
    final c = _customers.firstWhere((c) => c.id == id, orElse: () => Customer(
      id: '', name: 'Walk-in Patient', phone: '', email: '', loyaltyPoints: 0, membershipLevel: 'bronze', allergies: [], balance: 0, totalSpent: 0, visits: 0, notes: '',
    ));
    return c.allergies;
  }

  String _getCustomerDOB(String id) {
    final c = _customers.firstWhere((c) => c.id == id, orElse: () => Customer(
      id: '', name: 'Walk-in Patient', phone: '', email: '', loyaltyPoints: 0, membershipLevel: 'bronze', allergies: [], balance: 0, totalSpent: 0, visits: 0, notes: '',
    ));
    return c.dateOfBirth ?? 'N/A';
  }


  String _getMedName(String id) {
    final m = _medicines.firstWhere((m) => m.id == id, orElse: () => Medicine(
      id: '', name: 'Unknown drug', genericName: '', brand: '', category: '', barcode: '', sku: '', batchNumber: '', manufactureDate: '', expiryDate: '', quantity: 0, unit: '', purchasePrice: 0, sellingPrice: 0, discount: 0, taxRate: 0, lowStockThreshold: 0, location: Location(rack: '', shelf: '', warehouse: ''), status: '', controlled: false, prescriptionRequired: false, supplierId: '', description: '', sideEffects: [], interactions: [], dosage: '', storage: '', isPinned: false,
    ));
    return m.name;
  }

  void _approveRx() async {
    if (_activeRx == null) return;
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    final updated = _activeRx!.copyWith(status: 'validated');
    final event = ActivityEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      type: 'prescription',
      message: 'Validated Rx ${_activeRx!.id} by Dr. ${_activeRx!.doctorName}',
      actor: workspace.currentUser?.name ?? 'System',
      at: DateTime.now().toIso8601String(),
      severity: 'info',
    );
    await _db.updatePrescription(updated);
    await _db.addActivity(event);
    _fetchData();
    setState(() {
      _activeRx = updated;
      _verifiedItems.clear();
    });
  }

  void _rejectRx() async {
    if (_activeRx == null) return;
    final updated = _activeRx!.copyWith(status: 'expired');
    await _db.updatePrescription(updated);
    _fetchData();
    setState(() {
      _activeRx = updated;
      _verifiedItems.clear();
    });
  }

  void _compileToPOS(WorkspaceProvider workspace) async {
    if (_activeRx == null) return;
    final updated = _activeRx!.copyWith(status: 'fulfilled');
    await _db.updatePrescription(updated);
    _fetchData();
    if (!mounted) return;
    setState(() {
      _activeRx = null;
    });

    workspace.openTab('pos');
    workspace.showNotification(
      title: context.tr('presc.toast.loaded_title'),
      body: context.tr('presc.toast.loaded_body'),
      category: 'system',
    );
  }

  void _simulateScan() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(dialogCtx.tr('presc.ocr.dialog_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: Text(dialogCtx.tr('presc.ocr.dialog_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(dialogCtx.tr('presc.ocr.dialog_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).primaryColor,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _runOCRSimulation();
              },
              child: Text(dialogCtx.tr('presc.ocr.dialog_start')),
            ),
          ],
        );
      },
    );
  }

  void _runOCRSimulation() async {
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    if (_customers.isEmpty || _medicines.isEmpty) {
      workspace.showNotification(
        title: 'OCR Failed',
        body: 'Please ensure you have customers and medicines in the system first.',
        category: 'error',
      );
      return;
    }
    workspace.showNotification(
      title: context.tr('presc.toast.running_ocr_title'),
      body: context.tr('presc.toast.running_ocr_body'),
      category: 'system',
    );
    await Future.delayed(const Duration(seconds: 1));

    final randomCust = _customers[_customers.length > 2 ? 2 : 0];
    final randomMed = _medicines[0];
    final rxId = 'rx_${DateTime.now().millisecondsSinceEpoch}';
    
    final newRx = Prescription(
      id: rxId,
      customerId: randomCust.id,
      doctorName: 'Dr. Sofia Rossi',
      doctorLicense: 'LIC-73921',
      issuedAt: DateTime.now().toIso8601String(),
      status: 'pending',
      refillsRemaining: 3,
      items: [
        PrescriptionItem(medicineId: randomMed.id, quantity: 30, dosage: '1 tab BID'),
      ],
    );

    await _db.createPrescription(newRx);
    _fetchData();

    if (!mounted) return;
    workspace.showNotification(
      title: context.tr('presc.toast.scanned_title'),
      body: context.tr('presc.toast.scanned_body'),
      category: 'system',
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final workspace = Provider.of<WorkspaceProvider>(context);

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
              'Failed to load prescriptions: $_errorMsg',
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


    final filtered = _getFilteredRx();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;

          final listWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                icon: LucideIcons.fileSpreadsheet,
                title: context.tr('presc.title'),
                subtitle: context.tr('presc.subtitle'),
                actions: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.foreground,
                    foregroundColor: appColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _simulateScan,
                  icon: const Icon(LucideIcons.scan, size: 14),
                  label: Text(context.tr('presc.scan_btn'), style: const TextStyle(fontSize: 12)),
                ),
              ),

              // Pipeline tabs filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: appColors.border)),
                ),
                child: Row(
                  children: [
                    _statusFilterTab(context.tr('presc.filter.all'), 'all', appColors),
                    _statusFilterTab(context.tr('presc.filter.pending'), 'pending', appColors),
                    _statusFilterTab(context.tr('presc.filter.validated'), 'validated', appColors),
                    _statusFilterTab(context.tr('presc.filter.fulfilled'), 'fulfilled', appColors),
                    _statusFilterTab(context.tr('presc.filter.expired'), 'expired', appColors),
                  ],
                ),
              ),

              // Registry Data Table
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DataTableWidget<Prescription>(
                    data: filtered,
                    getRowId: (rx) => rx.id,
                    emptyText: context.tr('presc.empty'),
                    searchKeys: (rx) => [rx.id, _getCustomerName(rx.customerId), rx.doctorName, rx.doctorLicense],
                    onRowClick: (rx) {
                      setState(() {
                        _activeRx = rx;
                        _verifiedItems.clear();
                        _activeRxTab = 1;
                      });
                    },
                    columns: [
                      DataTableColumn(
                        key: 'id',
                        header: context.tr('presc.col.id'),
                        sortValue: (rx) => rx.id,
                        cellBuilder: (rx) => Text(rx.id, style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      DataTableColumn(
                        key: 'patient',
                        header: context.tr('presc.col.patient'),
                        cellBuilder: (rx) => Text(_getCustomerName(rx.customerId), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      DataTableColumn(
                        key: 'doctor',
                        header: context.tr('presc.col.doctor'),
                        cellBuilder: (rx) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(rx.doctorName, style: const TextStyle(fontSize: 12)),
                            Text(rx.doctorLicense, style: TextStyle(fontSize: 10, color: appColors.mutedForeground)),
                          ],
                        ),
                      ),
                      DataTableColumn(
                        key: 'date',
                        header: context.tr('presc.col.date'),
                        sortValue: (rx) => rx.issuedAt,
                        cellBuilder: (rx) => Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(rx.issuedAt)),
                          style: AppTheme.mono(fontSize: 12),
                        ),
                      ),
                      DataTableColumn(
                        key: 'refills',
                        header: context.tr('presc.col.refills'),
                        cellBuilder: (rx) => Text(context.tr('nav.prescriptions') == 'الوصفات الطبية' ? '${rx.refillsRemaining} تكرارات' : '${rx.refillsRemaining} refills', style: AppTheme.mono(fontSize: 12)),
                      ),
                      DataTableColumn(
                        key: 'status',
                        header: context.tr('presc.col.status'),
                        cellBuilder: (rx) {
                          BadgeVariant v = BadgeVariant.muted;
                          if (rx.status == 'pending') {
                            v = BadgeVariant.warning;
                          } else if (rx.status == 'validated') {
                            v = BadgeVariant.success;
                          } else if (rx.status == 'expired') {
                            v = BadgeVariant.danger;
                          }
                          String statusText = rx.status;
                          if (rx.status == 'pending') {
                            statusText = context.tr('presc.filter.pending');
                          } else if (rx.status == 'validated') {
                            statusText = context.tr('presc.filter.validated');
                          } else if (rx.status == 'fulfilled') {
                            statusText = context.tr('presc.filter.fulfilled');
                          } else if (rx.status == 'expired') {
                            statusText = context.tr('presc.filter.expired');
                          }
                          return StatusBadge(text: statusText, variant: v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          Widget buildDetailWidget() {
            return Container(
              width: isWide ? 420 : double.infinity,
              height: double.infinity,
              color: appColors.surface1,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('presc.sheet.title')} (${_activeRx!.id})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => setState(() => _activeRx = null),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        // Patient Info Card
                        Container(
                          decoration: BoxDecoration(
                             color: appColors.surface2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('presc.sheet.patient_id'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 8),
                              _info(context.tr('presc.sheet.patient_name'), _getCustomerName(_activeRx!.customerId), appColors),
                              _info(context.tr('presc.sheet.dob'), _getCustomerDOB(_activeRx!.customerId), appColors),
                              _info(context.tr('presc.sheet.allergies'), _getCustomerAllergies(_activeRx!.customerId).join(', '), appColors),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          context.tr('presc.sheet.checklist'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 8),

                        // List of items
                        ..._activeRx!.items.map((it) {
                          final isVerified = _verifiedItems.contains(it.medicineId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: _activeRx!.status == 'pending'
                                  ? () {
                                      setState(() {
                                        if (isVerified) {
                                          _verifiedItems.remove(it.medicineId);
                                        } else {
                                          _verifiedItems.add(it.medicineId);
                                        }
                                      });
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: appColors.surface2,
                                  border: Border.all(color: appColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      isVerified ? LucideIcons.checkSquare : LucideIcons.square,
                                      size: 16,
                                      color: isVerified ? appColors.foreground : appColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getMedName(it.medicineId),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            context.tr('presc.sheet.instruction', args: {
                                              'dosage': it.dosage,
                                              'quantity': it.quantity.toString()
                                            }),
                                            style: TextStyle(fontSize: 10.5, color: appColors.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Allergy conflict scanner warning
                        if (_hasAllergyConflict()) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('presc.sheet.warning'),
                                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  const Divider(),
                  const SizedBox(height: 10),
                  if (_activeRx!.status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _rejectRx,
                            child: Text(context.tr('presc.sheet.reject'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors.foreground,
                              foregroundColor: appColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _verifiedItems.length == _activeRx!.items.length ? _approveRx : null,
                            child: Text(context.tr('presc.sheet.approve'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_activeRx!.status == 'validated') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.foreground,
                        foregroundColor: appColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _compileToPOS(workspace),
                      icon: const Icon(LucideIcons.shoppingCart, size: 14),
                      label: Text(context.tr('presc.sheet.compile'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appColors.surface2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          _activeRx!.status == 'fulfilled'
                              ? context.tr('presc.sheet.fulfilled_status')
                              : context.tr('presc.sheet.expired_status'),
                          style: TextStyle(fontSize: 12, color: appColors.mutedForeground),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          if (isWide) {
            return Row(
              children: [
                Expanded(child: listWidget),
                if (_activeRx != null) ...[
                  Container(width: 1, color: appColors.border),
                  Expanded(child: buildDetailWidget()),
                ],
              ],
            );

          } else {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: appColors.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: appColors.border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeRxTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeRxTab == 0 ? appColors.background : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _activeRxTab == 0 ? [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                              ] : null,
                            ),
                            child: Center(
                              child: Text(
                                context.tr('presc.tab.queue'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeRxTab == 0 ? appColors.foreground : appColors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeRxTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeRxTab == 1 ? appColors.background : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _activeRxTab == 1 ? [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                              ] : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.tr('presc.tab.panel'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _activeRxTab == 1 ? appColors.foreground : appColors.mutedForeground,
                                    ),
                                  ),
                                  if (_activeRx != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 6,
                                      width: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _activeRxTab == 0
                      ? listWidget
                      : (_activeRx != null
                          ? buildDetailWidget()
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.fileText, size: 48, color: appColors.mutedForeground),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('presc.tab.select_hint'),
                                    style: TextStyle(color: appColors.mutedForeground, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  bool _hasAllergyConflict() {
    if (_activeRx == null) return false;
    final allergies = _getCustomerAllergies(_activeRx!.customerId);
    if (allergies.isEmpty) return false;

    for (final it in _activeRx!.items) {
      final name = _getMedName(it.medicineId).toLowerCase();
      for (final a in allergies) {
        if (name.contains(a.toLowerCase())) return true;
      }
    }
    return false;
  }

  Widget _statusFilterTab(String label, String value, AppColors appColors) {
    final active = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? appColors.foreground : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? appColors.foreground : appColors.mutedForeground,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String val, AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 11.5, color: appColors.mutedForeground)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
