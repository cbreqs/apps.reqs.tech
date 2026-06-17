import 'dart:convert';
import 'fuel_receipt.dart';

class Vehicle {
  final String vin;
  final String makeModel;
  final String year;

  /// Must be true for vehicle to be eligible for the refund.
  /// Gross weight must be 26,000 lbs or less (per Section 142.822).
  final bool underWeightLimit;

  /// One fuel type per vehicle — gasoline OR clear diesel, never both.
  /// Dyed diesel only valid for government/school district filers.
  final FuelType fuelType;

  const Vehicle({
    required this.vin,
    required this.makeModel,
    required this.year,
    required this.underWeightLimit,
    this.fuelType = FuelType.gasoline,
  });

  bool get isEligible => underWeightLimit;

  // ── JSON (SharedPreferences legacy) ──────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'vin': vin,
        'makeModel': makeModel,
        'year': year,
        'underWeightLimit': underWeightLimit,
        'fuelType': fuelType.name,
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        vin: json['vin'] as String,
        makeModel: json['makeModel'] as String,
        year: json['year'] as String,
        underWeightLimit: json['underWeightLimit'] as bool? ?? true,
        fuelType: json['fuelType'] != null
            ? FuelType.values.byName(json['fuelType'] as String)
            : FuelType.gasoline,
      );

  static String encode(List<Vehicle> vehicles) =>
      json.encode(vehicles.map((v) => v.toJson()).toList());

  static List<Vehicle> decode(String vehicles) =>
      (json.decode(vehicles) as List<dynamic>)
          .map<Vehicle>((v) => Vehicle.fromJson(v as Map<String, dynamic>))
          .toList();

  // ── SQLite ────────────────────────────────────────────────────────────────

  Map<String, dynamic> toDbMap() => {
        'vin': vin,
        'makeModel': makeModel,
        'year': year,
        'underWeightLimit': underWeightLimit ? 1 : 0,
        'fuelType': fuelType.name,
      };

  static Vehicle fromDbMap(Map<String, dynamic> map) => Vehicle(
        vin: map['vin'] as String,
        makeModel: map['makeModel'] as String,
        year: map['year'] as String,
        underWeightLimit: (map['underWeightLimit'] as int) == 1,
        fuelType: FuelType.values.byName(
            map['fuelType'] as String? ?? FuelType.gasoline.name),
      );

  Vehicle copyWith({
    String? vin,
    String? makeModel,
    String? year,
    bool? underWeightLimit,
    FuelType? fuelType,
  }) =>
      Vehicle(
        vin: vin ?? this.vin,
        makeModel: makeModel ?? this.makeModel,
        year: year ?? this.year,
        underWeightLimit: underWeightLimit ?? this.underWeightLimit,
        fuelType: fuelType ?? this.fuelType,
      );
}
