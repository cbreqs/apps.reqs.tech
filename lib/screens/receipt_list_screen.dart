import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/fuel_receipt.dart';
import '../providers/providers.dart';
import '../app/theme.dart';

enum _SortField { date, gallons, name }

/// Shows all receipts for a specific vehicle.
/// Launched with a [Vehicle] as route argument:
///   Navigator.pushNamed(context, '/receipts', arguments: vehicle)
class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  _SortField _sortField = _SortField.date;
  bool _sortAscending = false; // date defaults newest-first

  List<FuelReceipt> _sorted(List<FuelReceipt> receipts) {
    final list = [...receipts];
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case _SortField.date:
          cmp = a.date.compareTo(b.date);
        case _SortField.gallons:
          cmp = a.gallonsValue.compareTo(b.gallonsValue);
        case _SortField.name:
          cmp = a.sellerName.toLowerCase().compareTo(b.sellerName.toLowerCase());
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
        _sortAscending = field == _SortField.name; // name defaults A→Z
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ModalRoute.of(context)!.settings.arguments as Vehicle;
    final receiptsAsync = ref.watch(receiptProvider(vehicle.vin));

    return Scaffold(
      appBar: AppBar(
        title: Text('${vehicle.year} ${vehicle.makeModel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add receipt manually',
            onPressed: () => Navigator.pushNamed(
              context,
              '/add-receipt',
              arguments: vehicle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan receipt',
            onPressed: () => Navigator.pushNamed(
              context,
              '/scan-receipt',
              arguments: vehicle,
            ),
          ),
        ],
      ),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (receipts) => Column(
          children: [
            _VehicleSummaryBar(vehicle: vehicle, receipts: receipts),
            if (receipts.isNotEmpty) _SortBar(
              current: _sortField,
              ascending: _sortAscending,
              onSort: _setSort,
            ),
            Expanded(
              child: receipts.isEmpty
                  ? _EmptyState(vehicle: vehicle)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: receipts.length,
                      itemBuilder: (context, i) {
                        final sorted = _sorted(receipts);
                        return _ReceiptTile(
                          receipt: sorted[i],
                          vehicleVin: vehicle.vin,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => Navigator.pushNamed(
              context,
              '/scan-receipt',
              arguments: vehicle,
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => Navigator.pushNamed(
              context,
              '/add-receipt',
              arguments: vehicle,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  final _SortField current;
  final bool ascending;
  final void Function(_SortField) onSort;

  const _SortBar({
    required this.current,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text('Sort:',
              style: TextStyle(fontSize: 12, color: context.col.labelText)),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Date',
            field: _SortField.date,
            current: current,
            ascending: ascending,
            onTap: onSort,
          ),
          const SizedBox(width: 6),
          _SortChip(
            label: 'Gallons',
            field: _SortField.gallons,
            current: current,
            ascending: ascending,
            onTap: onSort,
          ),
          const SizedBox(width: 6),
          _SortChip(
            label: 'Business',
            field: _SortField.name,
            current: current,
            ascending: ascending,
            onTap: onSort,
          ),
        ],
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
    required this.label,
    required this.field,
    required this.current,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == field;
    return GestureDetector(
      onTap: () => onTap(field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.col.labelText,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VehicleSummaryBar extends StatelessWidget {
  final Vehicle vehicle;
  final List<FuelReceipt> receipts;

  const _VehicleSummaryBar(
      {required this.vehicle, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final totalGallons =
        receipts.fold<double>(0, (sum, r) => sum + r.gallonsValue);
    final totalRefund = totalGallons * 0.125;

    final col = context.col;
    return Container(
      color: col.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIN: ${vehicle.vin}',
                  style: TextStyle(color: col.onPrimary.withValues(alpha: 0.6), fontSize: 12),
                ),
                Text(
                  vehicle.fuelType.displayName,
                  style: TextStyle(color: col.onPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalGallons.toStringAsFixed(3)} gal',
                style: TextStyle(color: col.onPrimary.withValues(alpha: 0.7), fontSize: 13),
              ),
              Text(
                '\$${totalRefund.toStringAsFixed(2)} refund',
                style: TextStyle(
                  color: col.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!vehicle.isEligible)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Over 26,000 lbs — not eligible',
                child: Icon(Icons.warning_amber, color: Colors.amber, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptTile extends ConsumerWidget {
  final FuelReceipt receipt;
  final String vehicleVin;

  const _ReceiptTile({required this.receipt, required this.vehicleVin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(Icons.local_gas_station,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(
          receipt.sellerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${receipt.date}  ·  ${receipt.gallons} gal  ·  ${receipt.fuelType.displayName}\n'
          '${receipt.sellerCity.isNotEmpty ? '${receipt.sellerCity}, ${receipt.sellerState}' : receipt.sellerState}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${receipt.refundAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: context.col.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text('refund', style: TextStyle(fontSize: 11, color: context.col.mutedText)),
              ],
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: context.col.mutedText),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.pushNamed(context, '/edit-receipt', arguments: receipt);
                } else if (value == 'move') {
                  _moveReceipt(context, ref);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit_outlined), SizedBox(width: 8), Text('Edit')]),
                ),
                const PopupMenuItem(
                  value: 'move',
                  child: Row(children: [Icon(Icons.swap_horiz), SizedBox(width: 8), Text('Move to vehicle…')]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: ctx.col.crimson),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: ctx.col.crimson)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          '/edit-receipt',
          arguments: receipt,
        ),
      ),
    );
  }

  Future<void> _moveReceipt(BuildContext context, WidgetRef ref) async {
    if (receipt.id == null) return;
    final allVehicles = ref.read(vehicleProvider).value ?? [];
    final others = allVehicles.where((v) => v.vin != vehicleVin).toList();
    // Capture notifier before any async gap
    final receiptNotifier = ref.read(receiptProvider(vehicleVin).notifier);
    final container = ProviderScope.containerOf(context);

    if (others.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No other vehicles'),
          content: const Text('Add another vehicle first, then you can move this receipt.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    Vehicle? selected = others.length == 1 ? others.first : null;
    if (others.length > 1) {
      if (!context.mounted) return;
      selected = await showDialog<Vehicle>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Move to vehicle…'),
          children: others.map((v) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, v),
            child: Text('${v.year} ${v.makeModel}'),
          )).toList(),
        ),
      );
      if (selected == null) return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move receipt?'),
        content: Text(
          'Move ${receipt.date} — ${receipt.gallons} gal from ${receipt.sellerName} '
          'to ${selected!.year} ${selected.makeModel}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
        ],
      ),
    );
    if (confirmed != true) return;

    await receiptNotifier.moveReceipt(receipt.id!, selected!.vin);
    container.invalidate(refundSummaryProvider);
    container.invalidate(receiptProvider(selected!.vin));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (receipt.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: Text(
            '${receipt.date} — ${receipt.gallons} gal from ${receipt.sellerName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: ctx.col.crimson)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(receiptProvider(vehicleVin).notifier)
          .delete(receipt.id!);
      ref.invalidate(refundSummaryProvider);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final Vehicle vehicle;
  const _EmptyState({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 56, color: context.col.mutedText.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No receipts yet for this vehicle.',
              style: TextStyle(color: context.col.labelText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add receipts manually or scan them with your camera.',
              style: TextStyle(color: context.col.mutedText, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan a Receipt'),
              onPressed: () => Navigator.pushNamed(
                context,
                '/scan-receipt',
                arguments: vehicle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
