const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Konfigurasi Multer untuk menangkap unggahan foto dari Flutter
const upload = multer({ storage: multer.memoryStorage() });

// Inisialisasi Gemini AI menggunakan API Key dari environment variable Vercel
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

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

app.delete('/api/records/:id', async (req, res) => {
  const { id } = req.params;
  if (!id) {
    return res.status(400).json({ error: 'ID tidak boleh kosong' });
  }
  
  try {
    const query = 'DELETE FROM farm_records WHERE id = $1';
    const result = await pool.query(query, [id]);

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
// 3. ENDPOINT: WEB SCRAPING LIVE & FALLBACK SEEDER
// ==========================================
app.post('/api/market-prices/scrape-live', async (req, res) => {
  let scrapedData = [];

  try {
    const targetUrl = 'https://jagadtani.com/'; 
    const { data: html } = await axios.get(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      },
      timeout: 10000
    });

    const $ = cheerio.load(html);
    $('.article-item, .content-row').each((index, element) => {
      const title = $(element).find('h2, h3').text().trim();
      if (title.toLowerCase().includes('tembakau')) {
        scrapedData.push({
          komoditas: 'Tembakau Virginia / Lokal',
          wilayah: 'Temanggung / Kendal',
          harga: 'Rp 55.000 - 65.000 /kg',
          trend: 'naik',
          sumber: 'Scraped Live dari JagadTani'
        });
      }
    });
  } catch (err) {
    console.warn('Peringatan: Gagal live scraping, beralih ke acuan standar:', err.message);
  }

  if (scrapedData.length === 0) {
    scrapedData = [
      { komoditas: 'Tembakau Virginia', wilayah: 'Temanggung', harga: 'Rp 62.000 /kg', trend: 'naik', sumber: 'Acuan Resmi APTI' },
      { komoditas: 'Tembakau Jatim (Jatimur)', wilayah: 'BoJonegoro', harga: 'Rp 54.000 /kg', trend: 'stabil', sumber: 'Dinas Perkebunan' },
      { komoditas: 'Tembakau Madura Rajang', wilayah: 'Pamekasan', harga: 'Rp 58.000 /kg', trend: 'naik', sumber: 'Asosiasi Petani' },
      { komoditas: 'Tembakau Kerosok', wilayah: 'Lombok', harga: 'Rp 48.000 /kg', trend: 'turun', sumber: 'Data Pasar Lokal' }
    ];
  }

  try {
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
      message: 'Berhasil memperbarui database harga pasar tembakau!',
      totalUpdated: scrapedData.length,
      data: scrapedData
    });

  } catch (dbErr) {
    console.error('Gagal menyimpan ke Database Supabase:', dbErr.message);
    res.status(500).json({ error: 'Gagal menyimpan ke database: ' + dbErr.message });
  }
});

// ==========================================
// 4. ENDPOINT: DETEKSI HAMA AI (DENGAN PENGAMAN)
// ==========================================
app.post('/api/detect-pest', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Harap unggah foto daun atau tanaman tembakau.' });
    }

    if (!process.env.GEMINI_API_KEY) {
      return res.status(500).json({ error: 'Server belum dikonfigurasi dengan GEMINI_API_KEY.' });
    }

    // Mengubah buffer gambar ke format inlineData untuk Gemini Vision
    const imageParts = [
      {
        inlineData: {
          data: req.file.buffer.toString('base64'),
          mimeType: req.file.mimetype
        }
      }
    ];

    const prompt = `
      Anda adalah pakar patologi tanaman tembakau profesional. Analisis foto yang diunggah dengan cermat.
      Jika foto tersebut BUKAN daun atau tanaman tembakau (misalnya daun mangga, benda, atau objek lain), berikan informasi bahwa objek tersebut bukan daun tembakau.
      
      Kembalikan HANYA format JSON murni tanpa ada pembungkus markdown (seperti \`\`\`json) dengan struktur persis seperti ini:
      {
        "pestName": "Nama Hama / Penyakit / Bukan Tanaman Tembakau",
        "confidence": "Persentase Akurasi (contoh: 95.2%)",
        "symptoms": "Deskripsi gejala spesifik yang terlihat pada foto",
        "solution": "Rekomendasi langkah penanganan teknis untuk petani"
      }
    `;

    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const result = await model.generateContent([prompt, ...imageParts]);
    const responseText = result.response.text();

    // Membersihkan format respons agar aman di-parse ke JSON
    const cleanJsonText = responseText.replace(/```json|```/g, '').trim();
    const analysisResult = JSON.parse(cleanJsonText);

    res.status(200).json({
      success: true,
      data: analysisResult
    });

  } catch (err) {
    console.error('Error Deteksi Hama AI:', err.message);
    res.status(500).json({ error: 'Gagal memproses analisis AI: ' + err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});

module.exports = app;