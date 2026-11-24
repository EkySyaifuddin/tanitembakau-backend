import 'package:flutter/material.dart';

class MarketPriceScreen extends StatelessWidget {
  const MarketPriceScreen({Key? key}) : super(key: key);

  // Data dummy daftar harga pasar tembakau terkini
  final List<Map<String, dynamic>> _marketPrices = const [
    {
      'komoditas': 'Tembakau Virginia (Grade A)',
      'wilayah': 'Temanggung, Jawa Tengah',
      'harga': 'Rp 55.000 / kg',
      'trend': 'naik',
      'update': 'Hari ini, 10:00 WIB',
    },
    {
      'komoditas': 'Tembakau Kasturi (Super)',
      'wilayah': 'Jember, Jawa Timur',
      'harga': 'Rp 48.000 / kg',
      'trend': 'naik',
      'update': 'Hari ini, 09:30 WIB',
    },
    {
      'komoditas': 'Tembakau Madura (Janturan)',
      'wilayah': 'Pamekasan, Madura',
      'harga': 'Rp 42.000 / kg',
      'trend': 'stabil',
      'update': 'Kemarin',
    },
    {
      'komoditas': 'Tembakau Srintil (Lokal Premium)',
      'wilayah': 'Wonosobo, Jawa Tengah',
      'harga': 'Rp 150.000 / kg',
      'trend': 'naik',
      'update': 'Hari ini, 08:00 WIB',
    },
    {
      'komoditas': 'Tembakau Rajangan Biasa',
      'wilayah': 'Lombok, NTB',
      'harga': 'Rp 35.000 / kg',
      'trend': 'turun',
      'update': '2 hari lalu',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Pasar Tembakau'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Informasi Atas
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[800]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Harga pasar diperbarui secara berkala berdasarkan rata-rata pengepul dan gudang lokal.',
                    style: TextStyle(color: Colors.green[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Daftar Harga Komoditas Terkini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          // List Harga Pasar
          Expanded(
            child: ListView.builder(
              itemCount: _marketPrices.length,
              itemBuilder: (context, index) {
                final item = _marketPrices[index];
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
                                item['komoditas'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
                                    item['wilayah'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Update: ${item['update']}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item['harga'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green[800],
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
                                    item['trend'].toUpperCase(),
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
            ),
          ),
        ],
      ),
    );
  }
}
