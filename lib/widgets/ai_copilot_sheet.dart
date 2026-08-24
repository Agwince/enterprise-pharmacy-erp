import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiCopilotSheet extends StatefulWidget {
  const AiCopilotSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiCopilotSheet(),
    );
  }

  @override
  State<AiCopilotSheet> createState() => _AiCopilotSheetState();
}

class _AiCopilotSheetState extends State<AiCopilotSheet> {
  final _controller = TextEditingController();
  final _aiService = AiService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('ai_chat_messages').select('role, content').eq('user_id', user.id).order('created_at', ascending: true);
        final List<Map<String, String>> history = [];
        for (var row in data) {
          history.add({
            'role': row['role'].toString(),
            'content': row['content'].toString(),
          });
        }
        setState(() {
          _messages.addAll(history);
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    _controller.clear();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('ai_chat_messages').insert({'user_id': user.id, 'role': 'user', 'content': text});
      } catch (e) {}
    }

    // Prepare history to send (excluding the very last user message which is passed directly)
    final history = _messages.take(_messages.length - 1).toList();
    final response = await _aiService.sendMessage(text, history);

    if (mounted) {
      setState(() {
        _messages.add({"role": "assistant", "content": response});
        _isLoading = false;
      });
      if (user != null) {
        try {
          _supabase.from('ai_chat_messages').insert({'user_id': user.id, 'role': 'assistant', 'content': response});
        } catch (e) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text(
                  'Mediocare Genius',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          
          // Chat Area
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Ask me about stock, sales, or logistics.',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blueAccent.withOpacity(0.2) : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUser ? Colors.blueAccent.withOpacity(0.5) : Colors.white10,
                            ),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: GoogleFonts.inter(
                              color: isUser ? Colors.white : Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          
          // Input Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
