// Main chat screen for the AI finance assistant. This is where users interact with the AI.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Stateless widget for the AI chat screen.
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

// State class for managing the chat screen's dynamic data.
class _AIChatScreenState extends State<AIChatScreen> {
  // Controller for the text input field.
  final TextEditingController _controller = TextEditingController();
  // List to store chat messages (user and assistant).
  final List<Map<String, dynamic>> _messages = [];
  // Controller for scrolling the chat list.
  final ScrollController _scrollController = ScrollController();
  // Toggle for GenZ mode (changes AI response style).
  bool genZMode = false;
  // Flag to show loading indicator during API calls.
  bool isLoading = false;

  // Sends the user's message to the LLM API and handles the response.
  Future<void> _sendToLLM(String message) async {
    // Show loading state and add user message to the chat.
    setState(() {
      isLoading = true;
      _messages.add({"role": "user", "content": message});
    });

    // API endpoint for the LLM (OpenRouter in this case).
    final uri = Uri.parse("https://openrouter.ai/api/v1/chat/completions");
    // Headers for the API request, including auth and metadata.
    final headers = {
      "Authorization":
          "Bearer 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",
      "Content-Type": "application/json",
      "HTTP-Referer": "https://your-finance-app.com",
      "X-Title": "FinSight",
    };

    // Customize prompt based on GenZ mode for a more casual response style.
    final prompt = genZMode
        ? "Respond like a Gen-Z finance friend without markdown text and not long answers who knows money vibes 💸. Don't go too overboard but still explain in genz/alpha way. Ensure no markdown formatting. Don't have the messages be too long, be reasonable:\n$message"
        : message;

    // Prepare the request body with the model and message.
    final body = jsonEncode({
      "model": "meta-llama/llama-3.2-1b-instruct:free",
      "messages": [
        {"role": "user", "content": prompt}
      ]
    });

    // Send the POST request to the API.
    final response = await http.post(uri, headers: headers, body: body);

    // Handle the API response.
    if (response.statusCode == 200) {
      // Parse the response and extract the AI's reply.
      final result = jsonDecode(response.body);
      final reply = result['choices'][0]['message']['content'];

      // Add the AI's response to the chat.
      setState(() {
        _messages.add({"role": "assistant", "content": reply});
      });
    } else {
      // Show an error message if the API call fails.
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": "Oops, something went wrong. Try again later."
        });
      });
    }

    // Reset loading state.
    setState(() {
      isLoading = false;
    });

    // Clear the input field after sending.
    _controller.clear();
    
    // Auto-scroll to the bottom of the chat after adding a new message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Builds the UI for the chat screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark background for the app's aesthetic.
      backgroundColor: const Color(0xFF2B3A55),
      // App bar with title and GenZ mode toggle.
      appBar: AppBar(
        title: const Text(
          "AI Finance Assistant",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B3A55),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text(
                  "GenZ Mode",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                // Switch to toggle GenZ mode.
                Switch(
                  value: genZMode,
                  onChanged: (val) => setState(() => genZMode = val),
                  activeColor: const Color(0xFFE5BA73),
                  activeTrackColor: Colors.white.withOpacity(0.3),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome container shown when there are no messages.
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: const Color(0xFFE5BA73),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Finance Assistant",
                          style: TextStyle(
                            color: const Color(0xFFE5BA73),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ask me anything about budgeting, investing, saving, or financial planning. I'm here to help!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Suggestion chips for quick questions.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSuggestionChip("How to budget?"),
                        _buildSuggestionChip("Investing tips"),
                        _buildSuggestionChip("Save for vacation"),
                        _buildSuggestionChip("Reduce debt"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Chat messages displayed in a scrollable list.
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_outlined,
                            size: 64,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Ask your first question",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';

                        // Align messages based on sender (user or assistant).
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFF2B3A55)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isUser ? Radius.circular(0) : Radius.circular(16),
                                bottomLeft: !isUser ? Radius.circular(0) : Radius.circular(16),
                              ),
                              border: !isUser
                                  ? Border.all(color: Colors.grey.withOpacity(0.2))
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['content'],
                                  style: TextStyle(
                                    color: isUser ? Colors.white : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                                // Add a small AI branding for assistant messages.
                                if (!isUser)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 12,
                                          color: const Color(0xFFE5BA73),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "FinSight AI",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Loading indicator shown during API calls.
          if (isLoading)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFE5BA73),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Thinking...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Input field for typing messages.
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: TextStyle(color: Colors.black87),
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Ask about finances...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        // Send button for submitting messages.
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (_controller.text.trim().isNotEmpty) {
                                _sendToLLM(_controller.text.trim());
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2B3A55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Builds a suggestion chip for quick question prompts.
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _sendToLLM(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5BA73).withOpacity(0.3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}