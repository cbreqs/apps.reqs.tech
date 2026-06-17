import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database.dart';
import '../models/vehicle.dart';
import '../models/fuel_receipt.dart';
import '../models/profile.dart';

// ── Theme mode ────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'light':  state = ThemeMode.light;  break;
      case 'dark':   state = ThemeMode.dark;   break;
      default:       state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

// ── Constants ─────────────────────────────────────────────────────────────────

/// VIN used for the auto-created placeholder vehicle on first launch.
/// Check against this to decide whether setup is still incomplete.
const kDefaultVehicleVin = 'MY-VEHICLE-001';

// ── Database ──────────────────────────────────────────────────────────────────

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

// ── Profile ───────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<Profile> {
  ProfileNotifier() : super(const Profile()) {
    _load();
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _sensitiveKeys = [
    'ssn', 'spouseSsn', 'fein', 'bankRoutingNumber', 'bankAccountNumber',
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile');

    Profile profile = raw != null
        ? Profile.fromPrefsJson(jsonDecode(raw) as Map<String, dynamic>)
        : const Profile();

    // Migration: if old plaintext blob still contains sensitive keys, move them
    // to secure storage and strip them from prefs.
    if (raw != null) {
      final oldJson = jsonDecode(raw) as Map<String, dynamic>;
      final legacyKeys = _sensitiveKeys.where((k) => oldJson.containsKey(k));
      if (legacyKeys.isNotEmpty) {
        for (final k in legacyKeys) {
          final val = oldJson[k] as String?;
          if (val != null && val.isNotEmpty) {
            await _secureStorage.write(key: k, value: val);
          }
          oldJson.remove(k);
        }
        await prefs.setString('profile', jsonEncode(oldJson));
      }
    }

    // Read sensitive fields from secure storage and merge.
    final secure = <String, String>{};
    for (final k in _sensitiveKeys) {
      final val = await _secureStorage.read(key: k);
      if (val != null) secure[k] = val;
    }

    state = profile.withSecureFields(secure);
  }

  Future<void> save(Profile profile) async {
    state = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(profile.toPrefsJson()));
    for (final entry in profile.toSecureJson().entries) {
      await _secureStorage.write(key: entry.key, value: entry.value);
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, Profile>(
  (ref) => ProfileNotifier(),
);

// ── Vehicles ──────────────────────────────────────────────────────────────────

class VehicleNotifier extends StateNotifier<AsyncValue<List<Vehicle>>> {
  final AppDatabase _db;

  VehicleNotifier(this._db) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.getVehicles());

    // First launch: seed a placeholder so the scanner works immediately.
    // The home screen shows a "Getting Started" guide until this is replaced.
    if (state.value?.isEmpty == true) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('default_vehicle_created') != true) {
        await _db.saveVehicle(Vehicle(
          vin: kDefaultVehicleVin,
          makeModel: 'My Vehicle',
          year: DateTime.now().year.toString(),
          underWeightLimit: true,
          fuelType: FuelType.gasoline,
        ));
        await prefs.setBool('default_vehicle_created', true);
        state = await AsyncValue.guard(() => _db.getVehicles());
      }
    }
  }

  Future<void> add(Vehicle vehicle) async {
    await _db.saveVehicle(vehicle);
    await load();
  }

  Future<void> update(Vehicle vehicle) async {
    await _db.saveVehicle(vehicle);
    await load();
  }

  Future<void> delete(String vin) async {
    await _db.deleteVehicle(vin);
    await load();
  }

  Future<void> moveReceipts(String fromVin, String toVin) async {
    await _db.moveReceipts(fromVin, toVin);
    await load();
  }

  Future<void> moveReceiptsAndDelete(String fromVin, String toVin) async {
    await _db.moveReceiptsAndDeleteVehicle(fromVin, toVin);
    await load();
  }
}

final vehicleProvider =
    StateNotifierProvider<VehicleNotifier, AsyncValue<List<Vehicle>>>(
  (ref) => VehicleNotifier(ref.watch(dbProvider)),
);

// ── Receipts ──────────────────────────────────────────────────────────────────

class ReceiptNotifier extends StateNotifier<AsyncValue<List<FuelReceipt>>> {
  final AppDatabase _db;
  final String vehicleId;

  ReceiptNotifier(this._db, this.vehicleId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => _db.getReceiptsForVehicle(vehicleId));
  }

  Future<void> add(FuelReceipt receipt) async {
    await _db.saveReceipt(receipt);
    await load();
  }

  Future<void> update(FuelReceipt receipt) async {
    await _db.updateReceipt(receipt);
    await load();
  }

  Future<void> delete(int id) async {
    await _db.deleteReceipt(id);
    await load();
  }

  Future<void> moveReceipt(int receiptId, String toVin) async {
    await _db.moveReceipt(receiptId, toVin);
    await load();
  }
}

final receiptProvider = StateNotifierProvider.family<ReceiptNotifier,
    AsyncValue<List<FuelReceipt>>, String>(
  (ref, vehicleId) =>
      ReceiptNotifier(ref.watch(dbProvider), vehicleId),
);

// ── Refund summary ────────────────────────────────────────────────────────────

/// Live refund estimate across all eligible vehicles.
/// Rate: $0.125/gallon (Missouri motor fuel tax increase, Section 142.822)
final refundSummaryProvider = FutureProvider<RefundSummary>((ref) async {
  final db = ref.watch(dbProvider);
  final gallons = await db.totalEligibleGallons();
  return RefundSummary(
    totalEligibleGallons: gallons,
    estimatedRefund: gallons * 0.125,
    ratePerGallon: 0.125,
  );
});

class RefundSummary {
  final double totalEligibleGallons;
  final double estimatedRefund;
  final double ratePerGallon;

  const RefundSummary({
    required this.totalEligibleGallons,
    required this.estimatedRefund,
    required this.ratePerGallon,
  });
}
