const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// Gunakan memory storage multer standar untuk serverless
const upload = multer({ storage: multer.memoryStorage() });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// Test koneksi database saat server mulai
pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring database client', err.stack);
  }
  console.log('Successfully connected to database');
  release();
});

// ==========================================
// ENDPOINT: DETEKSI HAMA AI (AMAN & DINAMIS)
// ==========================================
app.post('/api/detect-pest', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'File gambar tidak ditemukan.' });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'GEMINI_API_KEY belum diset di environment variable server.' });
    }

    // Inisialisasi genAI di dalam endpoint untuk mencegah kendala scope serverless
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const imagePart = {
      inlineData: {
        data: req.file.buffer.toString('base64'),
        mimeType: req.file.mimetype || 'image/jpeg'
      }
    };

    const prompt = `
      Anda adalah pakar patologi tanaman tembakau profesional. Analisis foto daun yang diunggah dengan cermat.
      Jika foto tersebut bukan daun atau tanaman tembakau (seperti daun mangga atau objek lain), jelaskan pada bagian pestName bahwa itu bukan tanaman tembakau.
      Berikan respons HANYA dalam format JSON murni tanpa ada pembungkus markdown (tanpa \`\`\`json) dengan struktur persis seperti ini:
      {
        "pestName": "Nama Hama / Penyakit / Bukan Tanaman Tembakau",
        "confidence": "95.0%",
        "symptoms": "Deskripsi singkat gejala atau kondisi objek pada foto",
        "solution": "Saran penanganan teknis bagi petani"
      }
    `;

    const result = await model.generateContent([prompt, imagePart]);
    const responseText = result.response.text();
    const cleanJsonText = responseText.replace(/```json|```/g, '').trim();
    const parsedData = JSON.parse(cleanJsonText);

    return res.status(200).json({
      success: true,
      data: parsedData
    });

  } catch (err) {
    console.error('VERCEL AI ERROR:', err);
    return res.status(500).json({ error: 'Gagal memproses AI: ' + err.message });
  }
});

// ==========================================
// ENDPOINTS LAIN: KEUANGAN & HARGA PASAR
// ==========================================
app.get('/api/records', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM farm_records ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
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
    const result = await pool.query(query, [user_id || 1, record_type, category, amount, description, record_date]);
    res.status(201).json({ message: 'Catatan berhasil disimpan', data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/records/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM farm_records WHERE id = $1', [req.params.id]);
    res.json({ message: 'Catatan berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/market-prices', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM market_prices ORDER BY id ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

module.exports = app;