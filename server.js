require('dotenv').config();

const express = require('express');
const { Pool } = require('pg');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Konfigurasi Koneksi ke Database Supabase (PostgreSQL) menggunakan connectionString langsung
const pool = new Pool({
  connectionString: 'postgresql://postgres.obwqqxklqjjzzapcvgvy:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres',
  ssl: {
    rejectUnauthorized: false // Wajib untuk koneksi Supabase dari cloud hosting Vercel
  }
});

// Tes Koneksi Database saat Server Menyala
pool.connect((err, client, release) => {
    if (err) {
        console.error("Gagal terhubung ke database Supabase:", err.stack);
        return;
    }
    console.log("Berhasil terhubung ke database Supabase (PostgreSQL)!");
    release();
});

// ==================== ENDPOINT CATATAN KEUANGAN ====================

// 1. Mengambil seluruh catatan keuangan (GET)
app.get('/api/records', async (req, res) => {
  const query = 'SELECT * FROM farm_records ORDER BY record_date DESC';
  
  try {
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error('Gagal mengambil data database:', err);
    res.status(500).json({ error: 'Gagal mengambil data dari database' });
  }
});

// 2. Menambah Catatan Keuangan Baru (POST)
app.post('/api/records', async (req, res) => {
  const { user_id, record_type, category, amount, description, record_date } = req.body;
  
  const query = `
    INSERT INTO farm_records (user_id, record_type, category, amount, description, record_date) 
    VALUES ($1, $2, $3, $4, $5, $6) 
    RETURNING id
  `;
  
  try {
    const result = await pool.query(query, [user_id, record_type, category, amount, description, record_date]);
    res.json({ message: 'Catatan berhasil disimpan', id: result.rows[0].id });
  } catch (err) {
    console.error('Gagal menyimpan data ke database:', err);
    res.status(500).json({ error: 'Gagal menyimpan data ke database' });
  }
});

// 3. Menghapus catatan berdasarkan ID (DELETE)
app.delete('/api/records/:id', async (req, res) => {
  const recordId = req.params.id;
  const query = 'DELETE FROM farm_records WHERE id = $1 RETURNING id';

  try {
    const result = await pool.query(query, [recordId]);
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Data tidak ditemukan' });
    }

    res.json({ message: 'Catatan berhasil dihapus' });
  } catch (err) {
    console.error('Gagal menghapus data:', err);
    res.status(500).json({ error: 'Gagal menghapus data dari database' });
  }
});

// ==================== ENDPOINT HARGA PASAR (TAMBAHAN) ====================

// 4. Mengambil daftar harga pasar tembakau (GET)
app.get('/api/market-prices', async (req, res) => {
  const query = 'SELECT * FROM market_prices';

  try {
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.warn('Tabel market_prices belum ada, menggunakan data fallback.');
    res.json([
      { id: 1, komoditas: 'Tembakau Virginia (Grade A)', wilayah: 'Temanggung, Jawa Tengah', harga: 'Rp 55.000 / kg', trend: 'naik', update: 'Hari ini, 10:00 WIB' },
      { id: 2, komoditas: 'Tembakau Kasturi (Super)', wilayah: 'Jember, Jawa Timur', harga: 'Rp 48.000 / kg', trend: 'naik', update: 'Hari ini, 09:30 WIB' },
      { id: 3, komoditas: 'Tembakau Madura (Janturan)', wilayah: 'Pamekasan, Madura', harga: 'Rp 42.000 / kg', trend: 'stabil', update: 'Kemarin' },
    ]);
  }
});

// Jalankan Server di Port 3000
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server berjalan di port ${PORT}`);
});