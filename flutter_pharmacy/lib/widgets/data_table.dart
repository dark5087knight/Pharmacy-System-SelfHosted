import 'package:flutter/material.dart';
import '../theme/theme.dart';

class DataTableColumn<T> {
  final String key;
  final String header;
  final Widget Function(T row) cellBuilder;
  final Comparable Function(T row)? sortValue;
  final TextAlign alignment;
  final double? width;

  DataTableColumn({
    required this.key,
    required this.header,
    required this.cellBuilder,
    this.sortValue,
    this.alignment = TextAlign.left,
    this.width,
  });
}

class DataTableWidget<T> extends StatefulWidget {
  final List<DataTableColumn<T>> columns;
  final List<T> data;
  final List<String> Function(T row)? searchKeys;
  final void Function(T row)? onRowClick;
  final String emptyText;
  final Widget? toolbarActions;
  final Widget Function(T row)? rowActionBuilder;
  final String Function(T row) getRowId;
  final void Function(List<T> selectedItems)? onBulkDelete;
  final void Function(List<T> selectedItems)? onBulkEdit;
  final bool hideRowActions;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.data,
    this.searchKeys,
    this.onRowClick,
    this.emptyText = 'No records.',
    this.toolbarActions,
    this.rowActionBuilder,
    required this.getRowId,
    this.onBulkDelete,
    this.onBulkEdit,
    this.hideRowActions = true,
  });

  @override
  State<DataTableWidget<T>> createState() => _DataTableWidgetState<T>();
}

class _DataTableWidgetState<T> extends State<DataTableWidget<T>> {
  String _searchQuery = '';
  String? _sortKey;
  bool _sortAscending = true;
  final Set<String> _selectedIds = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _getSelectedItems() {
    return widget.data.where((row) => _selectedIds.contains(widget.getRowId(row))).toList();
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
  }

  List<T> _getProcessedData() {
    List<T> result = List.from(widget.data);

    // 1. Filter
    if (_searchQuery.isNotEmpty && widget.searchKeys != null) {
      final query = _searchQuery.toLowerCase();
      result = result.where((row) {
        final keys = widget.searchKeys!(row);
        return keys.any((k) => k.toLowerCase().contains(query));
      }).toList();
    }

    // 2. Sort
    if (_sortKey != null) {
      final col = widget.columns.firstWhere((c) => c.key == _sortKey);
      if (col.sortValue != null) {
        result.sort((a, b) {
          final av = col.sortValue!(a);
          final bv = col.sortValue!(b);
          final comp = av.compareTo(bv);
          return _sortAscending ? comp : -comp;
        });
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final processedData = _getProcessedData();

    return Container(
      decoration: BoxDecoration(
        color: appColors.surface1,
        border: Border.all(color: appColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            decoration: BoxDecoration(
              color: appColors.surface2,
              border: Border(bottom: BorderSide(color: appColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (widget.searchKeys != null) ...[
                  SizedBox(
                    width: 260,
                    height: 32,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        fillColor: appColors.background,
                        hintText: 'Filter...',
                        prefixIcon: Icon(Icons.search, size: 14, color: appColors.mutedForeground),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_selectedIds.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: appColors.background,
                      border: Border.all(color: appColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedIds.size}',
                          style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Text('selected', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _selectedIds.clear()),
                          child: Text(
                            'clear',
                            style: TextStyle(fontSize: 11, color: appColors.mutedForeground, decoration: TextDecoration.underline),
                          ),
                        ),
                        if (widget.onBulkEdit != null) ...[
                          const SizedBox(width: 8),
                          Text('·', style: TextStyle(color: appColors.mutedForeground)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => widget.onBulkEdit!(_getSelectedItems()),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text('Bulk edit', style: TextStyle(fontSize: 11, color: appColors.mutedForeground)),
                            ),
                          ),
                        ],
                        if (widget.onBulkDelete != null) ...[
                          const SizedBox(width: 8),
                          Text('·', style: TextStyle(color: appColors.mutedForeground)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => widget.onBulkDelete!(_getSelectedItems()),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text('Delete', style: TextStyle(fontSize: 11, color: appColors.destructive)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.toolbarActions != null) widget.toolbarActions!,
                const SizedBox(width: 8),
                Text(
                  '${processedData.length} records',
                  style: AppTheme.mono(fontSize: 11, color: appColors.mutedForeground),
                ),
              ],
            ),
          ),
          
          // Table Headers and Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 280, // account for sidebar
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(appColors.surface1),
                    dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return appColors.surface2;
                      }
                      return Colors.transparent;
                    }),
                    dividerThickness: 0.5,
                    horizontalMargin: 12,
                    columnSpacing: 24,
                    headingRowHeight: 36,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    onSelectAll: (val) {
                      setState(() {
                        if (val == true) {
                          for (final r in processedData) {
                            _selectedIds.add(widget.getRowId(r));
                          }
                        } else {
                          for (final r in processedData) {
                            _selectedIds.remove(widget.getRowId(r));
                          }
                        }
                      });
                    },
                    columns: [
                      // Data columns
                      ...widget.columns.map((col) {
                        return DataColumn(
                          label: InkWell(
                            onTap: col.sortValue != null ? () => _toggleSort(col.key) : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  col.header.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: appColors.mutedForeground,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                if (col.sortValue != null) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    _sortKey == col.key
                                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                        : Icons.unfold_more,
                                    size: 11,
                                    color: appColors.mutedForeground.withValues(alpha: _sortKey == col.key ? 1.0 : 0.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      // Action Column
                      if (widget.rowActionBuilder != null && !widget.hideRowActions)
                        const DataColumn(label: SizedBox(width: 24, child: Text(''))),
                    ],
                    rows: processedData.isEmpty
                        ? []
                        : processedData.map((row) {
                            final rowId = widget.getRowId(row);
                            final isSelected = _selectedIds.contains(rowId);
                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(rowId);
                                  } else {
                                    _selectedIds.remove(rowId);
                                  }
                                });
                              },
                              color: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (isSelected) {
                                  return appColors.surface2.withValues(alpha: 0.7);
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return appColors.surface2;
                                }
                                return Colors.transparent;
                              }),
                              cells: [
                                ...widget.columns.map((col) {
                                  return DataCell(
                                    col.cellBuilder(row),
                                    onTap: widget.onRowClick != null
                                        ? () => widget.onRowClick!(row)
                                        : null,
                                  );
                                }),
                                if (widget.rowActionBuilder != null && !widget.hideRowActions)
                                  DataCell(widget.rowActionBuilder!(row)),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
          ),
          if (processedData.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.emptyText,
                  style: TextStyle(fontSize: 12, color: appColors.mutedForeground),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
extension SizeExtension on Set {
  int get size => length;
}
