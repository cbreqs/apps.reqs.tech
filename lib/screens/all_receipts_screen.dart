import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fuel_receipt.dart';
import '../models/vehicle.dart';
import '../providers/providers.dart';
import '../app/theme.dart';

enum _SortField { date, gallons, vehicle }

final _allReceiptsProvider = FutureProvider<List<FuelReceipt>>((ref) {
  return ref.watch(dbProvider).getAllReceipts();
});

class AllReceiptsScreen extends ConsumerStatefulWidget {
  const AllReceiptsScreen({super.key});

  @override
  ConsumerState<AllReceiptsScreen> createState() => _AllReceiptsScreenState();
}

class _AllReceiptsScreenState extends ConsumerState<AllReceiptsScreen> {
  _SortField _sortField = _SortField.date;
  bool _sortAscending = false;

  @override
  void initState() {
  super.initState();
  // Refresh receipts every time this screen is opened
  Future.microtask(() => ref.invalidate(_allReceiptsProvider));
  }

  List<FuelReceipt> _sorted(List<FuelReceipt> receipts, Map<String, Vehicle> vehicleMap) {
    final list = [...receipts];
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case _SortField.date:
          cmp = a.date.compareTo(b.date);
        case _SortField.gallons:
          cmp = a.gallonsValue.compareTo(b.gallonsValue);
        case _SortField.vehicle:
          final vA = vehicleMap[a.vehicleId]?.makeModel ?? '';
          final vB = vehicleMap[b.vehicleId]?.makeModel ?? '';
          cmp = vA.compareTo(vB);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _setSort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = field == _SortField.vehicle;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(_allReceiptsProvider);
    final vehiclesAsync = ref.watch(vehicleProvider);
    final col = context.col;

    final vehicleMap = {
      for (final v in vehiclesAsync.valueOrNull ?? <Vehicle>[]) v.vin: v
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan receipt',
            onPressed: () => Navigator.pushNamed(context, '/scan-receipt'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add receipt manually',
            onPressed: () => Navigator.pushNamed(context, '/add-receipt'),
          ),
        ],
      ),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (receipts) {
          if (receipts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 56,
                        color: col.mutedText.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No receipts yet.',
                        style: TextStyle(color: col.labelText)),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan a Receipt'),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/scan-receipt'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sorted = _sorted(receipts, vehicleMap);
          final totalGallons =
              receipts.fold<double>(0, (s, r) => s + r.gallonsValue);
          final totalRefund = totalGallons * 0.125;

          return Column(
            children: [
              // Summary bar
              Container(
                color: col.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${receipts.length} receipt${receipts.length == 1 ? '' : 's'}',
                        style: TextStyle(color: col.onPrimary, fontSize: 13),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${totalGallons.toStringAsFixed(3)} gal',
                          style: TextStyle(
                              color: col.onPrimary.withValues(alpha: 0.7),
                              fontSize: 13),
                        ),
                        Text(
                          '\$${totalRefund.toStringAsFixed(2)} refund',
                          style: TextStyle(
                            color: col.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sort bar
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Text('Sort:',
                        style: TextStyle(
                            fontSize: 12, color: col.labelText)),
                    const SizedBox(width: 8),
                    _SortChip(label: 'Date', field: _SortField.date,
                        current: _sortField, ascending: _sortAscending, onTap: _setSort),
                    const SizedBox(width: 6),
                    _SortChip(label: 'Gallons', field: _SortField.gallons,
                        current: _sortField, ascending: _sortAscending, onTap: _setSort),
                    const SizedBox(width: 6),
                    _SortChip(label: 'Vehicle', field: _SortField.vehicle,
                        current: _sortField, ascending: _sortAscending, onTap: _setSort),
                  ],
                ),
              ),

              // Receipt list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final r = sorted[i];
                    final vehicle = vehicleMap[r.vehicleId];
                    return _ReceiptTile(
                        receipt: r, vehicle: vehicle, onRefresh: () {
                      ref.invalidate(_allReceiptsProvider);
                      ref.invalidate(refundSummaryProvider);
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final _SortField field;
  final _SortField current;
  final bool ascending;
  final void Function(_SortField) onTap;

  const _SortChip({
    required this.label, required this.field, required this.current,
    required this.ascending, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == field;
    return GestureDetector(
      onTap: () => onTap(field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: active
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.col.labelText,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                )),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 11,
                  color: Theme.of(context).colorScheme.onPrimary),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final FuelReceipt receipt;
  final Vehicle? vehicle;
  final VoidCallback onRefresh;

  const _ReceiptTile({
    required this.receipt,
    required this.vehicle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final vehicleLabel = vehicle != null
        ? '${vehicle!.year} ${vehicle!.makeModel}'
        : 'Unknown vehicle';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: col.primary.withValues(alpha: 0.15),
          child: Icon(Icons.local_gas_station, color: col.primary, size: 20),
        ),
        title: Text(receipt.sellerName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${receipt.date}  ·  ${receipt.gallons} gal  ·  ${receipt.fuelType.displayName}\n'
          '$vehicleLabel',
          style: TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${receipt.refundAmount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: col.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            Text('refund',
                style: TextStyle(fontSize: 11, color: col.mutedText)),
          ],
        ),
        onTap: () => Navigator.pushNamed(context, '/edit-receipt',
            arguments: receipt),
      ),
    );
  }
}
