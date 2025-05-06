import 'package:flutter/material.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  
  factory ChatService() {
    return _instance;
  }
  
  ChatService._internal();
  
  final List<String> messages = ["Hi! How can I help you?"];
  final List<bool> isUserMessage = [false]; // false for AI，true for user
  
  void addMessage(String message, bool isUser) {
    messages.add(message);
    isUserMessage.add(isUser);
  }
  
  void clearMessages() {
    messages.clear();
    isUserMessage.clear();
    // add initial welcome message
    messages.add("Hi! How can I help you?");
    isUserMessage.add(false);
  }
}