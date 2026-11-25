import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../helpers/database_helper.dart';
import '../models/pelanggan.dart';

// Halaman Formulir Pendaftaran dan Edit Pelanggan (Dual-Mode)
class FormPelangganPage extends StatefulWidget {
  final Pelanggan? pelanggan;

  const FormPelangganPage({super.key, this.pelanggan});

  @override
  State<FormPelangganPage> createState() => _FormPelangganPageState();
}

class _FormPelangganPageState extends State<FormPelangganPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _kodeController;
  late TextEditingController _namaController;
  late TextEditingController _nomorWaController;
  late TextEditingController _alamatController;

  double? _latitude;
  double? _longitude;
  bool _sedangAmbilLokasi = false;
  bool _sedangMenyimpan = false;

  bool get _isEditMode => widget.pelanggan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pelanggan;
    final autoKode = 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _kodeController = TextEditingController(text: p?.kodePelanggan ?? autoKode);
    _namaController = TextEditingController(text: p?.namaPelanggan ?? '');
    _nomorWaController = TextEditingController(text: p?.nomorWa ?? '');
    _alamatController = TextEditingController(text: p?.alamat ?? '');
    _latitude = p?.latitude;
    _longitude = p?.longitude;
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _nomorWaController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  // Mengambil koordinat GPS presisi menggunakan package geolocator
  Future<void> _ambilKoordinatGps() async {
    setState(() => _sedangAmbilLokasi = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layanan lokasi GPS belum aktif. Harap aktifkan GPS ponsel Anda.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin akses lokasi ditolak.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak permanen. Silakan aktifkan melalui Pengaturan Aplikasi.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koordinat GPS berhasil ditandai: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil titik lokasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sedangAmbilLokasi = false);
      }
    }
  }

  // Menyimpan data pelanggan ke basis data SQLite
  Future<void> _simpanPelanggan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMenyimpan = true);

    try {
      final pelangganData = Pelanggan(
        id: widget.pelanggan?.id,
        kodePelanggan: _kodeController.text.trim(),
        namaPelanggan: _namaController.text.trim(),
        nomorWa: _nomorWaController.text.trim(),
        alamat: _alamatController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        createdAt: widget.pelanggan?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (_isEditMode) {
        await DatabaseHelper.instance.updatePelanggan(pelangganData);
      } else {
        await DatabaseHelper.instance.insertPelanggan(pelangganData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Data pelanggan berhasil diperbarui!' : 'Pelanggan baru berhasil ditambahkan!'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data pelanggan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sedangMenyimpan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Data Pelanggan' : 'Daftar Pelanggan Baru',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. KODE PELANGGAN
              TextFormField(
                controller: _kodeController,
                readOnly: _isEditMode,
                decoration: InputDecoration(
                  labelText: 'Kode Pelanggan (ID)',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: _isEditMode ? Colors.grey.shade200 : Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Kode pelanggan wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 2. NAMA PELANGGAN
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap Pelanggan / Toko',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama pelanggan wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 3. NOMOR WHATSAPP
              TextFormField(
                controller: _nomorWaController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor WhatsApp Pelanggan',
                  hintText: 'Contoh: 081234567890',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nomor WhatsApp wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 4. ALAMAT LENGKAP
              TextFormField(
                controller: _alamatController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat Pengiriman / Lokasi',
                  prefixIcon: const Icon(Icons.home),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Alamat wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 5. KARTU PEREKAMAN KOORDINAT LOKASI GPS (LBS)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Titik Koordinat GPS Pelanggan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _latitude != null && _longitude != null
                          ? 'Latitude: ${_latitude!.toStringAsFixed(6)}\nLongitude: ${_longitude!.toStringAsFixed(6)}'
                          : 'Lokasi GPS belum ditandai. Tekan tombol di bawah untuk merekam posisi saat ini.',
                      style: TextStyle(
                        color: _latitude != null ? Colors.black87 : Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: _latitude != null ? 'monospace' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sedangAmbilLokasi ? null : _ambilKoordinatGps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade50,
                          foregroundColor: Colors.teal.shade800,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                        ),
                        icon: _sedangAmbilLokasi
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(_sedangAmbilLokasi ? 'Mendapatkan Sinyal GPS...' : 'Ambil Titik Koordinat Sekarang'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TOMBOL SIMPAN
              ElevatedButton.icon(
                onPressed: _sedangMenyimpan ? null : _simpanPelanggan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _sedangMenyimpan
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _sedangMenyimpan ? 'Menyimpan...' : (_isEditMode ? 'Perbarui Pelanggan' : 'Simpan Pelanggan Baru'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
