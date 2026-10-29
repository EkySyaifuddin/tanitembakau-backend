const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
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
    console.error('Error mengambil data harga pasar:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST: Tambah data harga pasar baru (Manual / Opsional)
app.post('/api/market-prices', async (req, res) => {
  const { komoditas, wilayah, harga, trend, sumber } = req.body;
  try {
    const query = `
      INSERT INTO market_prices (komoditas, wilayah, harga, trend, sumber, updated_at) 
      VALUES ($1, $2, $3, $4, $5, NOW()) 
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

// ==========================================
// 3. ENDPOINT: WEB SCRAPING LIVE (Otomatis dari Sumber Luar)
// ==========================================
app.post('/api/market-prices/scrape-live', async (req, res) => {
  try {
    // Ganti targetUrl dengan situs portal berita/agribisnis target Anda
    const targetUrl = 'https://sumber-berita-pangan.id/harga-tembakau'; 

    const { data: html } = await axios.get(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      }
    });

    const $ = cheerio.load(html);
    const scrapedData = [];

    // Parsing elemen HTML situs sumber (sesuaikan selector HTML dengan situs target)
    $('table.tabel-harga tbody tr').each((index, element) => {
      const komoditas = $(element).find('.nama-komoditas').text().trim();
      const wilayah = $(element).find('.wilayah').text().trim();
      const harga = $(element).find('.harga').text().trim();
      const trendText = $(element).find('.trend').text().trim().toLowerCase();
      
      let trend = 'stabil';
      if (trendText.includes('naik') || trendText.includes('up')) trend = 'naik';
      if (trendText.includes('turun') || trendText.includes('down')) trend = 'turun';

      if (komoditas && harga) {
        scrapedData.push({ komoditas, wilayah, harga, trend, sumber: 'Scraped Live dari Portal Resmi' });
      }
    });

    // Simpan atau Perbarui (Upsert) ke database Supabase
    for (let item of scrapedData) {
      const checkQuery = 'SELECT id FROM market_prices WHERE komoditas = $1 AND wilayah = $2';
      const checkResult = await pool.query(checkQuery, [item.komoditas, item.wilayah]);

      if (checkResult.rows.length > 0) {
        const updateQuery = `
          UPDATE market_prices 
          SET harga = $1, trend = $2, sumber = $3, updated_at = NOW() 
          WHERE komoditas = $4 AND wilayah = $5
        `;
        await pool.query(updateQuery, [item.harga, item.trend, item.sumber, item.komoditas, item.wilayah]);
      } else {
        const insertQuery = `
          INSERT INTO market_prices (komoditas, wilayah, harga, trend, sumber, updated_at) 
          VALUES ($1, $2, $3, $4, $5, NOW())
        `;
        await pool.query(insertQuery, [item.komoditas, item.wilayah, item.harga, item.trend, item.sumber]);
      }
    }

    res.status(200).json({
      message: 'Berhasil melakukan Scraping Live dan memperbarui database!',
      totalUpdated: scrapedData.length,
      data: scrapedData
    });

  } catch (err) {
    console.error('Gagal Scraping Data Live:', err.message);
    res.status(500).json({ error: 'Gagal melakukan scraping data live: ' + err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});

module.exports = app;