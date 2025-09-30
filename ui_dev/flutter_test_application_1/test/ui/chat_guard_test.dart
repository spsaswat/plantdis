import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/chat/chat_guard.dart';

void main() {
  group('ChatGuard relevance scoring', () {
    test('returns high score for clear plant disease query', () {
      final score = ChatGuard.getRelevanceScore('tomato blight treatment');
      expect(score, greaterThan(0.7));
      expect(ChatGuard.isOutOfScope('tomato blight treatment'), isFalse);
    });

    test('returns very low score for unrelated query', () {
      final score = ChatGuard.getRelevanceScore('football world cup results');
      expect(score, lessThan(0.4));
      expect(ChatGuard.isOutOfScope('football world cup results'), isTrue);
    });

    test('returns medium score for borderline keyword', () {
      final score = ChatGuard.getRelevanceScore('growth');
      expect(score, equals(0.8));
    });

    test('returns neutral score for empty text', () {
      final score = ChatGuard.getRelevanceScore('');
      expect(score, closeTo(0.5, 0.01));
    });

    test('detects pattern match and boosts score', () {
      final score = ChatGuard.getRelevanceScore('how to cure plant disease');
      expect(score, greaterThan(0.8));
    });
  });

  group('ChatGuard out-of-scope replies', () {
    test('uses clearlyOffTopicReply for very low score', () {
      final reply = ChatGuard.getOutOfScopeReply('any-model', 0.1);
      expect(reply, equals(ChatGuard.clearlyOffTopicReply));
    });

    test('uses borderlineReply for medium score', () {
      final reply = ChatGuard.getOutOfScopeReply('any-model', 0.2);
      expect(reply, equals(ChatGuard.borderlineReply));
    });

    test('uses outOfScopeReply for model-specific cases', () {
      final reply = ChatGuard.getOutOfScopeReply('gpt-3.5-turbo', 0.5);
      expect(reply, equals(ChatGuard.outOfScopeReply));
    });

    test('defaults to outOfScopeReply for unknown model', () {
      final reply = ChatGuard.getOutOfScopeReply('unknown-model', 0.5);
      expect(reply, equals(ChatGuard.outOfScopeReply));
    });
  });

  group('ChatGuard debug info', () {
    test('includes score and matched words', () {
      final debug = ChatGuard.getDebugInfo('yellow leaves on tomato');
      expect(debug, contains('Score'));
      expect(debug, contains('tomato'));
      expect(debug, contains('leaves'));
    });

    test('shows no matches for unrelated text', () {
      final debug = ChatGuard.getDebugInfo('football world cup');
      expect(debug, contains('Score'));
      expect(debug.contains('tomato'), isFalse);
      expect(debug.contains('leaf'), isFalse);
    });
  });
}
