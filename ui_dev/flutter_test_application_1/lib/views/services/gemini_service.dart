import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:developer' as developer;

import 'package:flutter_test_application_1/config/api_runtime_secrets.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  GenerativeModel? _model;

  // List of model names to try
  final List<String> _modelNames = [
    'gemma-3-27b-it',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal();

  // Send a question and get an answer
  // Added isPlantRelated parameter to control prompt type
  Future<String> getAnswer(
    String question, {
    bool isPlantRelated = true,
    String? preferredModel,
    bool allowFallback = false,
  }  ) async {
    if (ApiRuntimeSecrets.geminiApiKey.isEmpty) {
      await ApiRuntimeSecrets.init();
    }
    final apiKey = ApiRuntimeSecrets.geminiApiKey;
    if (apiKey.isEmpty) {
      final pathHint = ApiRuntimeSecrets.configFilePathHint;
      final fileHint = pathHint != null
          ? 'Add `geminiApiKey` in: $pathHint (on sandboxed macOS, paste from your project `api_config.json` into this file; the app cannot read the repo path). '
          : 'Add keys in `api_config.json` (see `api_config.json.example`). ';
      return 'Error: Missing Gemini API key. $fileHint'
          'Or set env `PLANTDIS_API_CONFIG` to a readable JSON file, or --dart-define=GEMINI_API_KEY=...';
    }
    developer.log('Sending question to Gemini: $question');
    final String normalizedPreferred = (preferredModel ?? '').trim();
    final bool hasPreferred = normalizedPreferred.isNotEmpty;
    final List<String> modelsToTry =
        (hasPreferred && !allowFallback)
            ? [normalizedPreferred]
            : [
              if (hasPreferred) normalizedPreferred,
              ..._modelNames.where((m) => m != normalizedPreferred),
            ];
    String? lastError;

    // Try each model until one works
    for (final modelName in modelsToTry) {
      try {
        developer.log('Trying model: $modelName');

        _model = GenerativeModel(model: modelName, apiKey: apiKey);

        // Use different prompts based on whether the question is plant-related
        String prompt;
        if (isPlantRelated) {
          // Original plant-related prompt
          prompt = '''
I need information about the following plant disease-related question:
$question

Important formatting requirements:
1. Provide a brief 1-2 sentence direct answer first
2. Then include 3-4 main points using simple bullet points with dash (-)
3. Keep the total response under 150 words
4. Use plain text only - no markdown, headings, or special formatting
5. Provide accurate, practical information for farmers and gardeners
''';
        } else {
          // General prompt for any question
          prompt = '''
Please answer the following question:
$question

Important formatting requirements:
1. Keep the response concise and helpful
2. Use plain text only - no markdown, headings, or special formatting
3. Provide a direct and relevant answer
''';
        }

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
        final err = e.toString();
        developer.log('Error with model $modelName: $err');
        lastError = 'model=$modelName error=$err';
        // Continue to the next model
      }
    }

    // If all models failed
    final detail =
        lastError == null ? '' : '\nDetails: $lastError';
    return 'Error: Could not connect to Google AI models.$detail';
  }

  // Helper method to clean and format the response text
  String _cleanResponseFormat(String text) {
    // Remove any markdown headers
    String cleaned = text.replaceAll(RegExp(r'#+\s+'), '');

    // Standardize bullet points to simple dashes
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*[\*\-]\s+', multiLine: true),
      '- ',
    );

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
