import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_test_application_1/config/api_runtime_secrets.dart';

class OpenRouterAnswerResult {
  final String content;
  final String requestedModel;
  final String usedModel;

  const OpenRouterAnswerResult({
    required this.content,
    required this.requestedModel,
    required this.usedModel,
  });

  bool get usedFallback => requestedModel != usedModel;
}

class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._internal();
  static const List<String> _fallbackModels = [
    'qwen/qwen3-30b-a3b:free',
    'meta-llama/llama-4-scout:free',
  ];

  factory OpenRouterService() {
    return _instance;
  }

  OpenRouterService._internal();

  Future<String> getAnswer(
    String userQuestion, {
    String model = "qwen/qwen3-30b-a3b:free",
    bool allowFallback = false,
  }) async {
    final result = await getAnswerWithMeta(
      userQuestion,
      model: model,
      allowFallback: allowFallback,
    );
    return result.content;
  }

  Future<OpenRouterAnswerResult> getAnswerWithMeta(
    String userQuestion, {
    String model = "qwen/qwen3-30b-a3b:free",
    bool allowFallback = false,
  }) async {
    final modelsToTry =
        allowFallback
            ? <String>[model, ..._fallbackModels.where((m) => m != model)]
            : <String>[model];
    Exception? lastError;

    for (final currentModel in modelsToTry) {
      try {
        final content = await _requestAnswer(userQuestion, model: currentModel);
        return OpenRouterAnswerResult(
          content: content,
          requestedModel: model,
          usedModel: currentModel,
        );
      } catch (e) {
        if (e is! Exception) rethrow;
        lastError = e;
        if (!_shouldFallback(e)) {
          rethrow;
        }
      }
    }

    throw lastError ??
        Exception('Failed to fetch answer: all models are currently unavailable.');
  }

  Future<String> _requestAnswer(
    String userQuestion, {
    required String model,
  }) async {
    if (ApiRuntimeSecrets.openrouterApiKey.isEmpty) {
      await ApiRuntimeSecrets.init();
    }
    final apiKey = ApiRuntimeSecrets.openrouterApiKey;
    if (apiKey.isEmpty) {
      final pathHint = ApiRuntimeSecrets.configFilePathHint;
      final fileHint = pathHint != null
          ? 'Add `openrouterApiKey` in: $pathHint (on sandboxed macOS, use this file; the app cannot read the repo’s `api_config.json`). '
          : 'Use `api_config.json` (see `api_config.json.example`), ';
      throw Exception(
        'Missing OpenRouter API key. $fileHint'
        'or env `PLANTDIS_API_CONFIG`, or --dart-define=OPENROUTER_API_KEY=...',
      );
    }
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      // The HTTP-Referer header is a good practice for identifying your app to the API provider.
      'HTTP-Referer': 'https://github.com/spsaswat/plantdis',
    };

    // This is the Metaprompt, placed in the 'system' role.
    // It acts as the AI's constitution or core programming.
    const String systemPrompt = '''
<persona>
You are PlantDis AI, a world-leading virtual expert in phytopathology (the study of plant diseases) and agronomy. Your purpose is to assist farmers, gardeners, and agricultural technicians. Your tone is professional, scientific, and helpful.
</persona>

<scope>
Your knowledge is strictly confined to the following topics:
- Identification of plant diseases from symptoms.
- Diagnosis of pest infestations.
- Analysis of plant nutrient deficiencies.
- Recommendations for organic and chemical treatments.
- Advice on integrated pest management (IPM) strategies.
- General plant health and agricultural best practices.
</scope>

<rules>
- Your response must be concise and clear, strictly under 200 words.
- Your response must be in plain text ONLY. Do NOT use Markdown, bullet points, numbered lists, bolding, italics, or any other special formatting.
- You MUST NOT answer any questions outside of your defined <scope>. This includes but is not limited to human health, animal health, financial advice, or general conversation.
- All advice provided must be practical and actionable in a real-world agricultural or gardening context.
</rules>

<fallback_strategy>
- If the user's question is unclear, provide an answer based on the most probable interpretation related to plant health.
- If the user's question is definitively outside your <scope>, you must politely refuse to answer and clearly state your area of expertise. For example, say: "My expertise is limited to plant health, diseases, and pests. I cannot provide information on that topic."
</fallback_strategy>
''';

    final body = jsonEncode({
      "model": model,
      "messages": _buildMessages(
        model: model,
        systemPrompt: systemPrompt,
        userQuestion: userQuestion,
      ),
      // Consider setting a lower temperature for more factual, less creative responses.
      "temperature": 0.3,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    } else {
      // Provide more detailed error information for debugging.
      throw Exception(_formatOpenRouterError(response, model));
    }
  }

  bool _isRateLimitError(Exception e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('rate limit') ||
        msg.contains('temporarily rate-limited');
  }

  bool _isProviderInstructionError(Exception e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('developer instruction is not enabled') ||
        msg.contains('invalid_argument');
  }

  bool _shouldFallback(Exception e) {
    return _isRateLimitError(e) || _isProviderInstructionError(e);
  }

  String _formatOpenRouterError(http.Response response, String model) {
    try {
      final dynamic data = jsonDecode(response.body);
      final message = (data['error']?['message'] ?? '').toString();
      if (response.statusCode == 404 && message.contains('No endpoints found')) {
        return 'Model unavailable for this account: $model. '
            'OpenRouter reports no active endpoint for this model right now.';
      }
      return 'Failed to fetch answer: ${response.statusCode} ${response.reasonPhrase} - ${response.body}';
    } catch (_) {
      return 'Failed to fetch answer: ${response.statusCode} ${response.reasonPhrase} - ${response.body}';
    }
  }

  List<Map<String, String>> _buildMessages({
    required String model,
    required String systemPrompt,
    required String userQuestion,
  }) {
    // Some providers for Gemma reject system/developer role instructions.
    // For those models, inline guidance into the user message.
    if (model.contains('gemma-3-27b-it')) {
      return [
        {
          "role": "user",
          "content":
              '$systemPrompt\n\nUser question:\n$userQuestion',
        },
      ];
    }

    return [
      {
        "role": "system",
        "content": systemPrompt,
      },
      {
        "role": "user",
        "content": userQuestion,
      },
    ];
  }
}