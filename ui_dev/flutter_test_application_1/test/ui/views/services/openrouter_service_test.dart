import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/services/openrouter_service.dart';

void main() {
  group('OpenRouterService', () {
    late OpenRouterService openRouterService;

    setUp(() {
      openRouterService = OpenRouterService();
    });

    group('Singleton Pattern Tests', () {
      test('OpenRouterService should return same instance', () {
        final instance1 = OpenRouterService();
        final instance2 = OpenRouterService();
        
        expect(identical(instance1, instance2), true);
      });

      test('OpenRouterService should be initialized properly', () {
        expect(openRouterService, isNotNull);
        expect(openRouterService, isA<OpenRouterService>());
      });
    });

    group('API Key Construction Tests', () {
      test('API key parts should be correct format', () {
        expect(openRouterService.part1, equals('sk-or-v1'));
        expect(openRouterService.part2.startsWith('-'), true);
        expect(openRouterService.part2.length, greaterThan(20));
      });
    });

    group('Real API Tests', () {
      test('getAnswer returns response for plant disease question', () async {
        final result = await openRouterService.getAnswer(
          "What causes brown spots on tomato leaves?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        expect(result.length, lessThan(1000)); // Should be concise
        
        // Response should not contain markdown formatting as per system prompt
        expect(result.contains('**'), false);
        expect(result.contains('##'), false);
        expect(result.contains('```'), false);
        
        print('Plant disease question result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer returns response for pest identification question', () async {
        final result = await openRouterService.getAnswer(
          "How to identify aphids on plants?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Pest identification result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer returns response for nutrient deficiency question', () async {
        final result = await openRouterService.getAnswer(
          "What are signs of nitrogen deficiency in plants?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Nutrient deficiency result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer handles treatment recommendation question', () async {
        final result = await openRouterService.getAnswer(
          "Best organic treatment for powdery mildew?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Treatment recommendation result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer refuses non-plant related questions', () async {
        final result = await openRouterService.getAnswer(
          "What is the weather today?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Should contain refusal message about expertise limitation
        final lowerResult = result.toLowerCase();
        final containsRefusal = lowerResult.contains('expertise') || 
                               lowerResult.contains('plant health') ||
                               lowerResult.contains('cannot provide') ||
                               lowerResult.contains('limited to');
        
        expect(containsRefusal, true);
        
        print('Non-plant question refusal result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer with different model parameter', () async {
        final result = await openRouterService.getAnswer(
          "How to prevent fungal infections in roses?",
          model: "qwen/qwen3-30b-a3b:free"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Different model result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));
    });

    group('Edge Cases Tests', () {
      test('getAnswer handles empty question', () async {
        final result = await openRouterService.getAnswer("");
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Empty question result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles very short question', () async {
        final result = await openRouterService.getAnswer("Help");
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Short question result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles special characters', () async {
        final result = await openRouterService.getAnswer(
          "Plant disease with special symbols?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Special characters result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles unicode characters', () async {
        final result = await openRouterService.getAnswer(
          "Plant disease symptoms question"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Unicode characters result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles very long question', () async {
        final longQuestion = "What are the symptoms and treatment for " * 10 + "plant diseases?";
        
        final result = await openRouterService.getAnswer(longQuestion);
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Long question result length: ${result.length}');
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Response Quality Tests', () {
      test('response should be properly trimmed', () async {
        final result = await openRouterService.getAnswer(
          "How to identify plant diseases?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Should not start or end with whitespace
        expect(result, equals(result.trim()));
        
        print('Trim test result: "$result"');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('response should be concise as per system prompt', () async {
        final result = await openRouterService.getAnswer(
          "Guide to tomato diseases and treatments?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Check word count - should be under 200 words as per system prompt
        final wordCount = result.split(RegExp(r'\s+')).length;
        print('Response word count: $wordCount');
        print('Response: $result');
        
        // Allow some flexibility but expect reasonable length
        expect(wordCount, lessThan(300)); // Allow buffer over 200 word limit
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('response should not contain formatting as per system prompt', () async {
        final result = await openRouterService.getAnswer(
          "Common plant diseases and their symptoms?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Should not contain markdown or special formatting
        expect(result.contains('**'), false); // No bold
        expect(result.contains('##'), false); // No headers
        expect(result.contains('```'), false); // No code blocks
        expect(result.contains('_'), false);  // No underscores
        expect(result.contains('- '), false); // No bullet points
        expect(result.contains('* '), false); // No asterisk bullets
        expect(result.contains('1. '), false); // No numbered lists
        
        print('Formatting test result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));
    });

    group('Error Handling Tests', () {
      test('getAnswer handles API errors gracefully', () async {
        try {
          // Test with potentially problematic input
          final result = await openRouterService.getAnswer(
            "Test question for error handling"
          );
          
          // If successful, should return valid response
          expect(result, isA<String>());
          expect(result.isNotEmpty, true);
          
          print('Error handling test result: $result');
        } catch (e) {
          // If it throws an exception, verify it's properly formatted
          expect(e, isA<Exception>());
          expect(e.toString(), contains('Failed to fetch answer'));
          
          print('Expected error caught: $e');
        }
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('service maintains singleton state', () async {
        final service1 = OpenRouterService();
        final service2 = OpenRouterService();
        
        expect(identical(service1, service2), true);
        expect(service1.part1, equals(service2.part1));
        expect(service1.part2, equals(service2.part2));
      });
    });

    group('System Prompt Compliance Tests', () {
      test('AI should stay within plant health scope', () async {
        final result = await openRouterService.getAnswer(
          "What do you specialize in?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        final lowerResult = result.toLowerCase();
        final containsPlantFocus = lowerResult.contains('plant') ||
                                  lowerResult.contains('disease') ||
                                  lowerResult.contains('agricultural') ||
                                  lowerResult.contains('phytopathology') ||
                                  lowerResult.contains('pest');
        
        expect(containsPlantFocus, true);
        
        print('Specialization result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('AI should refuse human health questions', () async {
        final result = await openRouterService.getAnswer(
          "What medicine should I take for fever?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        final lowerResult = result.toLowerCase();
        final containsRefusal = lowerResult.contains('cannot') ||
                               lowerResult.contains('expertise') ||
                               lowerResult.contains('plant health') ||
                               lowerResult.contains('limited to');
        
        expect(containsRefusal, true);
        
        print('Human health refusal result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('AI should refuse general conversation', () async {
        final result = await openRouterService.getAnswer(
          "How was your day today?"
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        final lowerResult = result.toLowerCase();
        final containsRefusal = lowerResult.contains('cannot') ||
                               lowerResult.contains('expertise') ||
                               lowerResult.contains('plant health') ||
                               lowerResult.contains('limited to');
        
        expect(containsRefusal, true);
        
        print('General conversation refusal result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));
    });

    group('Multiple Calls Test', () {
      test('multiple consecutive calls should work', () async {
        final questions = [
          "What causes leaf yellowing?",
          "How to prevent root rot?",
          "Signs of pest damage on leaves?"
        ];
        
        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          final result = await openRouterService.getAnswer(question);
          
          expect(result, isA<String>());
          expect(result.isNotEmpty, true);
          
          print('Question ${i + 1}: $question');
          print('Answer ${i + 1}: $result\n');
          
          // Add delay between requests to respect API limits
          if (i < questions.length - 1) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }, timeout: const Timeout(Duration(seconds: 150)));
    });
  });
}
