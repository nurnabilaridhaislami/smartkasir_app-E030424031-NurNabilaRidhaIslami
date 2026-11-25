import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartkasir_app/models/pelanggan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi SQLite FFI untuk unit testing di environment desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('UJI MODUL 13: MODEL PELANGGAN (Tahap 4.1)', () {
    test('1. Serialisasi toMap() dan Deserialisasi fromMap() model Pelanggan', () {
      final pelanggan = Pelanggan(
        id: 1,
        kodePelanggan: 'CUST-001',
        namaPelanggan: 'Warung Bu Siti',
        nomorWa: '081234567891',
        alamat: 'Jl. Kayu Tangi 1 No. 12',
        latitude: -3.298610,
        longitude: 114.588230,
        createdAt: '2025-01-01T08:00:00Z',
      );

      final map = pelanggan.toMap();
      expect(map['id'], 1);
      expect(map['kode_pelanggan'], 'CUST-001');
      expect(map['nama_pelanggan'], 'Warung Bu Siti');
      expect(map['nomor_wa'], '081234567891');
      expect(map['alamat'], 'Jl. Kayu Tangi 1 No. 12');
      expect(map['latitude'], -3.298610);
      expect(map['longitude'], 114.588230);

      final deserialized = Pelanggan.fromMap(map);
      expect(deserialized.id, 1);
      expect(deserialized.kodePelanggan, 'CUST-001');
      expect(deserialized.namaPelanggan, 'Warung Bu Siti');
      expect(deserialized.hasLocation, isTrue);
      expect(deserialized.coordinateText, contains('-3.298610'));
    });

    test('2. Helper hasLocation dan coordinateText saat koordinat kosong', () {
      final pelangganTanpaGps = Pelanggan(
        kodePelanggan: 'CUST-002',
        namaPelanggan: 'Toko Baru',
        nomorWa: '081299998888',
        alamat: 'Jl. Belum Ada Lokasi',
      );

      expect(pelangganTanpaGps.hasLocation, isFalse);
      expect(pelangganTanpaGps.coordinateText, 'Belum Ditandai');
    });
  });

  group('UJI MODUL 13: DATABASE HELPER TABEL PELANGGAN (Tahap 4.2)', () {
    test('3. Operasi CRUD Pelanggan pada SQLite in-memory', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE pelanggan (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              kode_pelanggan TEXT UNIQUE NOT NULL,
              nama_pelanggan TEXT NOT NULL,
              nomor_wa TEXT NOT NULL,
              alamat TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              created_at TEXT
            )
          ''');
        },
      );

      // Insert
      final id = await db.insert('pelanggan', {
        'kode_pelanggan': 'CUST-TEST',
        'nama_pelanggan': 'Pelanggan Uji',
        'nomor_wa': '0811223344',
        'alamat': 'Jl. Percobaan No. 1',
        'latitude': -3.310000,
        'longitude': 114.590000,
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(id, isPositive);

      // Query
      final list = await db.query('pelanggan');
      expect(list.length, 1);
      expect(list.first['nama_pelanggan'], 'Pelanggan Uji');

      // Update
      await db.update(
        'pelanggan',
        {'nama_pelanggan': 'Pelanggan Terupdate'},
        where: 'id = ?',
        whereArgs: [id],
      );
      final updatedList = await db.query('pelanggan', where: 'id = ?', whereArgs: [id]);
      expect(updatedList.first['nama_pelanggan'], 'Pelanggan Terupdate');

      // Delete
      await db.delete('pelanggan', where: 'id = ?', whereArgs: [id]);
      final emptyList = await db.query('pelanggan');
      expect(emptyList.isEmpty, isTrue);

      await db.close();
    });
  });
}
