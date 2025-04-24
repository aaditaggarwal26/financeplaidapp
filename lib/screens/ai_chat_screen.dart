import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool genZMode = false;
  bool isLoading = false;

  Future<void> _sendToLLM(String message) async {
    setState(() {
      isLoading = true;
      _messages.add({"role": "user", "content": message});
    });

    final uri = Uri.parse("https://openrouter.ai/api/v1/chat/completions");
    final headers = {
      "Authorization":
          "Bearer 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",
      "Content-Type": "application/json",
      "HTTP-Referer": "https://your-finance-app.com",
      "X-Title": "FinSight",
    };

    final prompt = genZMode
        ? "Respond like a Gen-Z finance friend without markdown text and not long answers who knows money vibes 💸. Don't go too overboard but still explain in genz/alpha way. Ensure no markdown formatting. Don't have the messages be too long, be reasonable:\n$message"
        : message;

    final body = jsonEncode({
      "model": "meta-llama/llama-3.2-1b-instruct:free",
      "messages": [
        {"role": "user", "content": prompt}
      ]
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      final reply = result['choices'][0]['message']['content'];

      setState(() {
        _messages.add({"role": "assistant", "content": reply});
      });
    } else {
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": "Oops, something went wrong. Try again later."
        });
      });
    }

    setState(() {
      isLoading = false;
    });

    _controller.clear();
    
    // Scroll to bottom after message is added
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A55),
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
          // Welcome container
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
          
          // Chat messages
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
          
          // Loading indicator
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
          
          // Input field
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