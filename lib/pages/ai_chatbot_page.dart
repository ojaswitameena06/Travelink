import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AIChatbotPage extends StatefulWidget {
  const AIChatbotPage({super.key});

  @override
  State<AIChatbotPage> createState() => _AIChatbotPageState();
}

class _AIChatbotPageState extends State<AIChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': '👋 Hi! I am your **Travelink AI Assistant**.\n\nAsk me anything! I can generate custom itineraries, packing lists, budget tips, or recommend destinations.'
    }
  ];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    "🌴 3-day Goa itinerary",
    "🚣 Best backwaters in Kerala",
    "💰 Budget travel tips",
    "🎒 Essential packing checklist",
    "🗼 Paris travel highlights",
  ];

  Future<void> _handleSubmitted(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': prompt});
      _isLoading = true;
    });

    _scrollToBottom();

    final response = await AIService.getTravelAdvice(prompt);

    if (mounted) {
      setState(() {
        _messages.add({'sender': 'ai', 'text': response});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.smart_toy, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("AI Travel Assistant 🤖"),
          ],
        ),
      ),
      body: Column(
        children: [
          // 💡 Quick Action Chips
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickPrompts.length,
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                    onPressed: () => _handleSubmitted(prompt),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 💬 Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey[100],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                      border: isUser ? null : Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, size: 16, color: Colors.blueAccent),
                              SizedBox(width: 4),
                              Text("Travelink AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                            ],
                          ),
                        if (!isUser) const SizedBox(height: 6),
                        Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("AI is planning your response...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),

          // ✏️ Text Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask AI about any destination or itinerary...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _handleSubmitted(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
