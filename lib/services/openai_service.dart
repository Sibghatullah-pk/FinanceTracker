import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lightweight AI service wrapper that supports either OpenAI (OPENAI_API_KEY)
/// or Google Generative Language / Gemini (GEMINI_API_KEY + GEMINI_MODEL).
class OpenAIService {
  OpenAIService._private();
  static final OpenAIService instance = OpenAIService._private();

  final _client = http.Client();

  String? get _geminiKey {
    try {
      return dotenv.env['GEMINI_API_KEY'];
    } catch (_) {
      return null;
    }
  }

  String? get _geminiModel {
    try {
      return dotenv.env['GEMINI_MODEL'];
    } catch (_) {
      return null;
    }
  }

  /// True if Gemini is configured.
  bool get isConfigured => _geminiKey != null && _geminiKey!.isNotEmpty;

  /// Send a prompt and return assistant text. Uses Google Gemini (Generative Language).
  /// This project uses Gemini exclusively; if `GEMINI_API_KEY` is not set a
  /// StateError is thrown to guide configuration.
  Future<String> chat(String prompt,
      {String? model, double temperature = 0.7, int maxTokens = 512}) async {
    try {
      if (_geminiKey == null || _geminiKey!.isEmpty) {
        throw StateError(
            'Gemini API key not configured (set GEMINI_API_KEY in .env)');
      }

      final gemModel = model ?? _geminiModel ?? 'models/text-bison-001';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta2/$gemModel:generateText?key=${_geminiKey!}');

      final body = jsonEncode({
        'prompt': {
          'text': prompt,
        },
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      });

      final res = await _client.post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: body);

      if (res.statusCode != 200) {
        throw Exception('Gemini request failed: ${res.statusCode} ${res.body}');
      }

      final Map<String, dynamic> json = jsonDecode(res.body);
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return '';
      final output = candidates.first['output'] as String? ?? '';
      return output.trim();
    } on NotInitializedError catch (_) {
      throw StateError(
          'Environment variables not loaded: create a .env file and ensure dotenv.load() runs before using AI features.');
    }
  }
}
