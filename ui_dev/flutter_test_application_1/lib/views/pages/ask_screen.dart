import 'package:flutter/material.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _questionController = TextEditingController();
  String _response = "";
  bool _isLoading = false;

  // Set questions
  final List<String> _predefinedQuestions = [
    "How do I identify common plant diseases?",
    "What are the best practices for watering plants?",
    "How can I treat fungal infections in plants?",
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = "";
    });

    try {
      // TODO: Backended API call implementation
      await Future.delayed(const Duration(seconds: 2));

      // Simulated response
      setState(() {
        _response =
            "This is a simulated response to: $question\n\n"
            "In a real implementation, this would come from the Gemini API. "
            "The response would provide helpful information about plant care or disease identification "
            "based on the user's question.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = "Error: Failed to get response. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ask Plant Expert"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select a question or ask your own:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // preset questions
            ...List.generate(
              _predefinedQuestions.length,
              (index) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    _questionController.text = _predefinedQuestions[index];
                    _askQuestion(_predefinedQuestions[index]);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_predefinedQuestions[index]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // question input
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: "Type your question here...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _askQuestion(_questionController.text),
                ),
              ),
              maxLines: 3,
              minLines: 1,
            ),

            const SizedBox(height: 24),

            // reply region
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                          child: Text(
                            _response.isEmpty
                                ? "Your answer will appear here..."
                                : _response,
                            style: TextStyle(
                              color:
                                  _response.isEmpty
                                      ? Colors.grey.shade600
                                      : Colors.black,
                            ),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
