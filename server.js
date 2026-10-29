const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Konfigurasi koneksi ke database Supabase PostgreSQL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

// Test koneksi database saat server mulai
pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring client', err.stack);
  }
  console.log('Successfully connected to database');
  release();
});

// ==========================================
// 1. ENDPOINTS: CATATAN KEUANGAN (farm_records)
// ==========================================

// GET: Ambil semua catatan keuangan
app.get('/api/records', async (req, res) => {
  try {
    const query = 'SELECT * FROM farm_records ORDER BY id DESC';
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error('Error mengambil data:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST: Tambah catatan keuangan baru
app.post('/api/records', async (req, res) => {
  const { user_id, record_type, category, amount, description, record_date } = req.body;
  
  try {
    const query = `
      INSERT INTO farm_records (user_id, record_type, category, amount, description, record_date) 
      VALUES ($1, $2, $3, $4, $5, $6) 
      RETURNING *
    `;
    const values = [user_id || 1, record_type, category, amount, description, record_date];
    const result = await pool.query(query, values);
    
    res.status(201).json({ message: 'Catatan berhasil disimpan', data: result.rows[0] });
  } catch (err) {
    console.error('Error menyimpan data:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// DELETE: Hapus catatan keuangan berdasarkan ID
app.delete('/api/records/:id', async (req, res) => {
  const { id } = req.params;
  console.log("Menerima request hapus untuk ID:", id);

  if (!id) {
    return res.status(400).json({ error: 'ID tidak boleh kosong' });
  }
  
  try {
    const query = 'DELETE FROM farm_records WHERE id = $1';
    const result = await pool.query(query, [id]);
    
    console.log("Baris yang terhapus:", result.rowCount);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Data dengan ID tersebut tidak ditemukan' });
    }

    res.json({ message: 'Catatan berhasil dihapus', rowCount: result.rowCount });
  } catch (err) {
    console.error('Error saat menghapus data:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// 2. ENDPOINTS: HARGA PASAR (market_prices)
// ==========================================

// GET: Ambil semua data harga pasar tembakau secara dinamis
app.get('/api/market-prices', async (req, res) => {
  try {
    const query = 'SELECT * FROM market_prices ORDER BY id ASC';
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error('Error mengambil harga pasar:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST: Tambah data harga pasar baru (Opsional / Admin)
app.post('/api/market-prices', async (req, res) => {
  const { komoditas, wilayah, harga, trend, sumber } = req.body;
  try {
    const query = `
      INSERT INTO market_prices (komoditas, wilayah, harga, trend, sumber) 
      VALUES ($1, $2, $3, $4, $5) 
      RETURNING *
    `;
    const values = [komoditas, wilayah, harga, trend || 'stabil', sumber || 'Dinas/APTI'];
    const result = await pool.query(query, values);
    
    res.status(201).json({ message: 'Harga pasar berhasil ditambahkan', data: result.rows[0] });
  } catch (err) {
    console.error('Error menyimpan harga pasar:', err.message);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});

module.exports = app;