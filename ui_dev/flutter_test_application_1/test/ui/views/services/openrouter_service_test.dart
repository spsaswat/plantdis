import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test_application_1/views/services/openrouter_service.dart';
import '../../../helpers/api_test_helpers.dart';

void main() {
  setUpAll(setupApiTestKeys);
  final service = OpenRouterService();
  http.Response answer(String text) => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {'content': text},
        },
      ],
    }),
    200,
  );

  test('Service is a singleton', () {
    expect(identical(service, OpenRouterService()), isTrue);
  });

  test(
    'Sends authenticated question and plant scope instructions; trims response',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return answer('  Inspect the leaves.  ');
      });
      final result = await http.runWithClient(
        () => service.getAnswer('Why are leaves yellow?', model: 'test/model'),
        () => client,
      );
      expect(result, 'Inspect the leaves.');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://openrouter.ai/api/v1/chat/completions',
      );
      expect(request.headers['authorization'], 'Bearer test-openrouter-key');
      final body = jsonDecode(request.body);
      expect(body['model'], 'test/model');
      expect(body['messages'][0]['role'], 'system');
      expect(body['messages'][0]['content'], contains('plant diseases'));
      expect(body['messages'][0]['content'], contains('human health'));
      expect(body['messages'][0]['content'], contains('plain text ONLY'));
      expect(body['messages'][1], {
        'role': 'user',
        'content': 'Why are leaves yellow?',
      });
    },
  );

  for (final question in [
    '',
    'Help',
    '叶片为什么变黄？',
    'leaf & root <test>',
    'Symptoms ' * 200,
  ]) {
    test(
      'Serializes question of length ${question.length} without altering it',
      () async {
        final client = MockClient((request) async {
          expect(jsonDecode(request.body)['messages'][1]['content'], question);
          return answer('Recorded response');
        });
        expect(
          await http.runWithClient(
            () => service.getAnswer(question),
            () => client,
          ),
          'Recorded response',
        );
      },
    );
  }

  test('Gemma instructions are included in the user message', () async {
    final client = MockClient((request) async {
      final messages = jsonDecode(request.body)['messages'] as List;
      expect(messages, hasLength(1));
      expect(messages.single['role'], 'user');
      expect(
        messages.single['content'],
        contains('User question:\nTreat rust?'),
      );
      expect(messages.single['content'], contains('plant health'));
      return answer('Remove infected leaves.');
    });
    await http.runWithClient(
      () =>
          service.getAnswer('Treat rust?', model: 'google/gemma-3-27b-it:free'),
      () => client,
    );
  });

  test('API errors throw and never masquerade as an answer', () async {
    var count = 0;
    final client = MockClient((_) async {
      count++;
      return http.Response('{"error":{"message":"invalid credentials"}}', 401);
    });
    await expectLater(
      http.runWithClient(
        () => service.getAnswer('Treat rust?', allowFallback: true),
        () => client,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('401'),
        ),
      ),
    );
    expect(count, 1);
  });

  for (final status in [429, 400]) {
    test(
      'Explicit fallback handles ${status == 429 ? "rate limit" : "provider instruction rejection"} and records model',
      () async {
        final models = <String>[];
        final client = MockClient((request) async {
          models.add(jsonDecode(request.body)['model'] as String);
          if (models.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'message':
                      status == 429
                          ? 'rate limit'
                          : 'developer instruction is not enabled',
                },
              }),
              status,
            );
          }
          return answer('Fallback answer');
        });
        final result = await http.runWithClient(
          () => service.getAnswerWithMeta(
            'Question',
            model: 'test/primary',
            allowFallback: true,
          ),
          () => client,
        );
        expect(models, ['test/primary', 'qwen/qwen3-30b-a3b:free']);
        expect(result.content, 'Fallback answer');
        expect(result.requestedModel, 'test/primary');
        expect(result.usedModel, models.last);
        expect(result.usedFallback, isTrue);
      },
    );
  }

  test('Fallback stays disabled unless requested', () async {
    var count = 0;
    await expectLater(
      http.runWithClient(
        () => service.getAnswer('Question'),
        () => MockClient((_) async {
          count++;
          return http.Response('rate limit', 429);
        }),
      ),
      throwsA(isA<Exception>()),
    );
    expect(count, 1);
  });

  test('Missing model endpoint reports a useful error', () async {
    await expectLater(
      http.runWithClient(
        () => service.getAnswer('Question', model: 'test/missing'),
        () => MockClient(
          (_) async =>
              http.Response('{"error":{"message":"No endpoints found"}}', 404),
        ),
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('test/missing'),
        ),
      ),
    );
  });

  test(
    'Malformed successful response fails instead of returning an error as an answer',
    () async {
      await expectLater(
        http.runWithClient(
          () => service.getAnswer('Question'),
          () => MockClient((_) async => http.Response('', 200)),
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
