import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test_application_1/views/services/gemini_service.dart';
import '../../../helpers/api_test_helpers.dart';

void main() {
  setUpAll(setupApiTestKeys);
  final service = GeminiService();
  http.Response answer(String text) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
            'role': 'model',
          },
          'finishReason': 'STOP',
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  test(
    'Service is a singleton',
    () => expect(identical(service, GeminiService()), isTrue),
  );

  for (final plantRelated in [true, false]) {
    test(
      'Sends ${plantRelated ? "plant" : "general"} prompt and cleans response',
      () async {
        final requests = <http.Request>[];
        final result = await http.runWithClient(
          () => service.getAnswer(
            'Explain yellow leaves',
            isPlantRelated: plantRelated,
            preferredModel: 'test-model',
          ),
          () => MockClient((request) async {
            requests.add(request);
            return answer(
              '  ### Advice\n**Inspect** the _leaves_.\n* Check roots.\n\n\nKeep dry.  ',
            );
          }),
        );
        expect(
          result,
          'Advice\nInspect the leaves.\n- Check roots.\n\nKeep dry.',
        );
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, contains('models/test-model:generateContent'));
        expect(request.headers['x-goog-api-key'], 'test-gemini-key');
        final prompt =
            jsonDecode(request.body)['contents'][0]['parts'][0]['text']
                as String;
        expect(prompt, contains('Explain yellow leaves'));
        expect(
          prompt,
          contains(plantRelated ? 'plant disease-related' : 'Please answer'),
        );
      },
    );
  }

  test('Removes code blocks and inline formatting', () async {
    final result = await http.runWithClient(
      () => service.getAnswer('Question', preferredModel: 'test-model'),
      () => MockClient(
        (_) async => answer('Use `water`.\n```python\nunsafe()\n```\n**Done**'),
      ),
    );
    expect(result, 'Use water.\n\nDone');
  });

  test(
    'Requested model failure returns explicit error without fallback',
    () async {
      var count = 0;
      final result = await http.runWithClient(
        () => service.getAnswer('Question', preferredModel: 'test-model'),
        () => MockClient((_) async {
          count++;
          return http.Response(
            '{"error":{"message":"unavailable","status":"UNAVAILABLE","code":503}}',
            503,
          );
        }),
      );
      expect(count, 1);
      expect(result, startsWith('Error:'));
      expect(result, contains('model=test-model'));
    },
  );

  test(
    'Explicit fallback tries next model and returns successful answer',
    () async {
      final paths = <String>[];
      final result = await http.runWithClient(
        () => service.getAnswer(
          'Question',
          preferredModel: 'test-model',
          allowFallback: true,
        ),
        () => MockClient((request) async {
          paths.add(request.url.path);
          if (paths.length == 1) {
            return http.Response(
              '{"error":{"message":"unavailable","status":"UNAVAILABLE","code":503}}',
              503,
            );
          }
          return answer('Recovered answer');
        }),
      );
      expect(result, 'Recovered answer');
      expect(paths, hasLength(2));
      expect(paths.last, contains('gemma-3-27b-it'));
    },
  );

  test('Default model sequence reports error if every model fails', () async {
    final paths = <String>[];
    final result = await http.runWithClient(
      () => service.getAnswer('Question'),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('', 400);
      }),
    );
    expect(paths, hasLength(3));
    expect(paths[0], contains('gemma-3-27b-it'));
    expect(paths[1], contains('gemini-2.0-flash'));
    expect(paths[2], contains('gemini-1.5-flash'));
    expect(result, startsWith('Error: Could not connect'));
  });

  test('Empty model response does not count as successful answer', () async {
    final result = await http.runWithClient(
      () => service.getAnswer('Question', preferredModel: 'test-model'),
      () => MockClient((_) async => answer('')),
    );
    expect(result, startsWith('Error:'));
  });
}
