import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/fuel_receipt.dart';
import '../providers/providers.dart';
import '../app/theme.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _vin = '';
  String _makeModel = '';
  String _year = '';
  bool _underWeightLimit = true;
  FuelType _fuelType = FuelType.gasoline;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eligibility notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.col.subtleFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.col.subtleBorder),
                ),
                child: Text(
                  'Only vehicles with a gross weight of 26,000 lbs or less are eligible for the Missouri motor fuel tax refund.',
                  style: TextStyle(fontSize: 13, color: context.col.primary),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'VIN',
                  helperText: 'Found on driver\'s side door jamb plate',
                ),
                textCapitalization: TextCapitalization.characters,
                onSaved: (v) => _vin = v?.trim() ?? '',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.col.subtleFill,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'MOgas MOmoney does not validate VINs or any other vehicle information. '
                  'Please verify all details are correct before generating your refund form.',
                  style: TextStyle(fontSize: 12, color: context.col.labelText),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(labelText: 'Make / Model'),
                onSaved: (v) => _makeModel = v?.trim() ?? '',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _year = v?.trim() ?? '',
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1900 || n > 2100) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fuel type
              Text('Fuel Type',
                  style: TextStyle(fontSize: 13, color: context.col.labelText)),
              const SizedBox(height: 8),
              SegmentedButton<FuelType>(
                segments: const [
                  ButtonSegment(
                      value: FuelType.gasoline, label: Text('Gasoline')),
                  ButtonSegment(
                      value: FuelType.clearDiesel, label: Text('Clear Diesel')),
                  ButtonSegment(
                      value: FuelType.dyedDiesel,
                      label: Text('Dyed Diesel'),
                      tooltip:
                          'Government & school district filers only'),
                ],
                selected: {_fuelType},
                onSelectionChanged: (s) =>
                    setState(() => _fuelType = s.first),
              ),
              if (_fuelType == FuelType.dyedDiesel)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠ Dyed diesel is only claimable by government entities or school districts.',
                    style: TextStyle(
                        color: context.col.crimson, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),

              // Weight eligibility
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gross weight is 26,000 lbs or less'),
                subtitle: const Text(
                    'Required for refund eligibility',
                    style: TextStyle(fontSize: 12)),
                value: _underWeightLimit,
                onChanged: (v) =>
                    setState(() => _underWeightLimit = v ?? true),
              ),
              if (!_underWeightLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'This vehicle will be saved but will not be included in your refund claim.',
                    style: TextStyle(
                        color: context.col.crimson, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Vehicle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    setState(() => _saving = true);

    final vehicle = Vehicle(
      vin: _vin,
      makeModel: _makeModel,
      year: _year,
      underWeightLimit: _underWeightLimit,
      fuelType: _fuelType,
    );

    await ref.read(vehicleProvider.notifier).add(vehicle);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle saved')),
    );
    Navigator.pop(context);
  }
}
