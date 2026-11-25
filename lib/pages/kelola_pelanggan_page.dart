import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../helpers/database_helper.dart';
import '../models/pelanggan.dart';
import 'form_pelanggan_page.dart';

// Halaman Manajemen dan Katalog Data Pelanggan (CRM & LBS)
class KelolaPelangganPage extends StatefulWidget {
  const KelolaPelangganPage({super.key});

  @override
  State<KelolaPelangganPage> createState() => _KelolaPelangganPageState();
}

class _KelolaPelangganPageState extends State<KelolaPelangganPage> {
  final _searchController = TextEditingController();
  List<Pelanggan> _daftarPelanggan = [];
  bool _sedangMemuat = true;

  @override
  void initState() {
    super.initState();
    _muatDaftarPelanggan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Memuat seluruh data pelanggan dari basis data SQLite
  Future<void> _muatDaftarPelanggan() async {
    setState(() => _sedangMemuat = true);
    final data = await DatabaseHelper.instance.getAllPelanggan();
    if (!mounted) return;
    setState(() {
      _daftarPelanggan = data;
      _sedangMemuat = false;
    });
  }

  // Melakukan pencarian pelanggan secara realtime (SQL LIKE)
  Future<void> _cariPelanggan(String keyword) async {
    if (keyword.trim().isEmpty) {
      _muatDaftarPelanggan();
      return;
    }
    final hasil = await DatabaseHelper.instance.searchPelanggan(keyword.trim());
    if (!mounted) return;
    setState(() {
      _daftarPelanggan = hasil;
    });
  }

  // Membuka navigasi rute ke lokasi pelanggan di Google Maps via URL Launcher
  Future<void> _bukaRuteGoogleMaps(double latitude, double longitude, String namaPelanggan) async {
    final urlString = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    final uri = Uri.parse(urlString);

    try {
      final berhasil = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!berhasil && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi Google Maps atau browser.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan membuka peta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Konfirmasi dialog hapus data pelanggan
  void _konfirmasiHapus(Pelanggan p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Pelanggan?'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus pelanggan "${p.namaPelanggan}"? Data tidak dapat dipulihkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deletePelanggan(p.id!);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pelanggan "${p.namaPelanggan}" berhasil dihapus!'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
              _muatDaftarPelanggan();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kelola Data Pelanggan',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // KOTAK PENCARIAN PELANGGAN
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _cariPelanggan,
              decoration: InputDecoration(
                hintText: 'Cari nama, ID pelanggan, atau alamat...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _muatDaftarPelanggan();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
              ),
            ),
          ),

          // DAFTAR PELANGGAN
          Expanded(
            child: _sedangMemuat
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : _daftarPelanggan.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada data pelanggan ditemukan',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _daftarPelanggan.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _daftarPelanggan[index];
                          final initial = item.namaPelanggan.isNotEmpty
                              ? item.namaPelanggan[0].toUpperCase()
                              : '?';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // AVATAR INISIAL
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.teal.shade700,
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // NAMA & KODE PELANGGAN
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.namaPelanggan,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.kodePelanggan,
                                                style: TextStyle(
                                                  color: Colors.teal.shade800,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // NOMOR WHATSAPP & ALAMAT
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.nomorWa,
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.alamat,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // STATUS KOORDINAT GPS
                                  Row(
                                    children: [
                                      Icon(
                                        item.hasLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                                        size: 14,
                                        color: item.hasLocation ? Colors.teal : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.hasLocation
                                            ? 'Koordinat: ${item.coordinateText}'
                                            : 'Lokasi belum ditandai',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.hasLocation ? Colors.teal.shade800 : Colors.grey,
                                          fontStyle: item.hasLocation ? FontStyle.normal : FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 18),

                                  // BARIS TOMBOL AKSI: RUTE, EDIT, HAPUS
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // TOMBOL BUKA RUTE GOOGLE MAPS
                                      if (item.hasLocation)
                                        ElevatedButton.icon(
                                          onPressed: () => _bukaRuteGoogleMaps(
                                            item.latitude!,
                                            item.longitude!,
                                            item.namaPelanggan,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.directions, size: 16),
                                          label: const Text('Rute Peta', style: TextStyle(fontSize: 12)),
                                        ),
                                      const Spacer(),
                                      // TOMBOL EDIT
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.indigo),
                                        tooltip: 'Edit Pelanggan',
                                        onPressed: () async {
                                          final refresh = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FormPelangganPage(pelanggan: item),
                                            ),
                                          );
                                          if (refresh == true) _muatDaftarPelanggan();
                                        },
                                      ),
                                      // TOMBOL HAPUS
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Hapus Pelanggan',
                                        onPressed: () => _konfirmasiHapus(item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormPelangganPage()),
          );
          if (refresh == true) _muatDaftarPelanggan();
        },
        backgroundColor: Colors.teal.shade700,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Tambah Pelanggan',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
