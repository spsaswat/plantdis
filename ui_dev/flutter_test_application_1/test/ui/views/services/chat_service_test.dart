import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_application_1/views/services/chat_service.dart'; 

void main() {
  group('ChatService', () {
    late ChatService chatService;

    setUp(() {
      chatService = ChatService();
      chatService.clearMessages(); // reset to initial state
    });

    test('initial message exists', () {
      expect(chatService.messages.length, 1);
      expect(chatService.messages.first, 'Hi! How can I help you?');
      expect(chatService.isUserMessage.first, false);
    });

    test('addMessage appends new user message', () {
      chatService.addMessage('Hello', true);

      expect(chatService.messages.last, 'Hello');
      expect(chatService.isUserMessage.last, true);
    });

    test('clearMessages resets to initial state', () {
      chatService.addMessage('Temp', true);
      chatService.clearMessages();

      expect(chatService.messages.length, 1);
      expect(chatService.messages.first, 'Hi! How can I help you?');
      expect(chatService.isUserMessage.first, false);
    });
  });
}
