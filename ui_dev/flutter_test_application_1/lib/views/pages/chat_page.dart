import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/openrouter_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final List<String> _messages = ["Hi! How can I help you?"];
  final List<bool> _isUserMessage = [false]; // false for AI, true for user
  bool _isLoading = false;
  late String _selectedModel;


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
                        Text("Select Model:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                            items: _models.map<DropdownMenuItem<String>>((String model) {
                              return DropdownMenuItem<String>(
                                value: model,
                                child: Text(model),
                              );
                            }).toList(),
                          ),
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
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoading && index == _messages.length) {
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
                                backgroundColor: index >= _isUserMessage.length || !_isUserMessage[index] 
                                    ? Colors.red 
                                    : Colors.green,
                                child: index >= _isUserMessage.length || !_isUserMessage[index] 
                                    ? Text('A') 
                                    : Text('U'),
                              ),
                              title: Text(_messages[index]),
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

  void _handleSubmitted(String text) async {
    // Add user message
    setState(() {
      _messages.add(text);
      _isUserMessage.add(true);
      _controller.clear();
      _isLoading = true;  // Show loading state
    });
    
    try {
      String answer;

      if (_selectedModel.startsWith("gemini")) {
        answer = await _geminiService.getAnswer(text);
      }else if (_selectedModel.startsWith("openrouter")) {
        String modelName;
        if (_selectedModel == "openrouter-Llama4-Scout") {
          modelName = "meta-llama/llama-4-scout:free";
        } else if (_selectedModel == "openrouter-Qwen3--30b") {
          modelName = "qwen/qwen3-30b-a3b:free";
        } else {
          modelName = "mistralai/mistral-7b-instruct"; // fallback
        }
        answer = await _openRouterService.getAnswer(text, model: modelName);
      } else {
        answer = "Unknown model selected.";
      }
      
      // Add AI response
      setState(() {
        _messages.add(answer);
        _isUserMessage.add(false);
        _isLoading = false;  // Hide loading state
      });
    } catch (e) {
      // Handle errors
      setState(() {
        _messages.add("Sorry, an error occurred: $e");
        _isUserMessage.add(false);
        _isLoading = false;  // Hide loading state
      });
    }
  }
}
