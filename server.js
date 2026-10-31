const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const axios = require('axios');
const multer = require('multer');
const { GoogleAuth } = require('google-auth-library');
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

// ==========================================
// ENDPOINT: DETEKSI HAMA 100% AI (FINAL FIX)
// ==========================================
app.post('/api/detect-pest', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'File gambar tidak ditemukan.' });
    }

    const rawEnvKey = process.env.GEMINI_API_KEY || process.env.GCP_SERVICE_ACCOUNT_KEY;
    if (!rawEnvKey) {
      return res.status(500).json({ error: 'Kunci atau kredensial belum diatur di Vercel.' });
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

    let responseText = '';

    // Cek apakah key berupa JSON Service Account (berisi kurawal '{')
    if (rawEnvKey.trim().startsWith('{')) {
      let credentials;
      try {
        credentials = JSON.parse(rawEnvKey);
        if (credentials.private_key) {
          credentials.private_key = credentials.private_key.replace(/\\n/g, '\n');
        }
      } catch (e) {
        throw new Error('Format JSON Service Account tidak valid.');
      }

      const auth = new GoogleAuth({
        credentials: credentials,
        scopes: ['https://www.googleapis.com/auth/cloud-platform']
      });

      const client = await auth.getClient();
      const accessToken = await client.getAccessToken();
      const tokenStr = accessToken.token || accessToken;
      const projectId = credentials.project_id || 'tanitembakau';

      // Gunakan endpoint Vertex AI regional resmi untuk Service Account
      const vertexUrl = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent`;

      const payload = {
        contents: [
          {
            role: 'user',
            parts: [
              { text: promptText },
              { inlineData: { mimeType: mimeType, data: base64Image } }
            ]
          }
        ]
      };

      const aiResponse = await axios.post(vertexUrl, payload, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenStr}`
        },
        timeout: 30000
      });

      responseText = aiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text;

    } else {
      // Jika itu API Key biasa (AIzaSy...)
      const pubUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${rawEnvKey}`;
      const payload = {
        contents: [
          {
            parts: [
              { text: promptText },
              { inlineData: { mimeType: mimeType, data: base64Image } }
            ]
          }
        ]
      };

      const aiResponse = await axios.post(pubUrl, payload, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000
      });

      responseText = aiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text;
    }

    if (!responseText) {
      throw new Error('Respons dari server AI kosong.');
    }

    const cleanJsonText = responseText.replace(/```json|```/g, '').trim();
    const parsedData = JSON.parse(cleanJsonText);

    return res.status(200).json({
      success: true,
      data: parsedData
    });

  } catchedErr = (err) => {
    // penanganan error catch standar
  }

  catch (err) {
    console.error('AI ERROR:', err.response?.data || err.message);
    const errorMsg = err.response?.data?.error?.message || err.message;
    return res.status(500).json({ error: 'Gagal memproses AI: ' + errorMsg });
  }
});

// ==========================================
// ENDPOINT LAINNYA (DATABASE)
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