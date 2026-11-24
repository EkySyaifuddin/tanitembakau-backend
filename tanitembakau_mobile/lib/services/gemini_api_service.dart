import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GeminiApiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const List<String> _models = ['gemini-3.8-flash'];

  static Future<Map<String, dynamic>> analyzePestImage(
    File imageFile,
    String promptText,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": promptText},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
    };

    String? lastErrorDetails;

    for (String modelName in _models) {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent';

      // 1. Batas percobaan ulang diubah menjadi 3 kali (attempt 0..3)
      for (int attempt = 0; attempt <= 3; attempt++) {
        try {
          if (attempt > 0) {
            // 2. Jeda antar percobaan ulang diperpanjang menjadi 4 * attempt detik
            await Future.delayed(Duration(seconds: 4 * attempt));
          }

          final response = await http
              .post(
                Uri.parse(url),
                headers: {
                  "Content-Type": "application/json",
                  "x-goog-api-key": _apiKey,
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 60));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidateText =
                data['candidates'][0]['content']['parts'][0]['text'];

            final cleanJson = candidateText
                .replaceAll(RegExp(r'```json|```'), '')
                .trim();
            return jsonDecode(cleanJson);
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            throw Exception(
              "API Key tidak valid atau akses ditolak (HTTP ${response.statusCode}).",
            );
          } else if (response.statusCode == 503) {
            // 3. Pesan khusus saat server gemini-3.8-flash sedang padat (HTTP 503)
            lastErrorDetails =
                "Server $modelName sedang padat (HTTP 503). Tunggu beberapa detik lalu coba lagi.";
            continue;
          } else {
            lastErrorDetails =
                "HTTP ${response.statusCode} pada $modelName: ${response.body}";
            if (response.statusCode != 429) {
              break;
            }
          }
        } catch (e) {
          final msg = e.toString();
          if (msg.contains("API Key tidak valid")) {
            rethrow;
          }
          lastErrorDetails = "[$modelName] $msg";
        }
      }
    }

    throw Exception(
      lastErrorDetails ??
          "Server AI sedang padat sementara. Silakan tekan tombol coba lagi.",
    );
  }
}
