import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fuel_receipt.dart';
import '../providers/providers.dart';
import '../app/theme.dart';
import '../widgets/seller_autocomplete.dart';

/// Edit an existing saved receipt.
/// Route argument: [FuelReceipt] (must have a non-null id).
class EditReceiptScreen extends ConsumerStatefulWidget {
  const EditReceiptScreen({super.key});

  @override
  ConsumerState<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends ConsumerState<EditReceiptScreen> {
  late FuelReceipt _original;
  bool _initialized = false;
  bool _saving = false;
  List<String> _knownSellers = [];
  List<String> _knownCities  = [];
  List<String> _knownZips    = [];

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    Future.wait([
      db.getUniqueSellers(),
      db.getUniqueCities(),
      db.getUniqueZips(),
    ]).then((results) {
      if (mounted) setState(() {
        _knownSellers = results[0];
        _knownCities  = results[1];
        _knownZips    = results[2];
      });
    });
  }

  final _dateController    = TextEditingController();
  final _gallonsController = TextEditingController();
  final _sellerController  = TextEditingController();
  final _streetController  = TextEditingController();
  final _cityController    = TextEditingController();
  final _stateController   = TextEditingController();
  final _zipController     = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _original = ModalRoute.of(context)!.settings.arguments as FuelReceipt;
      _dateController.text    = _original.date;
      _gallonsController.text = _original.gallons;
      _sellerController.text  = _original.sellerName;
      _streetController.text  = _original.sellerStreet;
      _cityController.text    = _original.sellerCity;
      _stateController.text   = _original.sellerState;
      _zipController.text     = _original.sellerZip;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _gallonsController.dispose();
    _sellerController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final gallonsText = _gallonsController.text.trim();
    final sellerText  = _sellerController.text.trim();

    if (gallonsText.isEmpty || sellerText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallons and seller name are required')),
      );
      return;
    }

    final gallons = double.tryParse(gallonsText);
    if (gallons == null || gallons <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid gallons amount (e.g. 12.345)')),
      );
      return;
    }

    setState(() => _saving = true);

    final updated = _original.copyWith(
      date:        _dateController.text.trim(),
      gallons:     gallons.toStringAsFixed(3),
      sellerName:  sellerText,
      sellerStreet: _streetController.text.trim(),
      sellerCity:  _cityController.text.trim(),
      sellerState: _stateController.text.trim(),
      sellerZip:   _zipController.text.trim(),
    );

    await ref.read(receiptProvider(_original.vehicleId).notifier).update(updated);
    ref.invalidate(refundSummaryProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved — ${updated.gallons} gal · \$${updated.refundAmount.toStringAsFixed(2)} refund value',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save changes',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Receipt image thumbnail — tap to view full size
            if (_original.imagePath != null) ...[
              _ReceiptThumbnail(imagePath: _original.imagePath!),
              const SizedBox(height: 16),
            ],

            // Info chip showing vehicle + fuel type
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(Icons.directions_car,
                      size: 16, color: context.col.onPrimary),
                  label: Text(
                    _original.fuelType.displayName,
                    style: TextStyle(color: context.col.onPrimary, fontSize: 12),
                  ),
                  backgroundColor: context.col.primary,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _Field(
              label: 'Date (MM/DD/YYYY)',
              controller: _dateController,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Gallons',
              controller: _gallonsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            SellerAutocomplete(
              controller: _sellerController,
              knownSellers: _knownSellers,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Street Address',
              controller: _streetController,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CityAutocomplete(
                    controller: _cityController,
                    knownCities: _knownCities,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: _Field(
                    label: 'State',
                    controller: _stateController,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: ZipAutocomplete(
                    controller: _zipController,
                    knownZips: _knownZips,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Live refund preview
            ValueListenableBuilder(
              valueListenable: _gallonsController,
              builder: (_, __, ___) {
                final g = double.tryParse(_gallonsController.text) ?? 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.col.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: context.col.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Refund value:',
                          style: TextStyle(fontSize: 13)),
                      Text(
                        '\$${(g * 0.125).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.col.gold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 8),
            Text(
              'Changes are saved to this device only.',
              style: TextStyle(fontSize: 12, color: context.col.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable receipt thumbnail — navigates to full-screen viewer.
class _ReceiptThumbnail extends StatelessWidget {
  final String imagePath;
  const _ReceiptThumbnail({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.pushNamed(
        context,
        '/view-image',
        arguments: imagePath,
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: file.existsSync()
                ? Image.file(
                    file,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 150,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            color: context.col.mutedText, size: 36),
                        const SizedBox(height: 6),
                        Text('Image no longer available',
                            style: TextStyle(color: context.col.mutedText, fontSize: 12)),
                      ],
                    ),
                  ),
          ),
          if (file.existsSync())
            Container(
              margin: const EdgeInsets.all(8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Tap to zoom',
                      style:
                          TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }
}
