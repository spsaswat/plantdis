import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:developer' as developer;

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  GenerativeModel? _model;
  final String _apiKey;

  // List of model names to try
  final List<String> _modelNames = [
    'gemini-1.5-pro',
    'gemini-pro',
    'gemini-1.0-pro',
  ];

  factory GeminiService() {
    return _instance;
  }

  // Private constructor to initialize the API
  GeminiService._internal() : _apiKey = 'AIzaSyDfDxPC2xc06Qj9qriKp1TUlhLt-ek5Y3Q' {
    if (_apiKey.isEmpty) {
      developer.log('API Key is empty', error: 'API key not found');
      throw Exception('API key not found');
    }
  }

  // Send a question and get an answer
  Future<String> getAnswer(String question) async {
    developer.log('Sending question to Gemini: $question');

    // Try each model until one works
    for (final modelName in _modelNames) {
      try {
        developer.log('Trying model: $modelName');

        _model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
        );

        final prompt = '''
I need information about the following plant disease-related question:
$question

Important formatting requirements:
1. Provide a brief 1-2 sentence direct answer first
2. Then include 3-5 main points using simple bullet points with dash (-)
3. Keep the total response under 150 words
4. Use plain text only - no markdown, headings, or special formatting
5. Provide accurate, practical information for farmers and gardeners
''';

        final content = [Content.text(prompt)];
        developer.log('Sending request to Gemini API with model $modelName...');

        final response = await _model!.generateContent(content);
        developer.log('Response received from Gemini API');

        final responseText = response.text;
        if (responseText == null || responseText.isEmpty) {
          developer.log('Empty response received from Gemini API');
          continue; // Try next model
        }

        // Clean up any potential markdown or special formatting
        return _cleanResponseFormat(responseText);
      } catch (e) {
        developer.log('Error with model $modelName: ${e.toString()}');
        // Continue to the next model
      }
    }

    // If all models failed
    return 'Error: Could not connect to any Gemini models. Please check your API key permissions.';
  }
  
  // Helper method to clean and format the response text
  String _cleanResponseFormat(String text) {
    // Remove any markdown headers
    String cleaned = text.replaceAll(RegExp(r'#+\s+'), '');
    
    // Standardize bullet points to simple dashes
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '- ');
    
    // Remove any code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    
    // Remove markdown emphasis (bold, italic)
    cleaned = cleaned.replaceAll(RegExp(r'[\_\*\`]'), '');
    
    // Fix spacing - remove excessive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Trim extra whitespace
    return cleaned.trim();
  }
}