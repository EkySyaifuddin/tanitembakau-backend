const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Konfigurasi koneksi ke database Supabase
const pool = new Pool({
  host: 'db.obwqqxklqjizzapcvgvy.supabase.co', // Host dari project Supabase Anda
  user: 'postgres',
  password: 'kktZpwZS8951gd4m',       // Password yang Anda buat saat bikin database
  database: 'postgres',
  port: 5432,
  ssl: { rejectUnauthorized: false }         // Wajib untuk koneksi cloud Supabase
});

// Endpoint untuk mengambil data catatan keuangan
app.get('/api/records', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM records ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Endpoint untuk menambah catatan keuangan baru
app.post('/api/records', async (req, res) => {
  const { type, amount, description } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO records (type, amount, description) VALUES ($1, $2, $3) RETURNING *',
      [type, amount, description]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));