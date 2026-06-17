/// Fuel types valid for Form 4923-H.
/// - Gasoline and ClearDiesel: available to all filers
/// - DyedDiesel: government entities and school districts ONLY
enum FuelType {
  gasoline,
  clearDiesel,
  dyedDiesel;

  String get displayName {
    switch (this) {
      case FuelType.gasoline:
        return 'Gasoline';
      case FuelType.clearDiesel:
        return 'Clear Diesel';
      case FuelType.dyedDiesel:
        return 'Dyed Diesel';
    }
  }
}

/// A persisted fuel receipt linked to a specific vehicle.
/// One fuel type per vehicle — enforced at the repository level.
/// Gallons stored as a string to preserve exact 3-decimal precision.
class FuelReceipt {
  final int? id;
  final String vehicleId; // VIN
  final FuelType fuelType;

  /// Exact gallons as displayed on the receipt, to 3 decimal places (e.g. "12.345")
  final String gallons;

  /// Date of purchase — MM/DD/YYYY
  final String date;

  final String sellerName;
  final String sellerStreet;
  final String sellerCity;
  final String sellerState;
  final String sellerZip;

  /// Path to the scanned receipt image stored in app-private storage
  final String? imagePath;

  /// OCR confidence score 0.0–1.0; null for manually entered receipts
  final double? ocrConfidence;

  const FuelReceipt({
    this.id,
    required this.vehicleId,
    required this.fuelType,
    required this.gallons,
    required this.date,
    required this.sellerName,
    this.sellerStreet = '',
    this.sellerCity = '',
    this.sellerState = 'MO',
    this.sellerZip = '',
    this.imagePath,
    this.ocrConfidence,
  });

  /// Gallons as a double for calculation purposes.
  /// Returns 0.0 if the stored string is not parseable.
  double get gallonsValue => double.tryParse(gallons) ?? 0.0;

  /// Refund amount for this receipt: gallons × $0.125
  double get refundAmount => gallonsValue * 0.125;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleId': vehicleId,
        'fuelType': fuelType.name,
        'gallons': gallons,
        'date': date,
        'sellerName': sellerName,
        'sellerStreet': sellerStreet,
        'sellerCity': sellerCity,
        'sellerState': sellerState,
        'sellerZip': sellerZip,
        'imagePath': imagePath,
        'ocrConfidence': ocrConfidence,
      };

  factory FuelReceipt.fromMap(Map<String, dynamic> map) => FuelReceipt(
        id: map['id'] as int?,
        vehicleId: map['vehicleId'] as String,
        fuelType: FuelType.values.byName(map['fuelType'] as String),
        gallons: map['gallons'] as String,
        date: map['date'] as String,
        sellerName: map['sellerName'] as String,
        sellerStreet: map['sellerStreet'] as String? ?? '',
        sellerCity: map['sellerCity'] as String? ?? '',
        sellerState: map['sellerState'] as String? ?? 'MO',
        sellerZip: map['sellerZip'] as String? ?? '',
        imagePath: map['imagePath'] as String?,
        ocrConfidence: map['ocrConfidence'] as double?,
      );

  FuelReceipt copyWith({
    int? id,
    String? vehicleId,
    FuelType? fuelType,
    String? gallons,
    String? date,
    String? sellerName,
    String? sellerStreet,
    String? sellerCity,
    String? sellerState,
    String? sellerZip,
    String? imagePath,
    double? ocrConfidence,
  }) =>
      FuelReceipt(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        fuelType: fuelType ?? this.fuelType,
        gallons: gallons ?? this.gallons,
        date: date ?? this.date,
        sellerName: sellerName ?? this.sellerName,
        sellerStreet: sellerStreet ?? this.sellerStreet,
        sellerCity: sellerCity ?? this.sellerCity,
        sellerState: sellerState ?? this.sellerState,
        sellerZip: sellerZip ?? this.sellerZip,
        imagePath: imagePath ?? this.imagePath,
        ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      );
}
