import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const TaniTembakauApp());
}

class TaniTembakauApp extends StatelessWidget {
  const TaniTembakauApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaniTembakau',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const DashboardScreen(),
    );
  }
}

// ==========================================================
// 1. HALAMAN UTAMA (DASHBOARD - GPS & CUACA DINAMIS)
// ==========================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _locationName = "Mendeteksi Lokasi Lahan...";
  double _temperature = 0.0;
  int _humidity = 0;
  String _weatherDescription = "Memuat cuaca...";
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fetchWeatherByGPS();
  }

  Future<void> _fetchWeatherByGPS() async {
    setState(() => _isLoadingWeather = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationName = "GPS Tidak Aktif";
          _weatherDescription = "Nyalakan GPS perangkat Anda";
          _isLoadingWeather = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationName = "Izin Ditolak";
            _weatherDescription = "Berikan izin lokasi untuk cuaca akurat";
            _isLoadingWeather = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      const apiKey = '449c1cbd03c27b710a6ddb8b26cf81a2';
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey&lang=id',
      );

      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationName = data['name'];
          _temperature = (data['main']['temp'] as num).toDouble();
          _humidity = data['main']['humidity'];
          _weatherDescription = data['weather'][0]['description'];
          _isLoadingWeather = false;
        });
      } else {
        setState(() {
          _weatherDescription = "Gagal memuat cuaca";
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationName = "Gagal Deteksi Lokasi";
        _weatherDescription = "Periksa koneksi internet / GPS";
        _isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String recommendation = "Kondisi cuaca baik untuk pertumbuhan tembakau.";
    String weatherDescLower = _weatherDescription.toLowerCase();

    if (weatherDescLower.contains('hujan') ||
        weatherDescLower.contains('badai') ||
        weatherDescLower.contains('gerimis')) {
      recommendation = "Waspadai genangan air di lahan! Pastikan drainase parit berfungsi baik.";
    } else if (_temperature > 32) {
      recommendation =
          "Suhu cukup panas, pastikan kecukupan air irigasi untuk tanaman.";
    } else if (_humidity > 85) {
      recommendation = "Kelembapan udara tinggi, waspadai potensi serangan jamur/penyakit daun.";
    } else if (weatherDescLower.contains('cerah') ||
        weatherDescLower.contains('berawan')) {
      recommendation =
          "Kondisi ideal untuk penjemuran daun atau pemupukan susulan.";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaniTembakau Dashboard'),
        backgroundColor: Colors.green[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green[50],
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Lahan: $_locationName",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                onPressed: _fetchWeatherByGPS,
                                tooltip: "Perbarui Cuaca Lokasi",
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _isLoadingWeather
                              ? const Text("Mendeteksi lokasi & cuaca...")
                              : Text(
                                  "Suhu: ${_temperature.toStringAsFixed(1)}°C | Kelembapan: $_humidity%\nKondisi: $_weatherDescription",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                          const SizedBox(height: 4),
                          Text(
                            recommendation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[900],
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.wb_sunny, size: 40, color: Colors.orange),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Fitur Utama",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  MenuCard(
                    icon: Icons.grass,
                    title: "Panduan Budidaya",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CultivationGuideScreen(),
                        ),
                      );
                    },
                  ),
                  MenuCard(
                    icon: Icons.camera_alt,
                    title: "Deteksi Hama AI",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PestDetectionScreen(),
                        ),
                      );
                    },
                  ),
                  MenuCard(
                    icon: Icons.book,
                    title: "Catatan Keuangan",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FinancialScreen(),
                        ),
                      );
                    },
                  ),
                  MenuCard(
                    icon: Icons.trending_up,
                    title: "Harga Pasar",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MarketPriceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.green[700]),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 2. HALAMAN DETEKSI HAMA AI
// ==========================================================
class PestDetectionScreen extends StatefulWidget {
  const PestDetectionScreen({super.key});

  @override
  State<PestDetectionScreen> createState() => _PestDetectionScreenState();
}

class _PestDetectionScreenState extends State<PestDetectionScreen> {
  bool _isAnalyzing = false;
  File? _imageFile;
  Map<String, dynamic>? _scanResult;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isAnalyzing = true;
          _scanResult = null;
        });

        const promptText = '''
          Anda adalah pakar patologi tanaman tembakau profesional. Analisis foto daun yang diunggah dengan cermat.
          Jika foto tersebut bukan daun atau tanaman tembakau (seperti daun mangga atau objek lain), jelaskan pada bagian pestName bahwa itu bukan tanaman tembakau.
          Berikan respons HANYA dalam format JSON murni tanpa ada pembungkus markdown dengan struktur persis seperti ini:
          {
            "pestName": "Nama Hama / Penyakit / Bukan Tanaman Tembakau",
            "confidence": "95.0%",
            "symptoms": "Deskripsi singkat gejala atau kondisi objek pada foto",
            "solution": "Saran penanganan teknis bagi petani"
          }
        ''';

        final parsedData = await GeminiApiService.analyzePestImage(
          _imageFile!,
          promptText,
        );

        if (!mounted) return;

        setState(() {
          _isAnalyzing = false;
          _scanResult = parsedData;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _scanResult = null;
      });

      final String errorMessage = e.toString().replaceFirst("Exception: ", "");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deteksi Hama AI"),
        backgroundColor: Colors.green[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.green[50],
              elevation: 1,
              child: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Ambil atau pilih foto daun tembakau untuk dianalisis oleh AI secara akurat.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isAnalyzing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "Menghubungkan ke Server AI & Menganalisis Daun...\nMohon tunggu sebentar.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_enhance,
                            size: 60,
                            color: Colors.green[700],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Belum ada foto yang dipilih",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Ambil Foto"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[800],
                      side: BorderSide(color: Colors.green.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Pilih Galeri"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            if (_scanResult != null) ...[
              const Text(
                "Hasil Analisis AI:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _scanResult!["pestName"] ?? "Hama Terdeteksi",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _scanResult!["confidence"] ?? "90%",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      const Text(
                        "Gejala Terdeteksi:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scanResult!["symptoms"] ?? "-",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Rekomendasi Penanganan:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scanResult!["solution"] ?? "-",
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 3. HALAMAN PANDUAN BUDIDAYA TEMBAKAU
// ==========================================================
class CultivationGuideScreen extends StatelessWidget {
  const CultivationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> guides = [
      {
        "step": "Tahap 1",
        "title": "Pembenihan & Persemaian",
        "duration": "Durasi: 0 - 35 Hari Setelah Semai",
        "desc": "Pilih benih tembakau unggul yang bersertifikat. Siapkan media semai campuran tanah halus dan pupuk kandang matang (perbandingan 1:1).\n\nPerlindungan: Berikan naungan plastik atau paranet agar bibit tidak rusak oleh terik matahari langsung atau curah hujan tinggi.\n\nPerawatan: Lakukan penyiraman secara rutin menggunakan sprayer halus setiap pagi dan sore hari.",
        "tools": "Benih unggul, Polybag/bedengan semai, Pupuk kandang, Paranet/naungan.",
      },
      {
        "step": "Tahap 2",
        "title": "Pengolahan Tanah & Pembuatan Bedengan",
        "duration": "Durasi: Persiapan sebelum tanam (± 1 minggu)",
        "desc": "Lakukan pembajakan atau pencangkulan tanah sedalam 20-30 cm untuk menggemburkan tanah dan membasmi bibit penyakit.\n\nPembuatan Bedengan: Buat bedengan dengan lebar 100-120 cm, tinggi 30 cm, dan jarak antar bedengan 40 cm.\n\nPemupukan Dasar: Taburkan pupuk kandang dan kapur pertanian (dolomit) jika pH tanah terlalu masam.",
        "tools": "Cangkul, Traktor mini, Pupuk kandang matang, Dolomit.",
      },
      {
        "step": "Tahap 3",
        "title": "Penanaman Bibit di Lahan",
        "duration": "Durasi: Saat bibit berumur 35 - 45 hari",
        "desc": "Pilih bibit yang sehat, tegar, dan memiliki 4-5 helai daun sejati.\n\nWaktu Tanam: Sebaiknya lakukan penanaman pada sore hari untuk meminimalkan stres pada tanaman akibat panas matahari.\n\nJarak Tanam: Atur jarak tanam ideal sekitar 50 cm x 70 cm agar sirkulasi udara dan penyerapan cahaya optimal.",
        "tools":
            "Bibit siap tanam, Aster/alat ukur jarak tanam, Air penyiraman.",
      },
      {
        "step": "Tahap 4",
        "title": "Pemeliharaan, Pemupukan & Penyiangan",
        "duration": "Durasi: 10 - 60 Hari Setelah Tanam (HST)",
        "desc": "• Penyiraman: Jaga kecukupan air tapi hindari genangan air yang terlalu lama.\n• Pemupukan Susulan: Berikan pupuk NPK/ZA pada umur 10-14 HST dan 25-30 HST.\n• Penyiangan & Wiwil: Cabut rumput liar di sekitar tanaman dan pangkas tunas samping (wiwil) serta bunga utama agar nutrisi terfokus pada pertumbuhan daun.",
        "tools": "Pupuk NPK/ZA, Ember penyiram, Gunting pangkas.",
      },
      {
        "step": "Tahap 5",
        "title": "Panen & Pascapanen Daun Tembakau",
        "duration": "Durasi: Mulai umur 70 - 90 HST",
        "desc": "• Pemetikan: Dilakukan bertahap mulai dari daun bagian bawah yang sudah menunjukkan tanda masak (warna hijau kekuningan).\n• Pascapanen: Lakukan perajangan daun dengan ketebalan merata, lalu susun di atas tikar/rak untuk proses penjemuran di bawah sinar matahari hingga kering sempurna.",
        "tools": "Pisau petik, Alat perajang tembakau, Tempat penjemuran (Gudang/rak).",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panduan Budidaya Tembakau"),
        backgroundColor: Colors.green[800],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final item = guides[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
              title: Text(
                item["title"]!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                item["step"]!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          item["duration"]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item["desc"]!,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.build,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Alat & Bahan: ${item["tools"]}",
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================================
// 4. HALAMAN CATATAN KEUANGAN
// ==========================================================
class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _recordType = 'expense';

  late Future<List<dynamic>> _futureRecords;

  @override
  void initState() {
    super.initState();
    _futureRecords = _fetchRecords();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchRecords() async {
    try {
      final response = await http.get(
        Uri.parse('https://tanitembakau-backend.vercel.app/api/records'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Gagal memuat data dari server');
      }
    } catch (e) {
      throw Exception('Kesalahan koneksi: $e');
    }
  }

  void _refreshRecords() {
    setState(() {
      _futureRecords = _fetchRecords();
    });
  }

  Future<void> _saveRecord() async {
    final url = Uri.parse(
      'https://tanitembakau-backend.vercel.app/api/records',
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": 1,
          "record_type": _recordType,
          "category": _categoryController.text,
          "amount": double.tryParse(_amountController.text) ?? 0.0,
          "description": _descController.text,
          "record_date": DateTime.now().toIso8601String().split('T')[0],
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Catatan keuangan berhasil disimpan! ✅"),
          ),
        );
        _categoryController.clear();
        _amountController.clear();
        _descController.clear();
        _refreshRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal menyimpan data ke server.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan koneksi: $e")));
    }
  }

  Future<void> _deleteRecord(int id) async {
    final url = Uri.parse(
      'https://tanitembakau-backend.vercel.app/api/records/$id',
    );

    try {
      final response = await http.delete(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Catatan berhasil dihapus! 🗑️")),
        );
        _refreshRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal menghapus data dari server.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan koneksi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Catatan Keuangan Tani"),
        backgroundColor: Colors.green[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tambah Catatan Baru",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _recordType,
              items: const [
                DropdownMenuItem(
                  value: 'expense',
                  child: Text("Pengeluaran / Modal (Bibit, Pupuk, dll)"),
                ),
                DropdownMenuItem(
                  value: 'income',
                  child: Text("Pemasukan / Hasil Panen"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _recordType = value!;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: "Kategori (Contoh: Pupuk Urea)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Nominal (Rp)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Keterangan Tambahan",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                ),
                onPressed: _saveRecord,
                child: const Text(
                  "Simpan Catatan",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            const Text(
              "Riwayat Catatan Keuangan",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(
              future: _futureRecords,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Gagal memuat data: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Belum ada catatan keuangan.'),
                    ),
                  );
                }

                final records = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final bool isExpense = record['record_type'] == 'expense';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isExpense
                              ? Colors.red[100]
                              : Colors.green[100],
                          child: Icon(
                            isExpense
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(
                          record['category'] ?? 'Tanpa Kategori',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${record['description'] ?? '-'}\nTanggal: ${record['record_date'] != null ? record['record_date'].toString().split('T')[0] : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rp ${record['amount']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isExpense ? Colors.red : Colors.green,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Hapus Catatan'),
                                    content: const Text(
                                      'Apakah Anda yakin ingin menghapus catatan ini?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                          _deleteRecord(record['id']);
                                        },
                                        child: const Text(
                                          'Hapus',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 5. HALAMAN HARGA PASAR & TREN (DINAMIS DARI DATABASE)
// ==========================================================
class MarketPriceScreen extends StatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  late Future<List<dynamic>> _futurePrices;

  List<FlSpot> _priceTrendSpots = const [
    FlSpot(1, 48),
    FlSpot(2, 52),
    FlSpot(3, 55),
    FlSpot(4, 58),
    FlSpot(5, 62),
  ];
  List<String> _chartBottomLabels = ['M1', 'M2', 'M3', 'M4', 'M5'];
  double _minY = 40;
  double _maxY = 70;

  @override
  void initState() {
    super.initState();
    _futurePrices = _fetchMarketPrices();
  }

  Future<List<dynamic>> _fetchMarketPrices() async {
    final response = await http
        .get(
          Uri.parse(
            'https://tanitembakau-backend.vercel.app/api/market-prices',
          ),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _updateChartFromApi(data);
      return data;
    } else {
      throw Exception('Gagal memuat data harga pasar dari server');
    }
  }

  void _updateChartFromApi(List<dynamic> data) {
    List<FlSpot> newSpots = [];
    List<String> newLabels = [];
    double lowest = double.infinity;
    double highest = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rawHarga = (item['harga'] ?? '0').toString();

      final numericStr = rawHarga.replaceAll(RegExp(r'[^0-9]'), '');
      final double fullPrice = double.tryParse(numericStr) ?? 0;

      if (fullPrice > 0) {
        final double priceInThousands = fullPrice >= 1000
            ? fullPrice / 1000.0
            : fullPrice;

        newSpots.add(
          FlSpot((newSpots.length + 1).toDouble(), priceInThousands),
        );

        if (priceInThousands < lowest) lowest = priceInThousands;
        if (priceInThousands > highest) highest = priceInThousands;

        final labelText = (item['wilayah'] ?? item['komoditas'] ?? 'K${i + 1}')
            .toString();
        newLabels.add(
          labelText.length > 6 ? labelText.substring(0, 6) : labelText,
        );
      }
    }

    if (newSpots.length >= 2 && mounted) {
      setState(() {
        _priceTrendSpots = newSpots;
        _chartBottomLabels = newLabels;
        _minY = (lowest - 10).clamp(0, double.infinity).floorToDouble();
        _maxY = (highest + 10).ceilToDouble();
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _futurePrices = _fetchMarketPrices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Pasar & Tren Tembakau'),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Perbarui Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📈 Perbandingan Harga Komoditas Daerah (Rp/kg)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(
                                show: true,
                                drawVerticalLine: false,
                              ),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt() - 1;
                                      if (index >= 0 &&
                                          index < _chartBottomLabels.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6.0,
                                          ),
                                          child: Text(
                                            _chartBottomLabels[index],
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}rb',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                    reservedSize: 36,
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 1,
                              maxX: _priceTrendSpots.length.toDouble(),
                              minY: _minY,
                              maxY: _maxY,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _priceTrendSpots,
                                  isCurved: true,
                                  color: Colors.green[700],
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.green.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                color: Colors.green[50],
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green[800], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Data terhubung secara otomatis ke server database TaniTembakau.',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Daftar Acuan Harga Komoditas Real-Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              FutureBuilder<List<dynamic>>(
                future: _futurePrices,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Gagal memuat harga pasar: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Belum ada data harga pasar.'),
                      ),
                    );
                  }

                  final prices = snapshot.data!;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prices.length,
                    itemBuilder: (context, index) {
                      final item = prices[index];
                      final isUp = item['trend'] == 'naik';
                      final isDown = item['trend'] == 'turun';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['komoditas'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['wilayah'] ?? '-',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sumber: ${item['sumber'] ?? 'Dinas/APTI'}',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['harga'] ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUp
                                          ? Colors.green[100]
                                          : isDown
                                          ? Colors.red[100]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isUp
                                              ? Icons.arrow_upward
                                              : isDown
                                              ? Icons.arrow_downward
                                              : Icons.remove,
                                          size: 12,
                                          color: isUp
                                              ? Colors.green[800]
                                              : isDown
                                              ? Colors.red[800]
                                              : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          (item['trend'] ?? 'STABIL')
                                              .toString()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isUp
                                                ? Colors.green[800]
                                                : isDown
                                                ? Colors.red[800]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 6. GEMINI API SERVICE (SUPPORT FORMAT API KEY "AQ." & FALLBACK)
// ==========================================================
class GeminiApiService {
  // Masukkan API Key berformat "AQ." Anda di bawah ini:
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Urutan model fallback otomatis
  static const List<String> _models = ['gemini-3.8-flash'];

  static Future<Map<String, dynamic>> analyzePestImage(
    File imageFile,
    String promptText,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": promptText},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
    };

    String? lastErrorDetails;

    // Iterasi model cadangan secara berurutan
    for (String modelName in _models) {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent';

      // Mekanisme Automatic Retry & Exponential Backoff (Maksimal 2 kali percobaan ulang)
      for (int attempt = 0; attempt <= 2; attempt++) {
        try {
          if (attempt > 0) {
            await Future.delayed(const Duration(seconds: 3));
          }

          final response = await http
              .post(
                Uri.parse(url),
                headers: {
                  "Content-Type": "application/json",
                  "x-goog-api-key": _apiKey,
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidateText =
                data['candidates'][0]['content']['parts'][0]['text'];

            final cleanJson = candidateText
                .replaceAll(RegExp(r'```json|```'), '')
                .trim();
            return jsonDecode(cleanJson);
          } else if (response.statusCode == 503 || response.statusCode == 429) {
            lastErrorDetails = "HTTP ${response.statusCode} pada $modelName";
            continue;
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            throw Exception(
              "API Key tidak valid atau akses ditolak (HTTP ${response.statusCode}).",
            );
          } else {
            lastErrorDetails =
                "HTTP ${response.statusCode} pada $modelName: ${response.body}";
            break;
          }
        } catch (e) {
          final msg = e.toString();
          if (msg.contains("API Key tidak valid")) {
            rethrow;
          }
          lastErrorDetails = "[$modelName] $msg";
        }
      }
    }

    throw Exception(
      lastErrorDetails ??
          "Server AI sedang padat sementara. Silakan tekan tombol coba lagi.",
    );
  }
}
