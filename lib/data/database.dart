import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/fuel_receipt.dart';
import '../models/vehicle.dart';

/// SQLite database for persisting vehicles and receipts.
/// Profile sensitive fields are handled separately via flutter_secure_storage.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mogas.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles (
            vin TEXT PRIMARY KEY,
            makeModel TEXT NOT NULL,
            year TEXT NOT NULL,
            underWeightLimit INTEGER NOT NULL DEFAULT 1,
            fuelType TEXT NOT NULL DEFAULT 'gasoline'
          )
        ''');

        await db.execute('''
          CREATE TABLE receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicleId TEXT NOT NULL,
            fuelType TEXT NOT NULL,
            gallons TEXT NOT NULL,
            date TEXT NOT NULL,
            sellerName TEXT NOT NULL,
            sellerStreet TEXT,
            sellerCity TEXT,
            sellerState TEXT,
            sellerZip TEXT,
            imagePath TEXT,
            ocrConfidence REAL,
            FOREIGN KEY (vehicleId) REFERENCES vehicles (vin) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ── Vehicles ──────────────────────────────────────────────────────────────

  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final rows = await db.query('vehicles', orderBy: 'year DESC');
    return rows.map(Vehicle.fromDbMap).toList();
  }

  Future<Vehicle?> getVehicle(String vin) async {
    final db = await database;
    final rows =
        await db.query('vehicles', where: 'vin = ?', whereArgs: [vin]);
    if (rows.isEmpty) return null;
    return Vehicle.fromDbMap(rows.first);
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    final db = await database;
    await db.insert(
      'vehicles',
      vehicle.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteVehicle(String vin) async {
    final db = await database;
    await db.delete('vehicles', where: 'vin = ?', whereArgs: [vin]);
  }

  /// Reassigns all receipts from [fromVin] to [toVin] without deleting [fromVin].
  /// Reassigns a single receipt to a different vehicle.
  Future<void> moveReceipt(int receiptId, String toVin) async {
    final db = await database;
    await db.update(
      'receipts',
      {'vehicleId': toVin},
      where: 'id = ?',
      whereArgs: [receiptId],
    );
  }

  Future<void> moveReceipts(String fromVin, String toVin) async {
    final db = await database;
    await db.update(
      'receipts',
      {'vehicleId': toVin},
      where: 'vehicleId = ?',
      whereArgs: [fromVin],
    );
  }

  /// Reassigns all receipts from [fromVin] to [toVin], then deletes [fromVin].
  Future<void> moveReceiptsAndDeleteVehicle(String fromVin, String toVin) async {
    final db = await database;
    await db.update(
      'receipts',
      {'vehicleId': toVin},
      where: 'vehicleId = ?',
      whereArgs: [fromVin],
    );
    await db.delete('vehicles', where: 'vin = ?', whereArgs: [fromVin]);
  }

  // ── Receipts ──────────────────────────────────────────────────────────────

  Future<List<FuelReceipt>> getReceiptsForVehicle(String vehicleId) async {
    final db = await database;
    final rows = await db.query(
      'receipts',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return rows.map(FuelReceipt.fromMap).toList();
  }

  Future<List<FuelReceipt>> getAllReceipts() async {
    final db = await database;
    final rows = await db.query('receipts', orderBy: 'date DESC');
    return rows.map(FuelReceipt.fromMap).toList();
  }

  Future<int> saveReceipt(FuelReceipt receipt) async {
    final db = await database;
    return db.insert(
      'receipts',
      receipt.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateReceipt(FuelReceipt receipt) async {
    assert(receipt.id != null, 'Cannot update a receipt with no id');
    final db = await database;
    await db.update(
      'receipts',
      receipt.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<void> deleteReceipt(int id) async {
    final db = await database;
    await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  /// All unique seller names across all receipts, sorted alphabetically.
  Future<List<String>> getUniqueSellers() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT sellerName FROM receipts ORDER BY sellerName ASC',
    );
    return rows.map((r) => r['sellerName'] as String).toList();
  }

  /// All unique seller cities across all receipts, sorted alphabetically.
  Future<List<String>> getUniqueCities() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT sellerCity FROM receipts WHERE sellerCity != '' ORDER BY sellerCity ASC",
    );
    return rows.map((r) => r['sellerCity'] as String).toList();
  }

  /// All unique seller ZIP codes across all receipts, sorted.
  Future<List<String>> getUniqueZips() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT sellerZip FROM receipts WHERE sellerZip != '' ORDER BY sellerZip ASC",
    );
    return rows.map((r) => r['sellerZip'] as String).toList();
  }

  /// Total eligible gallons across all eligible vehicles (≤26,000 lbs)
  Future<double> totalEligibleGallons() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT SUM(CAST(r.gallons AS REAL)) as total
      FROM receipts r
      JOIN vehicles v ON r.vehicleId = v.vin
      WHERE v.underWeightLimit = 1
    ''');
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Estimated refund: totalEligibleGallons × $0.125
  Future<double> estimatedRefund() async {
    final gallons = await totalEligibleGallons();
    return gallons * 0.125;
  }
}
