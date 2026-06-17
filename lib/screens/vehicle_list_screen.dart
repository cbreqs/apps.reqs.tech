import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/vehicle.dart';
import '../app/theme.dart';


class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleProvider);
    final col = context.col;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-vehicle'),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading vehicles: $e')),
        data: (vehicles) => vehicles.isEmpty
            ? const Center(child: Text('No vehicles yet. Tap + to add one.'))
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: col.subtleFill,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      'Tap a vehicle to view and edit its receipts. '
                      'Long-press a receipt to delete it.',
                      style: TextStyle(fontSize: 13, color: col.labelText),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) =>
                          _VehicleTile(vehicle: vehicles[index]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  final Vehicle vehicle;
  const _VehicleTile({required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final isPlaceholder = vehicle.vin == kDefaultVehicleVin;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: isPlaceholder
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: col.gold, width: 1.5),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPlaceholder)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: col.gold.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: col.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Placeholder — add your real vehicle, then delete this.',
                      style: TextStyle(
                          fontSize: 12,
                          color: col.gold,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Consumer(
            builder: (context, ref, _) {
              final receiptsAsync = ref.watch(receiptProvider(vehicle.vin));
              final receipts = receiptsAsync.valueOrNull ?? [];
              final totalGallons = receipts.fold<double>(0, (s, r) => s + r.gallonsValue);
              final totalRefund = totalGallons * 0.125;
              final count = receipts.length;

              return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isPlaceholder
                  ? col.gold.withValues(alpha: 0.25)
                  : vehicle.isEligible
                      ? col.primary
                      : col.mutedText,
              child: Icon(
                isPlaceholder
                    ? Icons.directions_car_outlined
                    : Icons.directions_car,
                color: isPlaceholder ? col.gold : Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              '${vehicle.year} ${vehicle.makeModel}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isPlaceholder ? col.mutedText : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlaceholder ? 'VIN: (not set)' : 'VIN: ${vehicle.vin}',
                  style: TextStyle(color: col.labelText),
                ),
                Text('Fuel: ${vehicle.fuelType.displayName}',
                    style: TextStyle(color: col.labelText)),
                if (!isPlaceholder && count > 0)
                  Text(
                    '$count receipt${count == 1 ? '' : 's'}  ·  ${totalGallons.toStringAsFixed(3)} gal  ·  \$${totalRefund.toStringAsFixed(2)} refund',
                    style: TextStyle(
                      color: vehicle.isEligible ? col.primary : col.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (!vehicle.isEligible)
                  Text(
                    '⚠ Over 26,000 lbs — not eligible for refund',
                    style: TextStyle(color: col.crimson, fontSize: 12),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'move') _moveReceipts(context, ref);
                if (value == 'delete') _confirmDelete(context, ref);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'move',
                  child: Row(children: [
                    Icon(Icons.swap_horiz),
                    SizedBox(width: 8),
                    Text('Move receipts to…'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: col.crimson),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: col.crimson)),
                  ]),
                ),
              ],
            ),
            onTap: () => Navigator.pushNamed(context, '/receipts',
                arguments: vehicle),
          );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _moveReceipts(BuildContext context, WidgetRef ref) async {
    final allVehicles = ref.read(vehicleProvider).value ?? [];
    final others = allVehicles.where((v) => v.vin != vehicle.vin).toList();

    if (others.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No other vehicles'),
          content: const Text('Add another vehicle first, then you can move receipts to it.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Vehicle? selected = others.length == 1 ? others.first : null;

    if (others.length > 1) {
      selected = await showDialog<Vehicle>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Move receipts to…'),
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
        title: const Text('Move receipts?'),
        content: Text('Move all receipts from ${vehicle.year} ${vehicle.makeModel} to ${selected!.year} ${selected.makeModel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vehicleProvider.notifier).moveReceipts(vehicle.vin, selected!.vin);
      ref.invalidate(refundSummaryProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final col = context.col;
    final isPlaceholder = vehicle.vin == kDefaultVehicleVin;

    // For the placeholder: if other vehicles exist and it has receipts,
    // offer to move receipts before deleting instead of losing them.
    if (isPlaceholder) {
      final allVehicles = ref.read(vehicleProvider).value ?? [];
      final others = allVehicles.where((v) => v.vin != kDefaultVehicleVin).toList();
      final receipts = await ref.read(dbProvider).getReceiptsForVehicle(vehicle.vin);

      if (!context.mounted) return;

      if (others.isNotEmpty && receipts.isNotEmpty) {
        // Ask whether to move receipts or discard them
        final target = others.length == 1 ? others.first : null;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Move receipts?'),
            content: Text(
              'You have ${receipts.length} receipt${receipts.length == 1 ? '' : 's'} on the placeholder vehicle. '
              'Move ${receipts.length == 1 ? 'it' : 'them'} to '
              '${target != null ? '${target.year} ${target.makeModel}' : 'your other vehicle'} before deleting?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: Text('Delete all', style: TextStyle(color: col.crimson)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'move'),
                child: const Text('Move & delete'),
              ),
            ],
          ),
        );
        if (action == null || action == 'cancel') return;
        if (action == 'move' && target != null) {
          await ref.read(vehicleProvider.notifier)
              .moveReceiptsAndDelete(vehicle.vin, target.vin);
          ref.invalidate(refundSummaryProvider);
          return;
        }
      }
    }

    // Standard delete confirmation
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text(isPlaceholder
            ? 'Delete the placeholder vehicle and all its receipts?'
            : 'This will also delete all receipts for ${vehicle.year} ${vehicle.makeModel}. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: col.crimson)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(vehicleProvider.notifier).delete(vehicle.vin);
      ref.invalidate(refundSummaryProvider);
    }
  }
}
