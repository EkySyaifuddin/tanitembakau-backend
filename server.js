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

// 1. GET: Ambil semua catatan keuangan
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

// 2. POST: Tambah catatan baru
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

// 3. POST: Hapus catatan berdasarkan ID (Metode POST khusus agar aman & tembus di Vercel)
app.post('/api/records/delete', async (req, res) => {
  const { id } = req.body;
  console.log("Menerima request hapus (via POST) untuk ID:", id);

  if (!id) {
    return res.status(400).json({ error: 'ID tidak boleh kosong' });
  }
  
  try {
    const query = 'DELETE FROM farm_records WHERE id = $1 RETURNING *';
    const result = await pool.query(query, [id]);
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Data tidak ditemukan di database' });
    }
    
    res.json({ message: 'Catatan berhasil dihapus', deleted: result.rows[0] });
  } catch (err) {
    console.error('Error saat menghapus data:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Jalankan server untuk mode local (opsional, Vercel otomatis menghandle export)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});

module.exports = app;