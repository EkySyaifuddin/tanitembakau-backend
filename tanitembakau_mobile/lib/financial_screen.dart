import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({Key? key}) : super(key: key);

  @override
  _FinancialScreenState createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  final String baseUrl = 'https://tanitembakau-backend.vercel.app/api';

  List<dynamic> _records = [];
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  String _recordType = 'Pengeluaran / Modal (Bibit, Pupuk, dll)';
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _recordTypes = [
    'Pengeluaran / Modal (Bibit, Pupuk, dll)',
    'Pemasukan / Penjualan Panen',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/records'));
      if (response.statusCode == 200) {
        setState(() {
          _records = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kesalahan koneksi: $e')));
    }
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;

    final newRecord = {
      "user_id": 1,
      "record_type": _recordType,
      "category": _categoryController.text,
      "amount": double.tryParse(_amountController.text) ?? 0.0,
      "description": _descriptionController.text,
      "record_date": DateTime.now().toIso8601String().split('T')[0],
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/records'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(newRecord),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _categoryController.clear();
        _amountController.clear();
        _descriptionController.clear();
        _fetchRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan berhasil disimpan!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteRecordDirectly(dynamic id) async {
    print('>>> MENGHAPUS ID: $id MELALUI BACKEND VERCEL');

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: ID catatan tidak ditemukan')),
      );
      return;
    }

    try {
      // Memanggil API DELETE ke backend Vercel Anda
      final response = await http.delete(
        Uri.parse('https://tanitembakau-backend.vercel.app/api/records/$id'),
      );

      print('>>> STATUS CODE HAPUS: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Refresh ulang data setelah berhasil dihapus dari server
        setState(() {
          _records.removeWhere((item) => (item['id'] ?? item['ID']) == id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan berhasil dihapus dari server!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus dari server (Kode: ${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      print('>>> ERROR HAPUS: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan koneksi: $e')));
    }
  }

  Widget _buildSummaryCard() {
    double totalPemasukan = 0;
    double totalPengeluaran = 0;

    for (var record in _records) {
      double amount = double.tryParse(record['amount'].toString()) ?? 0.0;
      String type = record['record_type'].toString().toLowerCase();

      if (type.contains('pemasukan') || type.contains('penjualan')) {
        totalPemasukan += amount;
      } else {
        totalPengeluaran += amount;
      }
    }

    double totalSaldo = totalPemasukan - totalPengeluaran;

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Saldo Tani',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${totalSaldo.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pemasukan: Rp ${totalPemasukan.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'Pengeluaran: Rp ${totalPengeluaran.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Keuangan Tani'),
        backgroundColor: Colors.green[750],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _recordType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _recordTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) =>
                          setState(() => _recordType = newValue!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submitRecord,
                        child: const Text('Simpan Catatan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Riwayat Catatan Keuangan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Belum ada catatan.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final item = _records[index];
                      // Mengambil ID dengan aman (mendukung huruf kecil 'id' maupun kapital 'ID')
                      final recordId = item['id'] ?? item['ID'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            item['category'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rp ${item['amount']}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item['description'] != null &&
                                  item['description'].toString().isNotEmpty)
                                Text(
                                  '${item['description']}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          // Tombol Hapus langsung dipasang agar mudah diklik
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Memunculkan konfirmasi sebelum hapus
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Hapus Catatan'),
                                    content: Text(
                                      'Yakin ingin menghapus "${item['category'] ?? '-'}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteRecordDirectly(recordId);
                                        },
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
