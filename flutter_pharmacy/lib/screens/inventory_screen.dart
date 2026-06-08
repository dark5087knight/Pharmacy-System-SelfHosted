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

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  List<Medicine> _medicines = [];
  List<Supplier> _suppliers = [];
  String _selectedSupplierId = '';
  String _filterStock = 'all'; // all, low, out, expired
  String _filterCategory = 'all';
  Medicine? _selectedMedicine; // for detail sheet
  bool _sheetOpen = false;

  // Add Form controllers
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _qtyController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _expiryController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _qtyController.dispose();
    _thresholdController.dispose();
    _sellPriceController.dispose();
    _buyPriceController.dispose();
    _expiryController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _fetchMedicines() async {
    final db = ApiService();
    try {
      final res = await db.request<List<Medicine>>('medicines');
      final sups = await db.request<List<Supplier>>('suppliers');
      if (mounted) {
        setState(() {
          _medicines = res;
          _suppliers = sups;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Medicine> _getFilteredMedicines() {
    final now = DateTime.now();
    return _medicines.where((m) {
      // 1. Stock Filter
      if (_filterStock == 'low') {
        if (m.quantity <= 0 || m.quantity > m.lowStockThreshold) return false;
      } else if (_filterStock == 'out') {
        if (m.quantity > 0) return false;
      } else if (_filterStock == 'expired') {
        try {
          final exp = DateTime.parse(m.expiryDate);
          if (exp.isAfter(now)) return false;
        } catch (_) {}
      }

      // 2. Category Filter
      if (_filterCategory != 'all' && m.category != _filterCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  void _openCreateSheet() {
    setState(() {
      _selectedMedicine = null;
      _skuController.text = 'SKU-${(10000 + _medicines.length).toString()}';
      _barcodeController.text = (990000000000 + _medicines.length).toString();
      _nameController.clear();
      _brandController.clear();
      _categoryController.text = 'Analgesic';
      _qtyController.text = '100';
      _thresholdController.text = '20';
      _sellPriceController.text = '9.99';
      _buyPriceController.text = '5.00';
      _expiryController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 365)));
      _selectedSupplierId = _suppliers.isNotEmpty ? _suppliers.first.id : '';
      _sheetOpen = true;
    });
  }

  void _openEditSheet(Medicine m) {
    setState(() {
      _selectedMedicine = m;
      _skuController.text = m.sku;
      _barcodeController.text = m.barcode;
      _nameController.text = m.name;
      _brandController.text = m.brand;
      _categoryController.text = m.category;
      _qtyController.text = m.quantity.toString();
      _thresholdController.text = m.lowStockThreshold.toString();
      _sellPriceController.text = m.sellingPrice.toString();
      _buyPriceController.text = m.purchasePrice.toString();
      _expiryController.text = DateFormat('yyyy-MM-dd').format(DateTime.parse(m.expiryDate));
      _selectedSupplierId = m.supplierId;
      _sheetOpen = true;
    });
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final qty = int.tryParse(_qtyController.text) ?? 0;
      final threshold = int.tryParse(_thresholdController.text) ?? 20;
      final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
      final buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;

      final db = ApiService();
      if (_selectedMedicine == null) {
        // Check for existing medicine with same name (case-insensitive)
        final existingIndex = _medicines.indexWhere(
          (m) => m.name.toLowerCase() == _nameController.text.trim().toLowerCase()
        );
        if (existingIndex != -1) {
          final existing = _medicines[existingIndex];
          // Stack: add quantity to existing
          final updatedMed = existing.copyWith(
            quantity: existing.quantity + qty,
            purchasePrice: buyPrice,
            sellingPrice: sellPrice,
            expiryDate: DateTime.parse(_expiryController.text).toIso8601String(),
            supplierId: _selectedSupplierId,
            lowStockThreshold: threshold,
          );
          await db.updateMedicine(updatedMed);
        } else {
          // Add new
          final newMed = Medicine(
            id: 'med_${DateTime.now().millisecondsSinceEpoch}',
            name: _nameController.text,
            genericName: _nameController.text,
            brand: _brandController.text,
            category: _categoryController.text,
            barcode: _barcodeController.text.trim(),
            sku: _skuController.text,
            batchNumber: 'B2025-001',
            manufactureDate: DateTime.now().toIso8601String(),
            expiryDate: DateTime.parse(_expiryController.text).toIso8601String(),
            quantity: qty,
            unit: 'tablet',
            purchasePrice: buyPrice,
            sellingPrice: sellPrice,
            discount: 0,
            taxRate: 12,
            lowStockThreshold: threshold,
            location: Location(rack: 'R1', shelf: 'S1', warehouse: 'Main'),
            status: 'active',
            controlled: false,
            prescriptionRequired: false,
            supplierId: _selectedSupplierId,
            isPinned: false,

            description: '',
            sideEffects: [],
            interactions: [],
            dosage: '1 daily',
            storage: 'Store below 25°C',
          );
          await db.createMedicine(newMed);
        }
      } else {
        // Edit existing
        final updatedMed = _selectedMedicine!.copyWith(
          name: _nameController.text,
          brand: _brandController.text,
          category: _categoryController.text,
          barcode: _barcodeController.text.trim(),
          quantity: qty,
          lowStockThreshold: threshold,
          sellingPrice: sellPrice,
          purchasePrice: buyPrice,
          supplierId: _selectedSupplierId,
          expiryDate: DateTime.parse(_expiryController.text).toIso8601String(),
        );
        await db.updateMedicine(updatedMed);
      }
      _fetchMedicines();
      setState(() {
        _sheetOpen = false;
      });
    }
  }

  void _onBulkDeleteMedicines(List<Medicine> selected) {
    if (selected.isEmpty) return;
    showDialog<bool>(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return AlertDialog(
          title: const Text('Bulk Delete Medications'),
          content: Text('Are you sure you want to delete ${selected.length} medications? This action is permanent and cannot be undone.'),
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
    ).then((confirm) async {
      if (confirm == true) {
        final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
        try {
          for (final m in selected) {
            await ApiService().deleteMedicine(m.id);
          }
          _fetchMedicines();
          workspace.showNotification(
            title: 'Bulk Deletion',
            body: 'Successfully deleted ${selected.length} medications.',
            category: 'system',
          );
        } catch (e) {
          workspace.showNotification(
            title: 'Error',
            body: e.toString().replaceAll('Exception: ', ''),
            category: 'error',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _getFilteredMedicines();
    final categories = _medicines.map((m) => m.category).toSet().toList();

    // Summary counts
    final lowStockCount = _medicines.where((m) => m.quantity > 0 && m.quantity <= m.lowStockThreshold).length;
    final outOfStockCount = _medicines.where((m) => m.quantity <= 0).length;

    return Scaffold(
      body: Row(
        children: [
          // Main table area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  icon: LucideIcons.package,
                  title: context.tr('inventory.title'),
                  subtitle: context.tr('inventory.subtitle'),
                  actions: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.foreground,
                      foregroundColor: appColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _openCreateSheet,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: Text(context.tr('inventory.add_btn'), style: const TextStyle(fontSize: 12)),
                  ),
                ),

                // Filters panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: appColors.border)),
                  ),
                  child: Row(
                    children: [
                      // Stock status tabs
                      _statusFilterTab(context.tr('inventory.filter.all'), 'all', appColors),
                      _statusFilterTab(context.tr('inventory.filter.low'), 'low', appColors, count: lowStockCount),
                      _statusFilterTab(context.tr('inventory.filter.out'), 'out', appColors, count: outOfStockCount),
                      _statusFilterTab(context.tr('inventory.filter.expired'), 'expired', appColors),

                      const Spacer(),

                      // Category dropdown filter
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: appColors.border),
                          borderRadius: BorderRadius.circular(6),
                          color: appColors.surface1,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterCategory,
                            style: TextStyle(fontSize: 12, color: appColors.foreground),
                            onChanged: (val) {
                              if (val != null) setState(() => _filterCategory = val);
                            },
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(context.tr('inventory.filter.all_cats'))),
                              ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DataTableWidget<Medicine>(
                      data: filtered,
                      getRowId: (m) => m.id,
                      emptyText: context.tr('inventory.empty'),
                      searchKeys: (m) => [m.name, m.sku, m.brand, m.genericName, m.barcode],
                      onRowClick: (m) {
                        workspace.openTab('medicine-details', title: m.name, params: {'id': m.id});
                      },
                      onBulkDelete: _onBulkDeleteMedicines,
                      columns: [
                        DataTableColumn(
                          key: 'sku',
                          header: context.tr('inventory.col.sku'),
                          sortValue: (m) => m.sku,
                          cellBuilder: (m) => Text(m.sku, style: AppTheme.mono(fontSize: 12)),
                        ),
                        DataTableColumn(
                          key: 'name',
                          header: context.tr('inventory.col.name'),
                          sortValue: (m) => m.name,
                          cellBuilder: (m) => Row(
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () async {
                                    setState(() {
                                      final idx = _medicines.indexWhere((x) => x.id == m.id);
                                      if (idx != -1) {
                                        _medicines[idx] = m.copyWith(isPinned: !m.isPinned);
                                      }
                                    });
                                    try {
                                      final updated = m.copyWith(isPinned: !m.isPinned);
                                      await ApiService().updateMedicine(updated);
                                      _fetchMedicines();
                                    } catch (_) {
                                      _fetchMedicines();
                                    }
                                  },
                                  child: Icon(
                                    m.isPinned ? LucideIcons.pin : LucideIcons.pinOff,
                                    size: 11,
                                    color: m.isPinned ? appColors.foreground : appColors.mutedForeground.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 1),
                                    Text(m.genericName, style: TextStyle(color: appColors.mutedForeground, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataTableColumn(
                          key: 'brand',
                          header: context.tr('inventory.col.brand'),
                          cellBuilder: (m) => Text('${m.brand} • ${m.category}', style: const TextStyle(fontSize: 12)),
                        ),
                        DataTableColumn(
                          key: 'quantity',
                          header: context.tr('inventory.col.qty'),
                          sortValue: (m) => m.quantity,
                          cellBuilder: (m) {
                            BadgeVariant v = BadgeVariant.success;
                            if (m.quantity == 0) {
                              v = BadgeVariant.danger;
                            } else if (m.quantity <= m.lowStockThreshold) {
                              v = BadgeVariant.warning;
                            }
                            return Row(
                              children: [
                                Text('${m.quantity} ${m.unit}s', style: AppTheme.mono(fontSize: 12)),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  text: m.quantity == 0 ? 'Out' : (m.quantity <= m.lowStockThreshold ? 'Low' : 'OK'),
                                  variant: v,
                                ),
                              ],
                            );
                          },
                        ),
                        DataTableColumn(
                          key: 'price',
                          header: context.tr('inventory.col.price'),
                          cellBuilder: (m) => Text(
                            '\$${m.purchasePrice.toStringAsFixed(2)} / \$${m.sellingPrice.toStringAsFixed(2)}',
                            style: AppTheme.mono(fontSize: 12),
                          ),
                        ),
                        DataTableColumn(
                          key: 'expiry',
                          header: context.tr('inventory.col.expiry'),
                          sortValue: (m) => m.expiryDate,
                          cellBuilder: (m) {
                            final now = DateTime.now();
                            Color textColor = appColors.foreground;
                            try {
                              final exp = DateTime.parse(m.expiryDate);
                              final days = exp.difference(now).inDays;
                              if (days < 0) {
                                textColor = appColors.destructive;
                              } else if (days <= 60) {
                                textColor = appColors.warning;
                              }
                            } catch (_) {}
                            return Text(
                              DateFormat('yyyy-MM-dd').format(DateTime.parse(m.expiryDate)),
                              style: AppTheme.mono(fontSize: 12, color: textColor),
                            );
                          },
                        ),
                      ],
                      rowActionBuilder: (m) {
                        return PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.moreHorizontal, size: 14),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _openEditSheet(m);
                            } else if (val == 'details') {
                              workspace.openTab('medicine-details', title: m.name, params: {'id': m.id});
                            } else if (val == 'delete') {
                              showDialog<bool>(
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
                              ).then((confirm) {
                                if (confirm == true) {
                                  ApiService().deleteMedicine(m.id).then((_) {
                                    _fetchMedicines();
                                  }).catchError((err) {
                                    debugPrint(err.toString());
                                  });
                                }
                              });
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'details', child: Text(context.tr('inventory.action.details'), style: const TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'edit', child: Text(context.tr('inventory.action.edit'), style: const TextStyle(fontSize: 12))),
                            PopupMenuItem(value: 'delete', child: Text(context.tr('inventory.action.delete'), style: TextStyle(fontSize: 12, color: appColors.destructive))),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sliding drawer sheet (edit / create)
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
                        Text(
                          _selectedMedicine == null ? context.tr('inventory.form.add') : context.tr('inventory.form.edit'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                          _buildField(context.tr('inventory.form.sku'), _skuController, enabled: false),
                          _buildField(context.tr('inventory.form.barcode'), _barcodeController, required: true),
                          if (_selectedMedicine != null)
                            _buildField(context.tr('inventory.form.name'), _nameController, required: true)
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('inventory.form.name'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Autocomplete<Medicine>(
                                    displayStringForOption: (Medicine m) => m.name,
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return const Iterable<Medicine>.empty();
                                      return _medicines.where((m) =>
                                        m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (Medicine selection) {
                                      _nameController.text = selection.name;
                                      _brandController.text = selection.brand;
                                      _categoryController.text = selection.category;
                                      _skuController.text = selection.sku;
                                      _buyPriceController.text = selection.purchasePrice.toString();
                                      _sellPriceController.text = selection.sellingPrice.toString();
                                      _qtyController.text = selection.quantity.toString();
                                      _thresholdController.text = selection.lowStockThreshold.toString();
                                      _selectedSupplierId = selection.supplierId;
                                      setState(() {});
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                                      if (controller.text.isEmpty && _nameController.text.isNotEmpty) {
                                        controller.text = _nameController.text;
                                      }
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        onChanged: (val) {
                                          _nameController.text = val;
                                        },
                                        style: const TextStyle(fontSize: 12),
                                        validator: (val) {
                                          _nameController.text = val ?? '';
                                          return (val == null || val.trim().isEmpty)
                                              ? context.tr('inventory.required_field')
                                              : null;
                                        },
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(10),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          _buildField(context.tr('inventory.form.brand'), _brandController, required: true),
                          _buildField(context.tr('inventory.form.category'), _categoryController, required: true),
                          _buildField(context.tr('inventory.form.qty'), _qtyController, number: true),
                          _buildField(context.tr('inventory.form.threshold'), _thresholdController, number: true),
                          _buildField(context.tr('inventory.form.buy_price'), _buyPriceController, number: true),
                          _buildField(context.tr('inventory.form.sell_price'), _sellPriceController, number: true),
                          _buildDatePickerField(context.tr('inventory.form.expiry'), _expiryController, required: true),
                          
                          // Supplier dropdown
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.tr('inventory.form.supplier'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
                                  validator: (val) => val == null || val.isEmpty ? context.tr('inventory.required_field') : null,
                                ),
                              ],
                            ),
                          ),
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
                      child: Text(context.tr('inventory.form.save'), style: const TextStyle(fontSize: 12)),
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

  Widget _statusFilterTab(String label, String value, AppColors appColors, {int? count}) {
    final active = _filterStock == value;
    return InkWell(
      onTap: () => setState(() => _filterStock = value),
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
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? appColors.foreground : appColors.mutedForeground,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: active ? appColors.foreground : appColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  count.toString(),
                  style: AppTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: active ? appColors.background : appColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        ),
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
                ? (val) => val == null || val.trim().isEmpty ? context.tr('inventory.required_field') : null
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
                ? (val) => val == null || val.trim().isEmpty ? context.tr('inventory.required_field') : null
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
