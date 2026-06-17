import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/vehicle.dart';
import '../models/fuel_receipt.dart';
import '../services/receipt_parser.dart';
import '../providers/providers.dart';
import '../app/theme.dart';
import '../widgets/seller_autocomplete.dart';

const _kLastVehicleVin = 'last_scanned_vehicle_vin';

/// OCR receipt scanner. Accepts an optional [Vehicle] as route argument.
/// If no vehicle is passed, user must select one before saving.
class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  ConsumerState<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  Vehicle? _vehicle;
  File? _imageFile;
  bool _scanning = false;
  bool _saving = false;
  List<String> _knownSellers = [];
  List<String> _knownCities = [];
  List<String> _knownZips = [];

  final _dateController = TextEditingController();
  final _gallonsController = TextEditingController();
  final _sellerController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'MO');
  final _zipController = TextEditingController();

  bool _vehicleAutoSelected = false;

  @override
  void initState() {
    super.initState();
    _loadKnownSellers();
  }

  Future<void> _loadKnownSellers() async {
    final db = ref.read(dbProvider);
    final results = await Future.wait([
      db.getUniqueSellers(),
      db.getUniqueCities(),
      db.getUniqueZips(),
    ]);
    if (mounted) {
      setState(() {
        _knownSellers = results[0];
        _knownCities  = results[1];
        _knownZips    = results[2];
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Vehicle) {
      _vehicle = args;
      _vehicleAutoSelected = true;
      _saveLastVehicleVin(args.vin);
    }
  }

  /// Copies the temp cache image to permanent app documents storage.
  /// Returns the permanent path, or the original path if copy fails.
  Future<String> _copyImageToPermanentStorage(File tempFile) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(docsDir.path, 'receipt_images'));
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final fileName =
          'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempFile.path)}';
      final dest = File(p.join(imagesDir.path, fileName));
      await tempFile.copy(dest.path);
      return dest.path;
    } catch (_) {
      return tempFile.path; // fall back to original if copy fails
    }
  }

  /// Checks if any saved receipt already uses this image file.
  Future<String?> _findDuplicateReceipt(String imagePath) async {
    final db = ref.read(dbProvider);
    final all = await db.getAllReceipts();
    for (final r in all) {
      if (r.imagePath != null && r.imagePath == imagePath) {
        return '${r.date} — ${r.gallons} gal from ${r.sellerName}';
      }
    }
    return null;
  }

  /// Persist the chosen VIN so the scanner remembers it next time.
  Future<void> _saveLastVehicleVin(String vin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastVehicleVin, vin);
  }

  /// Selects the vehicle to use, defaulting to:
  ///   1. Whatever was passed as a route argument (handled in didChangeDependencies)
  ///   2. The last vehicle the user scanned for (from SharedPreferences)
  ///   3. The only vehicle if there's just one
  /// Called once the vehicle list loads.
  void _maybeAutoSelectVehicle(List<Vehicle> vehicles) {
    if (_vehicleAutoSelected || _vehicle != null || vehicles.isEmpty) return;
    _vehicleAutoSelected = true;

    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final lastVin = prefs.getString(_kLastVehicleVin);
      Vehicle? match;
      if (lastVin != null) {
        try {
          match = vehicles.firstWhere((v) => v.vin == lastVin);
        } catch (_) {
          // VIN no longer in DB — fall through to single-vehicle default
        }
      }
      match ??= vehicles.length == 1 ? vehicles.first : null;
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _vehicle = match);
        });
      }
    });
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

  /// True only on Android/iOS where ML Kit is available.
  bool get _ocrSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _pickAndScan(ImageSource source) async {
    if (!_ocrSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR scanning requires Android or iOS. Enter receipt details manually below.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    await _runOcr(File(picked.path));
  }

  Future<void> _runOcr(File imageFile) async {
    setState(() => _scanning = true);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final parsed = extractReceiptFields(result.text);

      setState(() {
        _imageFile = imageFile;
        _scanning = false;
        _dateController.text = parsed.date ?? '';
        _gallonsController.text = parsed.gallons ?? '';
        _sellerController.text = parsed.seller ?? '';
        _streetController.text = parsed.street ?? '';
        _cityController.text = parsed.city ?? '';
        _stateController.text = parsed.state ?? 'MO';
        _zipController.text = parsed.zip ?? '';
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (_vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a vehicle before saving')),
      );
      return;
    }
    if (_gallonsController.text.trim().isEmpty ||
        _sellerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gallons and seller name are required')),
      );
      return;
    }

    setState(() => _saving = true);

    // ── Duplicate image check ────────────────────────────────────────────────
    if (_imageFile != null) {
      final duplicate = await _findDuplicateReceipt(_imageFile!.path);
      if (duplicate != null && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Receipt already saved'),
            content: Text(
              'This image was already used for:\n\n$duplicate\n\n'
              'Save again anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _saving = false);
          return;
        }
      }
    }

    // ── Copy image to permanent storage ──────────────────────────────────────
    String? permanentImagePath;
    if (_imageFile != null) {
      permanentImagePath =
          await _copyImageToPermanentStorage(_imageFile!);
    }

    final gallons =
        double.tryParse(_gallonsController.text.trim()) ?? 0.0;
    final receipt = FuelReceipt(
      vehicleId: _vehicle!.vin,
      fuelType: _vehicle!.fuelType,
      gallons: gallons.toStringAsFixed(3),
      date: _dateController.text.trim(),
      sellerName: _sellerController.text.trim(),
      sellerStreet: _streetController.text.trim(),
      sellerCity: _cityController.text.trim(),
      sellerState: _stateController.text.trim(),
      sellerZip: _zipController.text.trim(),
      imagePath: permanentImagePath,
    );

    await ref.read(receiptProvider(_vehicle!.vin).notifier).add(receipt);
    ref.invalidate(refundSummaryProvider);
    await _saveLastVehicleVin(_vehicle!.vin);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Saved — ${receipt.gallons} gal · \$${receipt.refundAmount.toStringAsFixed(2)} refund value'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleProvider);
    vehiclesAsync.whenData(_maybeAutoSelectVehicle);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Desktop notice — OCR requires Android/iOS
            if (!_ocrSupported)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.col.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: context.col.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: context.col.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OCR scanning works on Android & iOS only. '
                        'Fill in the fields below manually.',
                        style: TextStyle(fontSize: 12, color: context.col.onSurface),
                      ),
                    ),
                  ],
                ),
              ),

            // Vehicle selector — always visible so user can change it
            vehiclesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (vehicles) => DropdownButtonFormField<Vehicle>(
                decoration: const InputDecoration(labelText: 'Vehicle'),
                value: _vehicle != null && vehicles.any((v) => v.vin == _vehicle!.vin)
                    ? vehicles.firstWhere((v) => v.vin == _vehicle!.vin)
                    : null,
                items: vehicles
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text('${v.year} ${v.makeModel} (${v.fuelType.displayName})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _vehicle = v);
                  if (v != null) _saveLastVehicleVin(v.vin);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Scanning tip
            Builder(builder: (context) {
              final primary = Theme.of(context).colorScheme.primary;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For best results, use a flat, unfolded receipt on a '
                        'contrasting surface. Creases and wrinkles are the '
                        'number one cause of missed fields.',
                        style: TextStyle(fontSize: 12, color: primary),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Scan buttons — same height, Browse is primary action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Browse'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _scanning
                        ? null
                        : () => _pickAndScan(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _scanning
                        ? null
                        : () => _pickAndScan(ImageSource.camera),
                  ),
                ),
              ],
            ),

            if (_scanning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('Reading receipt...',
                          style: TextStyle(color: context.col.mutedText)),
                    ],
                  ),
                ),
              ),

            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/view-image',
                  arguments: _imageFile!.path,
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imageFile!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Parsed fields — all editable
            _EditableField(label: 'Date (MM/DD/YYYY)',
                controller: _dateController),
            const SizedBox(height: 12),
            _EditableField(
                label: 'Gallons',
                controller: _gallonsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            SellerAutocomplete(
              controller: _sellerController,
              knownSellers: _knownSellers,
            ),
            const SizedBox(height: 12),
            _EditableField(
                label: 'Street Address', controller: _streetController),
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
                  child: _EditableField(
                      label: 'State', controller: _stateController),
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

            // Refund preview
            if (_gallonsController.text.isNotEmpty)
              _RefundPreview(gallonsText: _gallonsController.text),

            const SizedBox(height: 16),

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
            const SizedBox(height: 8),
            Text(
              'Verify all fields before saving. Tap any field to edit.',
              style: TextStyle(fontSize: 12, color: context.col.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _EditableField({
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

class _RefundPreview extends StatelessWidget {
  final String gallonsText;
  const _RefundPreview({required this.gallonsText});

  @override
  Widget build(BuildContext context) {
    final gallons = double.tryParse(gallonsText) ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.col.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.col.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Refund value:', style: TextStyle(fontSize: 13)),
          Text(
            '\$${(gallons * 0.125).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.col.gold,
            ),
          ),
        ],
      ),
    );
  }
}
