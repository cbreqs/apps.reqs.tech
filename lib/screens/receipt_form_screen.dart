import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/fuel_receipt.dart';
import '../providers/providers.dart';
import '../app/theme.dart';

/// Manual receipt entry screen.
/// Launched with a [Vehicle] as route argument:
///   Navigator.pushNamed(context, '/add-receipt', arguments: vehicle)
class ReceiptFormScreen extends ConsumerStatefulWidget {
  const ReceiptFormScreen({super.key});

  @override
  ConsumerState<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends ConsumerState<ReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Vehicle? _vehicle;
  bool _vehicleLoaded = false;

  final _dateController = TextEditingController();
  String _gallons = '';
  String _sellerName = '';
  String _sellerStreet = '';
  String _sellerCity = '';
  String _sellerState = 'MO';
  String _sellerZip = '';
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_vehicleLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Vehicle) _vehicle = args;
      _vehicleLoaded = true;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicle != null
            ? 'Add Receipt — ${_vehicle!.year} ${_vehicle!.makeModel}'
            : 'Add Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle selector — dropdown if no vehicle passed, chip if pre-selected
              vehiclesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (vehicles) => DropdownButtonFormField<Vehicle>(
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  value: _vehicle != null && vehicles.any((v) => v.vin == _vehicle!.vin)
                      ? vehicles.firstWhere((v) => v.vin == _vehicle!.vin)
                      : null,
                  items: vehicles.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v.year} ${v.makeModel} (${v.fuelType.displayName})'),
                  )).toList(),
                  onChanged: (v) => setState(() => _vehicle = v),
                  validator: (v) => v == null ? 'Select a vehicle' : null,
                ),
              ),
              const SizedBox(height: 20),

              // Date
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date Purchased',
                  helperText: 'MM/DD/YYYY · Must be July 1 – June 30',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                keyboardType: TextInputType.datetime,
                onTap: () => _pickDate(context),
                readOnly: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Gallons
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Gallons Purchased',
                  helperText: 'Enter exact gallons to 3 decimal places',
                  suffixText: 'gal',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSaved: (v) => _gallons = v?.trim() ?? '',
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter valid gallons';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Seller Information',
                    style: Theme.of(context).textTheme.titleLarge),
              ),

              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Seller / Station Name'),
                onSaved: (v) => _sellerName = v?.trim() ?? '',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Street Address'),
                onSaved: (v) => _sellerStreet = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'City'),
                      onSaved: (v) => _sellerCity = v?.trim() ?? '',
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: 'MO',
                      decoration:
                          const InputDecoration(labelText: 'State'),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      onSaved: (v) => _sellerState = v?.trim() ?? 'MO',
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'ZIP', counterText: ''),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      onSaved: (v) => _sellerZip = v?.trim() ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Refund preview
              _RefundPreviewTile(gallonsText: _gallons),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Receipt'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Select purchase date',
      builder: (context, child) => child!,
    );
    if (picked != null) {
      _dateController.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_vehicle == null) return;
    _formKey.currentState?.save();

    setState(() => _saving = true);

    // Normalise gallons to 3 decimal places
    final gallonsDouble = double.tryParse(_gallons) ?? 0.0;
    final gallonsStr = gallonsDouble.toStringAsFixed(3);

    final receipt = FuelReceipt(
      vehicleId: _vehicle!.vin,
      fuelType: _vehicle!.fuelType,
      gallons: gallonsStr,
      date: _dateController.text,
      sellerName: _sellerName,
      sellerStreet: _sellerStreet,
      sellerCity: _sellerCity,
      sellerState: _sellerState,
      sellerZip: _sellerZip,
    );

    await ref.read(receiptProvider(_vehicle!.vin).notifier).add(receipt);
    // Invalidate refund summary so home screen updates
    ref.invalidate(refundSummaryProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Receipt saved — $gallonsStr gal · \$${(gallonsDouble * 0.125).toStringAsFixed(2)} refund value'),
      ),
    );
    Navigator.pop(context);
  }
}

/// Shows a live refund value as the user types gallons.
class _RefundPreviewTile extends StatelessWidget {
  final String gallonsText;
  const _RefundPreviewTile({required this.gallonsText});

  @override
  Widget build(BuildContext context) {
    final gallons = double.tryParse(gallonsText) ?? 0.0;
    final refund = gallons * 0.125;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.col.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Refund value for this receipt:',
              style: TextStyle(fontSize: 13)),
          Text(
            '\$${refund.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.col.gold,
            ),
          ),
        ],
      ),
    );
  }
}
