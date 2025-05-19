import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/openrouter_service.dart';
import '../../chat/chat_guard.dart'; // Import ChatGuard
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  late String _selectedModel;
  bool _chatGuardEnabled = false; // Start with ChatGuard OFF 

  // Get the instance of ChatService
  final ChatService _chatService = ChatService();

  final List<String> _models = [
    "gemini-1.5-pro",
    "openrouter-Llama4-Scout",
    "openrouter-Qwen3--30b",
  ];

  // Initialize Gemini service
  final GeminiService _geminiService = GeminiService();
  // Initialize openrouter service
  final OpenRouterService _openRouterService = OpenRouterService();

  @override
  void initState() {
    super.initState();
    _selectedModel = _models[0];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FractionallySizedBox(
              widthFactor: constraints.maxWidth > 500 ? 0.5 : 1,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Text(
                          "Select Model:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _selectedModel,
                            isExpanded: true,
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedModel = newValue;
                                });
                              }
                            },
                            items: _models.map<DropdownMenuItem<String>>((
                              String model,
                            ) {
                              return DropdownMenuItem<String>(
                                value: model,
                                child: Text(model),
                              );
                            }).toList(),
                          ),
                        ),
                        // Spider/ChatGuard button
                        IconButton(
                          icon: Icon(
                            Icons.bug_report,
                            color: _chatGuardEnabled ? Colors.green : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _chatGuardEnabled = !_chatGuardEnabled;
                            });
                          },
                          tooltip: 'Toggle ChatGuard filtering',
                        ),
                        // Clear button
                        IconButton(
                          icon: Icon(Icons.delete_outline),
                          onPressed: _clearChat,
                          tooltip: 'Clear chat history',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 8,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _chatService.messages.length +
                              (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoading &&
                                index == _chatService.messages.length) {
                              // Show loading indicator
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: Text('A'),
                                ),
                                title: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Thinking...'),
                                  ],
                                ),
                              );
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    index >= _chatService.isUserMessage.length ||
                                            !_chatService.isUserMessage[index]
                                        ? Colors.red
                                        : Colors.green,
                                child:
                                    index >= _chatService.isUserMessage.length ||
                                            !_chatService.isUserMessage[index]
                                        ? Text('A')
                                        : Text('U'),
                              ),
                              title: Text(_chatService.messages[index]),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Type a message...',
                                ),
                                onSubmitted: (text) {
                                  if (text.isNotEmpty && !_isLoading) {
                                    _handleSubmitted(text);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                              icon: Icon(Icons.send),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      if (_controller.text.isNotEmpty) {
                                        _handleSubmitted(_controller.text);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Add clear chat content function
  void _clearChat() {
    setState(() {
      _chatService.clearMessages();
    });
  }

  void _handleSubmitted(String text) async {
    // Add user message
    setState(() {
      _chatService.addMessage(text, true);
      _controller.clear();
      _isLoading = true; // Show loading state
    });

    try {
      // Only apply ChatGuard filtering when enabled
      if (_chatGuardEnabled) {
        // Check if the message is on-topic using ChatGuard
        double relevanceScore = ChatGuard.getRelevanceScore(text);

        if (ChatGuard.isOutOfScope(text)) {
          // Message is off-topic, show the appropriate response
          setState(() {
            _chatService.addMessage(
              ChatGuard.getOutOfScopeReply(_selectedModel, relevanceScore),
              false,
            );
            _isLoading = false; // Hide loading state
          });
          return; // Exit early - don't call the LLM
        }
      }

      // Proceed with normal flow - message is on-topic or ChatGuard is disabled
      String answer;

      if (_selectedModel.startsWith("gemini")) {
        // Pass ChatGuard status to GeminiService
        // When ChatGuard is enabled, treat as plant-related question
        // When ChatGuard is disabled, treat as general question
        answer = await _geminiService.getAnswer(text, isPlantRelated: _chatGuardEnabled);
      } else if (_selectedModel.startsWith("openrouter")) {
        String modelName;
        if (_selectedModel == "openrouter-Llama4-Scout") {
          modelName = "meta-llama/llama-4-scout:free";
        } else if (_selectedModel == "openrouter-Qwen3--30b") {
          modelName = "qwen/qwen3-30b-a3b:free";
        } else {
          modelName = "qwen/qwen3-30b-a3b:free"; // fallback
        }
        answer = await _openRouterService.getAnswer(text, model: modelName);
      } else {
        answer = "Unknown model selected.";
      }

      // Add AI response
      setState(() {
        _chatService.addMessage(answer, false);
        _isLoading = false; // Hide loading state
      });
    } catch (e) {
      // Handle errors
      setState(() {
        _chatService.addMessage("Sorry, an error occurred: $e", false);
        _isLoading = false; // Hide loading state
      });
    }
  }
}
