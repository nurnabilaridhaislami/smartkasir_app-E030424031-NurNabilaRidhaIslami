// Mengimpor pustaka dasar Flutter, SQLite, dan path
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Mengimpor model data Produk, Karyawan, dan Pelanggan
import '../models/produk.dart';
import '../models/karyawan.dart';
import '../models/pelanggan.dart';

// Kelas Pengelola Basis Data Lokal SQLite (Pola Desain Singleton)
class DatabaseHelper {
  // Instansiasi tunggal statis
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter pembuka koneksi database aktif
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartkasir.db');
    return _database!;
  }

  // Inisialisasi berkas basis data SQLite (Versi 3: Tambah Tabel Pelanggan)
  Future<Database> _initDB(String filePath) async {
    Database db;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      db = await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _createDB,
          onUpgrade: _onUpgradeDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      db = await openDatabase(
        path,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _onUpgradeDB,
      );
    }

    // Auto-Recovery: Jika tabel produk kosong, pulihkan data bawaan secara otomatis
    await _seedProdukJikaKosong(db);

    return db;
  }

  // Helper pemulihan data produk otomatis jika tabel masih kosong
  Future<void> _seedProdukJikaKosong(Database db) async {
    try {
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM produk'),
          ) ??
          0;
      if (count == 0) {
        for (final produk in produkAwalSQLite) {
          await db.insert(
            'produk',
            produk.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (_) {}
  }

  // DDL: Pembuatan Tabel Basis Data (Versi 3 Multi-Table)
  Future _createDB(Database db, int version) async {
    // 1. Pembuatan Tabel Produk
    await db.execute('''
      CREATE TABLE produk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_produk TEXT UNIQUE,
        nama_produk TEXT NOT NULL,
        kategori TEXT NOT NULL,
        harga_beli REAL NOT NULL,
        harga_jual REAL NOT NULL,
        stok INTEGER NOT NULL,
        gambar_path TEXT,
        diskon_persen INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // 2. Pembuatan Tabel Karyawan
    await db.execute('''
      CREATE TABLE karyawan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_karyawan TEXT NOT NULL,
        pin TEXT NOT NULL,
        peran TEXT NOT NULL
      )
    ''');

    // 3. Pembuatan Tabel Pelanggan (Modul 13 CRM & GPS LBS)
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

    // 4. Seeding Data Awal Produk (Modul M11)
    for (final produk in produkAwalSQLite) {
      await db.insert(
        'produk',
        produk.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 5. Seeding Data Awal Karyawan (Modul M12)
    await db.rawInsert('''
      INSERT INTO karyawan (nama_karyawan, pin, peran)
      VALUES ('Ahmad Kasir', '1234', 'Kasir')
    ''');
    await db.rawInsert('''
      INSERT INTO karyawan (nama_karyawan, pin, peran)
      VALUES ('Siti Supervisor', '8888', 'Manajer')
    ''');

    // 6. Seeding Data Awal Pelanggan (Modul M13)
    await db.rawInsert('''
      INSERT INTO pelanggan (kode_pelanggan, nama_pelanggan, nomor_wa, alamat, latitude, longitude, created_at)
      VALUES ('CUST-001', 'Warung Bu Siti', '081234567891', 'Jl. Kayu Tangi 1 No. 12', -3.298610, 114.588230, '2025-01-01T08:00:00Z')
    ''');
    await db.rawInsert('''
      INSERT INTO pelanggan (kode_pelanggan, nama_pelanggan, nomor_wa, alamat, latitude, longitude, created_at)
      VALUES ('CUST-002', 'Budi Santoso', '085712345678', 'Jl. Sultan Adam Komp. H. Iyus', -3.305120, 114.601450, '2025-01-02T09:00:00Z')
    ''');
  }

  // DDL: Migrasi Skema jika versi basis data ditingkatkan
  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Membuat tabel karyawan untuk database pengguna yang sudah ada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS karyawan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama_karyawan TEXT NOT NULL,
          pin TEXT NOT NULL,
          peran TEXT NOT NULL
        )
      ''');
      // Memasukkan staf awal jika tabel baru dibuat
      await db.rawInsert('''
        INSERT INTO karyawan (nama_karyawan, pin, peran)
        VALUES ('Ahmad Kasir', '1234', 'Kasir')
      ''');
    }

    if (oldVersion < 3) {
      // Membuat tabel pelanggan untuk migrasi ke versi 3
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pelanggan (
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

      // Seeding pelanggan bawaan jika belum ada
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pelanggan'),
          ) ??
          0;
      if (count == 0) {
        await db.rawInsert('''
          INSERT INTO pelanggan (kode_pelanggan, nama_pelanggan, nomor_wa, alamat, latitude, longitude, created_at)
          VALUES ('CUST-001', 'Warung Bu Siti', '081234567891', 'Jl. Kayu Tangi 1 No. 12', -3.298610, 114.588230, '2025-01-01T08:00:00Z')
        ''');
        await db.rawInsert('''
          INSERT INTO pelanggan (kode_pelanggan, nama_pelanggan, nomor_wa, alamat, latitude, longitude, created_at)
          VALUES ('CUST-002', 'Budi Santoso', '085712345678', 'Jl. Sultan Adam Komp. H. Iyus', -3.305120, 114.601450, '2025-01-02T09:00:00Z')
        ''');
      }
    }
  }

  // ==========================================
  // METODE CRUD: TABEL PELANGGAN (MODUL M13)
  // ==========================================

  // 1. CREATE: Menyimpan Pelanggan Baru
  Future<int> insertPelanggan(Pelanggan pelanggan) async {
    final db = await instance.database;
    return await db.insert(
      'pelanggan',
      pelanggan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 2. READ: Mengambil Seluruh Pelanggan
  Future<List<Pelanggan>> getAllPelanggan() async {
    final db = await instance.database;
    final result = await db.query('pelanggan', orderBy: 'id DESC');
    return result.map((json) => Pelanggan.fromMap(json)).toList();
  }

  // 3. READ: Mencari Pelanggan Berdasarkan Kata Kunci
  Future<List<Pelanggan>> searchPelanggan(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'pelanggan',
      where: 'nama_pelanggan LIKE ? OR kode_pelanggan LIKE ? OR alamat LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'id DESC',
    );
    return result.map((json) => Pelanggan.fromMap(json)).toList();
  }

  // 4. UPDATE: Memperbarui Data Pelanggan
  Future<int> updatePelanggan(Pelanggan pelanggan) async {
    final db = await instance.database;
    return await db.update(
      'pelanggan',
      pelanggan.toMap(),
      where: 'id = ?',
      whereArgs: [pelanggan.id],
    );
  }

  // 5. DELETE: Menghapus Pelanggan Berdasarkan ID
  Future<int> deletePelanggan(int id) async {
    final db = await instance.database;
    return await db.delete(
      'pelanggan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 6. COUNT: Menghitung Total Pelanggan Terdaftar
  Future<int> countPelanggan() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM pelanggan');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==========================================
  // METODE CRUD: TABEL KARYAWAN (MODUL M12)
  // ==========================================

  // 1. CREATE: Menyimpan Karyawan Baru
  Future<int> insertKaryawan(Karyawan karyawan) async {
    final db = await instance.database;
    return await db.insert('karyawan', karyawan.toMap());
  }

  // 2. READ: Mengambil Seluruh Karyawan
  Future<List<Karyawan>> getAllKaryawan() async {
    final db = await instance.database;
    final result = await db.query('karyawan', orderBy: 'id ASC');
    return result.map((json) => Karyawan.fromMap(json)).toList();
  }

  // 3. UPDATE: Memperbarui Data Karyawan
  Future<int> updateKaryawan(Karyawan karyawan) async {
    final db = await instance.database;
    return await db.update(
      'karyawan',
      karyawan.toMap(),
      where: 'id = ?',
      whereArgs: [karyawan.id],
    );
  }

  // 4. DELETE: Menghapus Karyawan Berdasarkan ID
  Future<int> deleteKaryawan(int id) async {
    final db = await instance.database;
    return await db.delete(
      'karyawan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // METODE CRUD: TABEL PRODUK (DARI MINGGU 11)
  // ==========================================

  // Pemulihan data produk bawaan SmartKasir
  Future<void> restoreDataProduk() async {
    final db = await instance.database;
    for (final produk in produkAwalSQLite) {
      await db.insert(
        'produk',
        produk.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> insertProduk(Produk produk) async {
    final db = await instance.database;
    return await db.insert(
      'produk',
      produk.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Produk>> getAllProduk() async {
    final db = await instance.database;
    final result = await db.query('produk', orderBy: 'harga_jual ASC');
    return result.map((json) => Produk.fromMap(json)).toList();
  }

  Future<List<Produk>> getProdukByKategori(String kategori) async {
    final db = await instance.database;
    if (kategori == 'Semua') return await getAllProduk();
    final result = await db.query('produk', where: 'kategori = ?', whereArgs: [kategori], orderBy: 'harga_jual ASC');
    return result.map((json) => Produk.fromMap(json)).toList();
  }

  Future<List<Produk>> searchProduk(String keyword) async {
    final db = await instance.database;
    final result = await db.query('produk', where: 'nama_produk LIKE ?', whereArgs: ['%$keyword%'], orderBy: 'harga_jual ASC');
    return result.map((json) => Produk.fromMap(json)).toList();
  }

  Future<int> updateProduk(Produk produk) async {
    final db = await instance.database;
    return await db.update('produk', produk.toMap(), where: 'id = ?', whereArgs: [produk.id]);
  }

  Future<int> deleteProduk(int id) async {
    final db = await instance.database;
    return await db.delete('produk', where: 'id = ?', whereArgs: [id]);
  }
}
