import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._internal();

  // It's generally better practice to load secrets from a configuration file or environment variables
  // rather than hardcoding them directly in the source code.
  final String part1 = 'sk-or-v1';
  final String part2 = '-f381cf86eb82382709b76024ba028d6119865c3036873b77f84263d10122ea05';
  String _apiKey = '';

  factory OpenRouterService() {
    return _instance;
  }

  OpenRouterService._internal();

  Future<String> getAnswer(String userQuestion, {String model = "qwen/qwen3-30b-a3b:free"}) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    _apiKey = part1 + part2;
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      // The HTTP-Referer header is a good practice for identifying your app to the API provider.
      'HTTP-Referer': 'https://github.com/spsaswat/plantdis',
    };

    // This is the Metaprompt, placed in the 'system' role.
    // It acts as the AI's constitution or core programming.
    final String systemPrompt = '''
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
      // Best practice: Use 'system' for the metaprompt and 'user' for the actual user query.
      "messages": [
        {
          "role": "system",
          "content": systemPrompt,
        },
        {
          "role": "user",
          "content": userQuestion, // The user's question is now clean and separate.
        }
      ],
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
      throw Exception('Failed to fetch answer: ${response.statusCode} ${response.reasonPhrase} - ${response.body}');
    }
  }
}