import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class MedicineDetailsScreen extends StatefulWidget {
  final String medicineId;

  const MedicineDetailsScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailsScreen> createState() => _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends State<MedicineDetailsScreen> {
  bool _loading = true;
  Medicine? _medicine;
  List<Supplier> _suppliers = [];
  bool _sheetOpen = false;

  // Form keys & controllers
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _genericController = TextEditingController();
  final _categoryController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _batchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _unitController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _expiryController = TextEditingController();
  final _mfgController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dosageController = TextEditingController();
  final _storageController = TextEditingController();
  final _sideEffectsController = TextEditingController();
  final _interactionsController = TextEditingController();

  String _selectedSupplierId = '';
  bool _controlled = false;
  bool _prescriptionRequired = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _genericController.dispose();
    _categoryController.dispose();
    _barcodeController.dispose();
    _batchController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    _sellPriceController.dispose();
    _buyPriceController.dispose();
    _expiryController.dispose();
    _mfgController.dispose();
    _descriptionController.dispose();
    _dosageController.dispose();
    _storageController.dispose();
    _sideEffectsController.dispose();
    _interactionsController.dispose();
    super.dispose();
  }

  void _fetchDetails() async {
    try {
      final db = ApiService();
      final res = await db.request<Medicine>('medicines/${widget.medicineId}');
      final sups = await db.request<List<Supplier>>('suppliers');
      if (mounted) {
        setState(() {
          _medicine = res;
          _suppliers = sups;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openEditSheet() {
    final m = _medicine;
    if (m == null) return;
    setState(() {
      _skuController.text = m.sku;
      _nameController.text = m.name;
      _brandController.text = m.brand;
      _genericController.text = m.genericName;
      _categoryController.text = m.category;
      _barcodeController.text = m.barcode;
      _batchController.text = m.batchNumber;
      _qtyController.text = m.quantity.toString();
      _unitController.text = m.unit;
      _thresholdController.text = m.lowStockThreshold.toString();
      _sellPriceController.text = m.sellingPrice.toString();
      _buyPriceController.text = m.purchasePrice.toString();
      _expiryController.text = DateFormat('yyyy-MM-dd').format(DateTime.parse(m.expiryDate));
      _mfgController.text = DateFormat('yyyy-MM-dd').format(DateTime.parse(m.manufactureDate));
      _descriptionController.text = m.description;
      _dosageController.text = m.dosage;
      _storageController.text = m.storage;
      _sideEffectsController.text = m.sideEffects.join(', ');
      _interactionsController.text = m.interactions.join(', ');
      _selectedSupplierId = m.supplierId;
      _controlled = m.controlled;
      _prescriptionRequired = m.prescriptionRequired;
      _sheetOpen = true;
    });
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final qty = int.tryParse(_qtyController.text) ?? 0;
      final threshold = int.tryParse(_thresholdController.text) ?? 20;
      final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
      final buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;

      final updatedMed = _medicine!.copyWith(
        name: _nameController.text.trim(),
        genericName: _genericController.text.trim(),
        brand: _brandController.text.trim(),
        category: _categoryController.text.trim(),
        barcode: _barcodeController.text.trim(),
        batchNumber: _batchController.text.trim(),
        quantity: qty,
        unit: _unitController.text.trim(),
        lowStockThreshold: threshold,
        sellingPrice: sellPrice,
        purchasePrice: buyPrice,
        expiryDate: DateTime.parse(_expiryController.text).toIso8601String(),
        manufactureDate: DateTime.parse(_mfgController.text).toIso8601String(),
        controlled: _controlled,
        prescriptionRequired: _prescriptionRequired,
        supplierId: _selectedSupplierId,
        description: _descriptionController.text.trim(),
        dosage: _dosageController.text.trim(),
        storage: _storageController.text.trim(),
        sideEffects: _sideEffectsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        interactions: _interactionsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      );

      final db = ApiService();
      try {
        await db.updateMedicine(updatedMed);
        setState(() {
          _medicine = updatedMed;
          _sheetOpen = false;
        });
        _fetchDetails();
      } catch (err) {
        debugPrint(err.toString());
      }
    }
  }

  void _deleteMedication() async {
    final m = _medicine;
    if (m == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return AlertDialog(
          title: const Text('Delete Medication'),
          content: Text('Are you sure you want to delete ${m.name}? This action is permanent and cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('staff.cancel'), style: TextStyle(color: appColors.mutedForeground)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('staff.delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ApiService().deleteMedicine(m.id);
        if (mounted) {
          final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
          final tabId = 'medicine-details_${m.id}';
          workspace.closeTab(workspace.activeGroupIndex, tabId);
          workspace.showNotification(
            title: 'Medication Deleted',
            body: '${m.name} removed successfully.',
            category: 'system',
          );
        }
      } catch (e) {
        if (mounted) {
          final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
          workspace.showNotification(
            title: 'Error',
            body: e.toString().replaceAll('Exception: ', ''),
            category: 'error',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_medicine == null) {
      return Center(
        child: EmptyState(
          icon: LucideIcons.alertCircle,
          title: context.tr('med_details.error_title'),
          description: context.tr('med_details.error_desc'),
        ),
      );
    }

    final m = _medicine!;
    final margin = m.sellingPrice > 0 
        ? ((m.sellingPrice - m.purchasePrice) / m.sellingPrice * 100).toStringAsFixed(1)
        : '0.0';

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page header with navigation and name
        PageHeader(
          icon: LucideIcons.pill,
          title: m.name,
          subtitle: '${m.brand} · ${m.genericName}',
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: appColors.destructive),
                onPressed: _deleteMedication,
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: const Text('Delete Medication', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.foreground,
                  foregroundColor: appColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _openEditSheet,
                icon: const Icon(LucideIcons.edit, size: 14),
                label: const Text('Edit Medication', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left core column
                      Expanded(
                        flex: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Section(
                              title: context.tr('med_details.card.core'),
                              children: Column(
                                children: [
                                  _row(context.tr('med_details.sku'), m.sku, appColors, isMono: true),
                                  _row(context.tr('med_details.generic'), m.genericName, appColors),
                                  _row(context.tr('med_details.brand_mfg'), m.brand, appColors),
                                  _row(context.tr('med_details.category_class'), m.category, appColors),
                                  _row(context.tr('med_details.barcode_val'), m.barcode, appColors, isMono: true),
                                  _row(context.tr('med_details.batch_code'), m.batchNumber, appColors, isMono: true),
                                  _row(context.tr('med_details.mfg'), DateFormat('yyyy-MM-dd').format(DateTime.parse(m.manufactureDate)), appColors, isMono: true),
                                  _row(context.tr('med_details.exp'), DateFormat('yyyy-MM-dd').format(DateTime.parse(m.expiryDate)), appColors, isMono: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            Section(
                              title: context.tr('med_details.card.stock'),
                              children: Column(
                                children: [
                                  _rowWidget(
                                    context.tr('med_details.qty'),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${m.quantity} ${m.unit}s', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        StatusBadge(
                                          text: m.quantity == 0
                                              ? context.tr('inventory.filter.out')
                                              : (m.quantity <= m.lowStockThreshold
                                                  ? context.tr('inventory.filter.low')
                                                  : context.tr('med_details.status.good')),
                                          variant: m.quantity == 0 ? BadgeVariant.danger : (m.quantity <= m.lowStockThreshold ? BadgeVariant.warning : BadgeVariant.success),
                                        ),
                                      ],
                                    ),
                                    appColors,
                                  ),
                                  _row(context.tr('med_details.threshold'), '${m.lowStockThreshold} units', appColors, isMono: true),
                                  _row(context.tr('wh.warehouse'), m.location.warehouse, appColors),
                                  _row(context.tr('wh.rack'), m.location.rack, appColors, isMono: true),
                                  _row(context.tr('wh.shelf'), m.location.shelf, appColors, isMono: true),
                                  _rowWidget(
                                    context.tr('med_details.prescription'),
                                    StatusBadge(
                                      text: m.prescriptionRequired ? context.tr('med_details.yes') : context.tr('med_details.no'),
                                      variant: m.prescriptionRequired ? BadgeVariant.warning : BadgeVariant.outline,
                                    ),
                                    appColors,
                                  ),
                                  _rowWidget(
                                    context.tr('med_details.controlled'),
                                    StatusBadge(
                                      text: m.controlled ? context.tr('med_details.yes_controlled') : context.tr('med_details.no'),
                                      variant: m.controlled ? BadgeVariant.danger : BadgeVariant.outline,
                                    ),
                                    appColors,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            Section(
                              title: context.tr('med_details.card.finance'),
                              children: Column(
                                children: [
                                  _row(context.tr('med_details.buy'), '\$${m.purchasePrice.toStringAsFixed(2)}', appColors, isMono: true),
                                  _row(context.tr('med_details.sell'), '\$${m.sellingPrice.toStringAsFixed(2)}', appColors, isMono: true),
                                  _row(context.tr('med_details.margin'), '$margin%', appColors, isMono: true),
                                  _row(context.tr('med_details.discounts'), '${m.discount.toStringAsFixed(0)}%', appColors, isMono: true),
                                  _row(context.tr('med_details.tax'), '${m.taxRate.toStringAsFixed(0)}%', appColors, isMono: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wide) const SizedBox(width: 20),
                      // Right column
                      if (wide)
                        Expanded(
                          flex: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Section(
                                title: context.tr('med_details.card.posology'),
                                children: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('med_details.description').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(m.description, style: const TextStyle(fontSize: 12.5)),
                                    const SizedBox(height: 16),
                                    Text(context.tr('med_details.dosage').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(m.dosage, style: const TextStyle(fontSize: 12.5)),
                                    const SizedBox(height: 16),
                                    Text(context.tr('med_details.storage').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(m.storage, style: const TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              Section(
                                title: context.tr('med_details.card.safety'),
                                children: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('med_details.side_effects').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    ...m.sideEffects.map((s) => Text('• $s', style: const TextStyle(fontSize: 12))),
                                    if (m.sideEffects.isEmpty) Text(context.tr('med_details.none_reported'), style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 16),
                                    Text(context.tr('med_details.interactions').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    ...m.interactions.map((i) => Text('• $i', style: const TextStyle(fontSize: 12))),
                                    if (m.interactions.isEmpty) Text(context.tr('med_details.none_reported'), style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          Expanded(child: mainContent),
          if (_sheetOpen) ...[
            Container(width: 1, color: appColors.border),
            Container(
              width: 380,
              color: appColors.surface1,
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EDIT MEDICATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () => setState(() => _sheetOpen = false),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildField('SKU Code', _skuController, enabled: false),
                          _buildField('Product Name', _nameController, required: true),
                          _buildField('Generic Name', _genericController, required: true),
                          _buildField('Brand / Manufacturer', _brandController, required: true),
                          _buildField('Category', _categoryController, required: true),
                          _buildField('Barcode', _barcodeController, required: true),
                          _buildField('Batch Number', _batchController, required: true),
                          _buildField('Stock Qty', _qtyController, number: true),
                          _buildField('Unit (e.g. tablet)', _unitController, required: true),
                          _buildField('Low Threshold Warning', _thresholdController, number: true),
                          _buildField('Purchase Cost (\$)', _buyPriceController, number: true),
                          _buildField('Retail Selling Price (\$)', _sellPriceController, number: true),
                          _buildDatePickerField('Manufacture Date', _mfgController, required: true),
                          _buildDatePickerField('Expiry Date', _expiryController, required: true),
                          
                          // Controlled / Rx checkboxes
                          SwitchListTile(
                            title: const Text('Prescription Required (Rx)', style: TextStyle(fontSize: 12)),
                            value: _prescriptionRequired,
                            onChanged: (val) => setState(() => _prescriptionRequired = val),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('Controlled Substance', style: TextStyle(fontSize: 12)),
                            value: _controlled,
                            onChanged: (val) => setState(() => _controlled = val),
                            contentPadding: EdgeInsets.zero,
                          ),

                          // Supplier dropdown
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Supplier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _suppliers.any((s) => s.id == _selectedSupplierId) 
                                      ? _selectedSupplierId 
                                      : (_suppliers.isNotEmpty ? _suppliers.first.id : null),
                                  style: TextStyle(fontSize: 12, color: appColors.foreground),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.all(10),
                                  ),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedSupplierId = val);
                                    }
                                  },
                                  items: _suppliers.map((s) {
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.company, style: TextStyle(color: appColors.foreground)),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          
                          _buildField('Description', _descriptionController),
                          _buildField('Dosage', _dosageController),
                          _buildField('Storage Instructions', _storageController),
                          _buildField('Side Effects (comma-separated)', _sideEffectsController),
                          _buildField('Interactions (comma-separated)', _interactionsController),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.foreground,
                        foregroundColor: appColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _saveForm,
                      child: const Text('Save Medication Info', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppColors appColors, {bool isMono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: appColors.mutedForeground)),
          Text(
            value,
            style: isMono
                ? AppTheme.mono(fontSize: 12, color: appColors.foreground)
                : TextStyle(fontSize: 12, color: appColors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _rowWidget(String label, Widget widget, AppColors appColors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: appColors.mutedForeground)),
          widget,
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool enabled = true, bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(fontSize: 12),
            validator: required
                ? (val) => val == null || val.trim().isEmpty ? 'Required field' : null
                : null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(String label, TextEditingController controller, {required bool required}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 12),
            onTap: () async {
              final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (picked != null) {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
              }
            },
            validator: required
                ? (val) => val == null || val.trim().isEmpty ? 'Required field' : null
                : null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(10),
              suffixIcon: Icon(LucideIcons.calendar, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
