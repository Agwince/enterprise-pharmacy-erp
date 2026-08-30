import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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
  final ScrollController _scrollController = ScrollController();
  final _aiService = AiService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  StreamSubscription<String>? _streamSubscription;
  http.Client? _activeClient;
  final _supabase = Supabase.instance.client;

  final List<String> _quickPrompts = [
    '📊 Multi-Branch Sales & Revenue Breakdown',
    '💊 Top Antibiotics & Diabetes Medications',
    '🧊 Cold-Chain & Insulin Temperature Audit',
    '🛵 Live Dispatch Routes in Nairobi',
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _cancelStreaming();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _activeClient?.close();
    _activeClient = null;
    if (_isLoading && mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('ai_chat_messages')
            .select('role, content')
            .eq('user_id', user.id)
            .order('created_at', ascending: true);
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
      debugPrint('AI history fetch note: $e');
    } finally {
      if (mounted) {
        if (_messages.isEmpty) {
          _messages.add({
            'role': 'assistant',
            'content': '👋 Greetings Executive. I am your Mediocare Operations Copilot powered by real-time streaming.\n\nI have instant synchronization with your 782 pharmaceutical SKUs, 4 regional hubs (Nairobi, Kisumu, Mombasa, Eldoret), and live GPS telemetry. Ask any question below or pick a prompt to analyze.'
          });
        }
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty) return;

    _cancelStreaming();
    _activeClient = http.Client();

    setState(() {
      _messages.add({"role": "user", "content": text});
      _messages.add({"role": "assistant", "content": ""});
      _isLoading = true;
    });
    if (presetText == null) {
      _controller.clear();
    }
    _scrollToBottom();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('ai_chat_messages').insert({'user_id': user.id, 'role': 'user', 'content': text});
      } catch (_) {}
    }

    final history = _messages.take(_messages.length - 2).toList();
    final responseBuffer = StringBuffer();

    _streamSubscription = _aiService
        .streamMessage(text, history, client: _activeClient)
        .listen(
      (delta) {
        if (mounted) {
          responseBuffer.write(delta);
          setState(() {
            _messages.last['content'] = responseBuffer.toString();
          });
          _scrollToBottom();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _messages.last['content'] = "Advisory unavailable ($err). Please try again.";
            _isLoading = false;
          });
          _scrollToBottom();
        }
      },
      onDone: () async {
        if (mounted) {
          setState(() => _isLoading = false);
          _scrollToBottom();
          final user = _supabase.auth.currentUser;
          if (user != null && responseBuffer.isNotEmpty) {
            try {
              await _supabase.from('ai_chat_messages').insert({
                'user_id': user.id,
                'role': 'assistant',
                'content': responseBuffer.toString(),
              });
            } catch (_) {}
          }
        }
      },
      cancelOnError: true,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFullHistory() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      return await _supabase
          .from('ai_chat_messages')
          .select('role, content, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 700 : double.infinity,
          maxHeight: screenHeight * 0.85,
        ),
        margin: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.tealAccent.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0D9488).withValues(alpha: 0.2), const Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mediocare Operations Copilot',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Powered by Minimax M3 • Live Telemetry & ERP Synced',
                                style: GoogleFonts.inter(
                                  color: Colors.tealAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const TabBar(
                      labelColor: Colors.tealAccent,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: Colors.tealAccent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: "Live Operations Chat"),
                        Tab(icon: Icon(Icons.history_rounded, size: 16), text: "Executive Audit Log"),
                      ],
                    ),
                  ],
                ),
              ),

              // Body: Live Chat vs History
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Live Chat
                    Column(
                      children: [
                        // Quick Prompt Suggestion Pills
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                            border: Border(
                              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _quickPrompts.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final prompt = _quickPrompts[index];
                              return ActionChip(
                                label: Text(
                                  prompt,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                onPressed: _isLoading ? null : () => _sendMessage(prompt),
                              );
                            },
                          ),
                        ),

                        // Message Stream
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg['role'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? const Color(0xFF0F766E).withValues(alpha: 0.35)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isUser
                                          ? Colors.tealAccent.withValues(alpha: 0.4)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop ? 550 : screenWidth * 0.82,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isUser ? Icons.person_outline_rounded : Icons.auto_awesome,
                                            size: 14,
                                            color: isUser ? Colors.tealAccent : Colors.cyanAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isUser ? 'You' : 'Minimax AI Copilot',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isUser ? Colors.tealAccent : Colors.cyanAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        msg['content'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.45,
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
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Minimax M3 analyzing live ERP metrics...',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent),
                                ),
                              ],
                            ),
                          ),

                        // Input Area
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            border: Border(
                              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Ask about 782 SKUs, branch revenues, or rider telemetry...',
                                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                                    filled: true,
                                    fillColor: const Color(0xFF0F172A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isLoading
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                      ),
                                      child: IconButton(
                                        tooltip: 'Stop generation',
                                        icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: _cancelStreaming,
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        tooltip: 'Send message',
                                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                        onPressed: () => _sendMessage(),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: History
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchFullHistory(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                        }
                        final historyData = snapshot.data ?? [];
                        if (historyData.isEmpty) {
                          return Center(
                            child: Text('No historical queries recorded for this session.',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: historyData.length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final msg = historyData[index];
                            final isUser = msg['role'] == 'user';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isUser ? Colors.blueAccent : Colors.teal,
                                radius: 14,
                                child: Icon(isUser ? Icons.person : Icons.auto_awesome, size: 14, color: Colors.white),
                              ),
                              title: Text(
                                msg['content']?.toString() ?? '',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              ),
                              subtitle: Text(
                                isUser ? 'CEO Query' : 'Minimax Advisory',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
