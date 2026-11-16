import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartkasir_app/models/karyawan.dart';
import 'package:smartkasir_app/pages/form_karyawan_page.dart';
import 'package:smartkasir_app/pages/profil_toko_page.dart';
import 'package:smartkasir_app/pages/main_navigation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi SQLite FFI untuk unit testing di environment desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('UJI MODUL 12: MODEL KARYAWAN (Tahap 4.1)', () {
    test('1. Serialisasi toMap() dan Deserialisasi fromMap() model Karyawan', () {
      const karyawan = Karyawan(
        id: 1,
        namaKaryawan: 'Ahmad Kasir',
        pin: '123456',
        peran: 'Kasir',
      );

      final map = karyawan.toMap();
      expect(map['id'], 1);
      expect(map['nama_karyawan'], 'Ahmad Kasir');
      expect(map['pin'], '123456');
      expect(map['peran'], 'Kasir');

      final deserialized = Karyawan.fromMap(map);
      expect(deserialized.id, 1);
      expect(deserialized.namaKaryawan, 'Ahmad Kasir');
      expect(deserialized.pin, '123456');
      expect(deserialized.peran, 'Kasir');
    });
  });

  group('UJI MODUL 12: DATABASE HELPER MULTI-TABEL CRUD (Tahap 4.2)', () {
    test('2. Operasi CRUD Karyawan pada SQLite database', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE karyawan (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nama_karyawan TEXT NOT NULL,
              pin TEXT NOT NULL,
              peran TEXT NOT NULL
            )
          ''');
          await db.rawInsert('''
            INSERT INTO karyawan (nama_karyawan, pin, peran)
            VALUES ('Ahmad Kasir', '123456', 'Kasir')
          ''');
          await db.rawInsert('''
            INSERT INTO karyawan (nama_karyawan, pin, peran)
            VALUES ('Siti Supervisor', '888888', 'Supervisor')
          ''');
        },
      );

      // Cek read initial data
      var list = await db.query('karyawan');
      expect(list.length, 2);

      // Cek Insert Karyawan baru (Create)
      final newId = await db.insert('karyawan', {
        'nama_karyawan': 'Rahmat Hidayat',
        'pin': '555555',
        'peran': 'Kasir',
      });
      expect(newId, 3);

      // Cek Update Karyawan (Update)
      await db.update(
        'karyawan',
        {'nama_karyawan': 'Rahmat Hidayat Update', 'pin': '555555', 'peran': 'Supervisor'},
        where: 'id = ?',
        whereArgs: [newId],
      );

      final updated = await db.query('karyawan', where: 'id = ?', whereArgs: [newId]);
      expect(updated.first['nama_karyawan'], 'Rahmat Hidayat Update');
      expect(updated.first['peran'], 'Supervisor');

      // Cek Delete Karyawan (Delete)
      await db.delete('karyawan', where: 'id = ?', whereArgs: [newId]);
      final afterDelete = await db.query('karyawan', where: 'id = ?', whereArgs: [newId]);
      expect(afterDelete.isEmpty, isTrue);

      await db.close();
    });
  });

  group('UJI MODUL 12: FORM DWIFUNGSI KARYAWAN & TANTANGAN 1 & 2', () {
    testWidgets('3. Validasi Form Karyawan (Nama min 3 karakter, PIN 6 digit, peran Supervisor)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: FormKaryawanPage(),
        ),
      );
      await tester.pump();

      // Cek elemen antarmuka form
      expect(find.text('Tambah Staf Kasir Baru'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Nama & PIN
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // 1. Verifikasi opsi peran memuat 'Supervisor' (Tantangan 1)
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Supervisor'), findsWidgets);
      expect(find.text('Kasir'), findsWidgets);
      expect(find.text('Admin'), findsWidgets);
      expect(find.text('Manajer'), findsWidgets);

      // Tutup menu dropdown dengan tap salah satu item
      await tester.tap(find.text('Supervisor').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 2. Coba simpan form kosong -> Harus memicu validasi
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Nama karyawan wajib diisi!'), findsOneWidget);
      expect(find.text('PIN kasir wajib diisi!'), findsOneWidget);

      // 3. Masukkan nama < 3 karakter & PIN bukan 6 digit
      await tester.enterText(find.byType(TextFormField).first, 'Ab');
      await tester.enterText(find.byType(TextFormField).last, '1234'); // 4 digit ditolak di Tantangan 2
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Nama karyawan minimal 3 karakter!'), findsOneWidget);
      expect(find.text('PIN kasir harus tepat 6 digit angka!'), findsOneWidget);

      // 4. Masukkan nama valid & PIN tepat 6 digit (Tantangan 2)
      await tester.enterText(find.byType(TextFormField).first, 'Rahmat Hidayat');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.pump();

      // Form validation check:
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isTrue);
    });
  });

  group('UJI MODUL 12: PROFIL TOKO & SHAREDPREFERENCES & TANTANGAN 3', () {
    testWidgets('4. Pengaturan profil toko dan penyimpanan Instagram (ig_toko)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'nama_toko': 'SmartKasir Poliban',
        'alamat_toko': 'Jl. Brigjend H. Hasan Basry, Banjarmasin',
        'no_wa': '081234567890',
        'ig_toko': '@smartkasir_poliban',
        'footer_struk': 'Terima Kasih Atas Kunjungan Anda!',
        'active_cashier_name': 'Ahmad Kasir',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilTokoPage(),
        ),
      );
      await tester.pump();

      // Pastikan data termuat dengan benar
      expect(find.text('SmartKasir Poliban'), findsOneWidget);
      expect(find.text('Jl. Brigjend H. Hasan Basry, Banjarmasin'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('@smartkasir_poliban'), findsOneWidget);
      expect(find.text('Ahmad Kasir'), findsOneWidget);

      // Ubah data profil toko termasuk ig_toko
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(5)); // nama, alamat, wa, ig, footer

      // Edit nama toko
      await tester.enterText(fields.at(0), 'Warung Berkah Digital');
      // Edit instagram toko
      await tester.enterText(fields.at(3), '@warungberkah.id');

      // Scroll ke tombol simpan dan tap
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nama_toko'), 'Warung Berkah Digital');
      expect(prefs.getString('ig_toko'), '@warungberkah.id');
    });
  });

  group('UJI MODUL 12: MAIN NAVIGATION PAGE (Tahap 4.6)', () {
    testWidgets('5. Tab navigasi bawah memiliki 4 menu dan tab Toko membuka ProfilTokoPage', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'active_cashier_name': 'Ahmad Kasir',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationPage(),
        ),
      );
      await tester.pump();

      // Cek 4 menu navigasi
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Kasir'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Toko'), findsOneWidget);

      // Ketuk Tab Toko (Indeks 3)
      await tester.tap(find.byIcon(Icons.store_outlined));
      await tester.pump();

      // Pastikan Halaman Profil & Pengaturan Toko tampil
      expect(find.text('Profil & Pengaturan Toko'), findsOneWidget);
      expect(find.text('IDENTITAS USAHA & STRUK KASIR'), findsOneWidget);
    });
  });
}
