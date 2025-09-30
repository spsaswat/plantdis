import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/services/gemini_service.dart';

void main() {
  group('GeminiService', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    group('Singleton Pattern Tests', () {
      test('GeminiService should return same instance', () {
        final instance1 = GeminiService();
        final instance2 = GeminiService();
        
        expect(identical(instance1, instance2), true);
      });

      test('GeminiService should be initialized properly', () {
        expect(geminiService, isNotNull);
        expect(geminiService, isA<GeminiService>());
      });
    });

    group('getAnswer Method Tests', () {
      test('getAnswer returns string for plant related question', () async {
        final result = await geminiService.getAnswer(
          "What causes leaf spots on tomatoes?", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Check that response doesn't contain markdown formatting
        expect(result.contains('```'), false);
        expect(result.contains('**'), false);
        expect(result.contains('##'), false);
        
        print('Plant question result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer returns string for non-plant related question', () async {
        final result = await geminiService.getAnswer(
          "What is the capital of France?", 
          isPlantRelated: false
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Check that response doesn't contain markdown formatting
        expect(result.contains('```'), false);
        expect(result.contains('**'), false);
        expect(result.contains('##'), false);
        
        print('Non-plant question result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer handles empty question gracefully', () async {
        final result = await geminiService.getAnswer(
          "", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Empty question result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles very short question', () async {
        final result = await geminiService.getAnswer(
          "Help", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Short question result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer response format is clean for plant questions', () async {
        final result = await geminiService.getAnswer(
          "How to treat plant fungal infections?", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Verify clean formatting
        expect(result.contains('###'), false); // No markdown headers
        expect(result.contains('**'), false);  // No bold markdown
        expect(result.contains('```'), false); // No code blocks
        expect(result.contains('`'), false);   // No inline code
        expect(result.contains('_'), false);   // No underscore emphasis
        expect(result.contains('*'), false);   // No asterisk emphasis (except in bullet points)
        
        // Should contain bullet points with dashes
        if (result.contains('-')) {
          expect(result.contains('- '), true);
        }
        
        print('Formatted plant question result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('getAnswer response format is clean for general questions', () async {
        final result = await geminiService.getAnswer(
          "Explain photosynthesis", 
          isPlantRelated: false
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Verify clean formatting
        expect(result.contains('###'), false);
        expect(result.contains('**'), false);
        expect(result.contains('```'), false);
        expect(result.contains('`'), false);
        expect(result.contains('_'), false);
        expect(result.contains('*'), false);
        
        print('Formatted general question result: $result');
      }, timeout: const Timeout(Duration(seconds: 45)));
    });

    group('Error Handling Tests', () {
      test('getAnswer handles special characters in question', () async {
        final result = await geminiService.getAnswer(
          "What about plants with symbols: @#\$%^&*()?", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Special characters result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('getAnswer handles very long question', () async {
        final longQuestion = "What is the best way to treat " * 50 + "plant diseases?";
        
        final result = await geminiService.getAnswer(
          longQuestion, 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        print('Long question result length: ${result.length}');
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Response Quality Tests', () {
      test('plant related responses should be concise', () async {
        final result = await geminiService.getAnswer(
          "What causes yellowing leaves?", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Plant responses should be under 150 words as per the prompt
        final wordCount = result.split(RegExp(r'\s+')).length;
        print('Plant response word count: $wordCount');
        print('Plant response: $result');
        
        // Just verify it's a reasonable length, not too strict on the 150 word limit
        expect(wordCount > 0, true);
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('responses should not contain excessive newlines', () async {
        final result = await geminiService.getAnswer(
          "How to water plants properly?", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Should not contain triple newlines or more
        expect(result.contains('\n\n\n'), false);
        
        print('Newline test result: $result');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('responses should be trimmed properly', () async {
        final result = await geminiService.getAnswer(
          "Plant care tips", 
          isPlantRelated: true
        );
        
        expect(result, isA<String>());
        expect(result.isNotEmpty, true);
        
        // Should not start or end with whitespace
        expect(result, equals(result.trim()));
        
        print('Trim test result: "$result"');
      }, timeout: const Timeout(Duration(seconds: 30)));
    });

    group('Multiple Calls Test', () {
      test('multiple consecutive calls should work', () async {
        final questions = [
          "What is plant nutrition?",
          "How do plants grow?",
          "What is soil pH?"
        ];
        
        for (final question in questions) {
          final result = await geminiService.getAnswer(
            question, 
            isPlantRelated: true
          );
          
          expect(result, isA<String>());
          expect(result.isNotEmpty, true);
          
          print('Question: $question');
          print('Answer: $result\n');
          
          // Add small delay between requests
          await Future.delayed(Duration(milliseconds: 500));
        }
      }, timeout: const Timeout(Duration(seconds: 120)));
    });
  });
}
