import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._internal();

  final String _apiKey = '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';

  factory OpenRouterService() {
    return _instance;
  }

  OpenRouterService._internal();

  Future<String> getAnswer(String prompt, {String model = "qwen/qwen3-30b-a3b:free"}) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/spsaswat/plantdis',

    };

    final String fullPrompt = '''
Please answer the user's question based on your expert knowledge, focusing exclusively on plants, plant health issues, plant diseases, or pest infestations.
Important requirements:
- Keep your response concise and clear, under 200 words.
- Use plain text only. Do NOT use bullet points, markdown, or any special formatting.
- Do NOT discuss topics unrelated to plants, agriculture, or pest management.
- Provide practical and actionable advice suitable for farmers, gardeners, or agricultural technicians.
If the user's question is unclear or incomplete, provide your best guess based on typical plant issues.
Always assume the question is related to a real-world agricultural or gardening context.
User question: $prompt
''';

    final body = jsonEncode({
      "model": model,
      "messages": [
        {
          "role": "user",
          "content": fullPrompt,
        }
      ],
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    } else {
      throw Exception('Failed to fetch answer: ${response.statusCode} ${response.reasonPhrase}');
    }
  }
}
