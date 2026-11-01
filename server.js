const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const { GoogleGenAI } = require('@google/genai');
const multer = require('multer');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

const upload = multer({ storage: multer.memoryStorage() });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring database client', err.stack);
  }
  console.log('Successfully connected to database');
  release();
});

// Inisialisasi Google Gen AI SDK resmi
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || process.env.GCP_SERVICE_ACCOUNT_KEY });

// ==========================================
// ENDPOINT: DETEKSI HAMA 100% AI (OFFICIAL SDK)
// ==========================================
app.post('/api/detect-pest', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'File gambar tidak ditemukan.' });
    }

    const apiKey = process.env.GEMINI_API_KEY || process.env.GCP_SERVICE_ACCOUNT_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'API key belum diatur di environment Vercel.' });
    }

    const base64Image = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype || 'image/jpeg';

    const promptText = `
      Anda adalah pakar patologi tanaman tembakau profesional. Analisis foto daun yang diunggah dengan cermat.
      Jika foto tersebut bukan daun atau tanaman tembakau (seperti daun mangga atau objek lain), jelaskan pada bagian pestName bahwa itu bukan tanaman tembakau.
      Berikan respons HANYA dalam format JSON murni tanpa ada pembungkus markdown dengan struktur persis seperti ini:
      {
        "pestName": "Nama Hama / Penyakit / Bukan Tanaman Tembakau",
        "confidence": "95.0%",
        "symptoms": "Deskripsi singkat gejala atau kondisi objek pada foto",
        "solution": "Saran penanganan teknis bagi petani"
      }
    `;

    // Menggunakan SDK resmi Google Gen AI untuk menghindari error manual HTTP header
    const response = await ai.models.generateContent({
      model: 'gemini-1.5-flash',
      contents: [
        { text: promptText },
        {
          inlineData: {
            mimeType: mimeType,
            data: base64Image
          }
        }
      ]
    });

    const responseText = response.text;
    if (!responseText) {
      throw new Error('Respons dari server AI kosong.');
    }

    const cleanJsonText = responseText.replace(/```json|```/g, '').trim();
    const parsedData = JSON.parse(cleanJsonText);

    return res.status(200).json({
      success: true,
      data: parsedData
    });

  } catch (err) {
    console.error('SDK AI ERROR:', err.message);
    return res.status(500).json({ error: 'Gagal memproses AI: ' + err.message });
  }
});

// Endpoint Database pendukung
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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

module.exports = app;