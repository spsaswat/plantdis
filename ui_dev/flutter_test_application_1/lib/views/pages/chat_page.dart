import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final List<String> _messages = ["Hi ! How can I help you?"];
  final List<bool> _isUserMessage = [false]; // false for AI, true for user
  bool _isLoading = false;
  
  // Initialize Gemini service
  final GeminiService _geminiService = GeminiService();

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
      // Call Gemini API to get an answer
      final answer = await _geminiService.getAnswer(text);
      
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
