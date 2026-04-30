import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../storage/chat_storage.dart';
import '../services/llm_service.dart';
import '../utils/response_cleaner.dart';

// ─── Sliding-Window Context Controller ────────────────────────────────────────
// Manages the entire chat state so that ChatScreen is a pure UI consumer.
// Key responsibility: build the LLM prompt from a TRUNCATED window of messages
// so we never exceed the model's context length.
class ChatController extends ChangeNotifier {

  // ── Public state ───────────────────────────────────────────────────────────
  final List<ChatMessage>  messages       = [];
  List<Conversation>       conversations  = [];
  int?                     currentConvId;
  bool                     isThinking     = false;
  bool                     historyLoading = false;
  String?                  activeModelPath;

  // ── Settings state ────────────────────────────────────────────────────────
  String  customInstructions = '';
  double  temperature        = 0.7;
  int     maxTokens          = 512;
  int     contextWindowSize  = 2048;

  // ── Public setters (call notifyListeners internally) ─────────────────────
  void setActiveModelPath(String? path) {
    activeModelPath = path;
    notifyListeners();
  }

  void setCustomInstructions(String v) {
    customInstructions = v;
    notifyListeners();
  }

  void setTemperature(double v) {
    temperature = v;
    notifyListeners();
  }

  void setMaxTokens(int v) {
    maxTokens = v;
    notifyListeners();
  }

  void setContextWindowSize(int v) {
    contextWindowSize = v;
    notifyListeners();
  }

  // ── Sliding-window config ─────────────────────────────────────────────────
  // How many recent messages (in addition to the system prompt) to pass to
  // the model. Each user+ai pair ≈ 2 items. 12 = ~6 turns of context.
  static const int _maxContextMessages = 8;

  // ── Preset instant replies ─────────────────────────────────────────────────
  static final _kPresetReplies = <RegExp, List<String>>{
    RegExp(r'^h+e+l+o+[!?.]*$'):
        ['Hey there! 👋 How can I help?', 'Hello! 😊 What can I do for you?'],
    RegExp(r'^h+i+[!?.]*$'):
        ['Hi! 👋 How can I help?', 'Hello! Ask me anything.'],
    RegExp(r'^hey+[!?.]*$'):
        ['Hey! 👋 What\'s up?', 'Hey there! Ready to help!'],
    RegExp(r"^how\s+are\s+(you|u)[!?.]*$"):
        ['I\'m sharp and ready! 😊 What\'s on your mind?'],
    RegExp(r'^good\s+morning[!?.]*$'):
        ['Good morning! ☀️ How can I help?'],
    RegExp(r'^good\s+evening[!?.]*$'):
        ['Good evening! 🌙 What\'s on your mind?'],
    RegExp(r'^good\s+night[!?.]*$'):
        ['Good night! 🌙 Sleep well!'],
    RegExp(r'^th?a+nk(s| you)[!?.]*$'):
        ['You\'re welcome! 😊 Anything else?', 'Happy to help!'],
    RegExp(r'^(bye|goodbye|see\s+you|cya)[!?.]*$'):
        ['Goodbye! 👋 Come back anytime.'],
    RegExp(r'^who\s+are\s+you[!?.]*$'):
        ['I\'m RAMA — your 100% offline AI assistant! 🤖 I run entirely on your device, no internet needed.'],
    RegExp(r'^what\s+(is|are)\s+your\s+name[!?.]*$'):
        ['I\'m RAMA AI — your private, offline AI assistant! 🤖'],
    RegExp(r'^(ok|okay|sure|got\s+it|understood)[!?.]*$'):
        ['Great! Anything else I can help with? 😊', 'Got it! Let me know if you need anything.'],
    RegExp(r'^(yes|yeah|yep|yup)[!?.]*$'):
        ['Sounds good! How can I assist? 😊'],
    RegExp(r'^(no|nope|nah)[!?.]*$'):
        ['No problem! Feel free to ask me anything anytime.'],
    RegExp(r'^(what\s+can\s+you\s+do|help)[!?.]*$'):
        ['I can answer questions, write code, explain concepts, summarize text, and much more — all 100% offline! 🤖 Try asking me anything.'],
  };

  String? _instantReply(String text) {
    final lower = text.toLowerCase().trim();
    for (final entry in _kPresetReplies.entries) {
      if (entry.key.hasMatch(lower)) {
        final variants = entry.value;
        return variants[DateTime.now().millisecond % variants.length];
      }
    }
    return null;
  }

  // ── Conversation management ────────────────────────────────────────────────

  Future<void> loadConversations() async {
    historyLoading = true;
    notifyListeners();
    conversations = await ChatStorage.listConversations();
    historyLoading = false;
    notifyListeners();
  }

  Future<void> startNewChat() async {
    messages.clear();
    currentConvId = null;
    notifyListeners();
  }

  Future<void> loadConversation(Conversation conv) async {
    messages.clear();
    currentConvId = conv.id;
    notifyListeners();

    final stored = await ChatStorage.loadMessages(conv.id!);
    final msgs = stored.map((s) => ChatMessage(
      _roleFromString(s.role), s.text, time: s.time,
    )).toList();

    messages.addAll(msgs);
    notifyListeners();
  }

  Future<void> deleteConversation(Conversation conv) async {
    await ChatStorage.deleteConversation(conv.id!);
    if (currentConvId == conv.id) {
      messages.clear();
      currentConvId = null;
    }
    await loadConversations();
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isThinking) return;
    if (activeModelPath == null) return;

    // Create conversation if needed
    if (currentConvId == null) {
      final id = await ChatStorage.createConversation(
        title: text.length > 40 ? '${text.substring(0, 38)}…' : text,
      );
      currentConvId = id;
    }

    final userMsg = ChatMessage(MessageRole.user, text.trim());
    messages.add(userMsg);
    isThinking = true;
    notifyListeners();

    await ChatStorage.insertMessage(StoredMessage(
      conversationId: currentConvId!,
      role:           'user',
      text:           text.trim(),
      time:           userMsg.time,
    ));

    // ── Instant reply check ────────────────────────────────────────────────
    final preset = _instantReply(text.trim());
    if (preset != null) {
      await _postReply(preset, text.trim());
      return;
    }

    // ── Full LLM inference with sliding-window context ─────────────────────
    final contextMsgs = await ChatStorage.lastMessages(
      currentConvId!, _maxContextMessages,
    );
    final prompt = _buildSlidingWindowPrompt(contextMsgs, text.trim());

    try {
      final raw   = await LLMService.runInference(activeModelPath!, prompt);
      final reply = cleanLLMResponse(raw);
      if (reply.isNotEmpty) {
        await _postReply(reply, text.trim());
      } else {
        await _postReply('(No response generated)', text.trim());
      }
    } catch (e) {
      final errMsg = ChatMessage(MessageRole.error, 'Error: $e');
      messages.add(errMsg);
      isThinking = false;
      await ChatStorage.insertMessage(StoredMessage(
        conversationId: currentConvId!,
        role:           'error',
        text:           'Error: $e',
        time:           errMsg.time,
      ));
      notifyListeners();
    }
  }

  // ── Shared post-reply helper ───────────────────────────────────────────────
  Future<void> _postReply(String reply, String userText) async {
    final role  = reply.startsWith('Error:') ? MessageRole.error : MessageRole.ai;
    final aiMsg = ChatMessage(role, reply);
    messages.add(aiMsg);
    isThinking = false;
    notifyListeners();

    await ChatStorage.insertMessage(StoredMessage(
      conversationId: currentConvId!,
      role:           role == MessageRole.error ? 'error' : 'ai',
      text:           reply,
      time:           aiMsg.time,
    ));

    // Update conversation title if still default
    final matchIdx = conversations.indexWhere((c) => c.id == currentConvId);
    if (matchIdx >= 0) {
      final conv = conversations[matchIdx];
      if (conv.title.isEmpty || conv.title == 'New Chat') {
        await ChatStorage.updateTitle(
          currentConvId!,
          userText.length > 40 ? '${userText.substring(0, 38)}…' : userText,
        );
      }
    }
    await loadConversations();
  }

  // ── Sliding-Window Prompt Builder ──────────────────────────────────────────
  // Architecture:
  //   [System Prompt / Custom Instructions]
  //   [Retained conversation history — last _maxContextMessages]
  //   [Current user turn]
  //
  // The history is already sliced by ChatStorage.lastMessages(), so we never
  // exceed the token budget regardless of how long a conversation grows.
  String _buildSlidingWindowPrompt(
    List<StoredMessage> history,
    String input,
  ) {
    final buf = StringBuffer();

    // ── System instruction ─────────────────────────────────────────────────
    buf.write('You are RAMA, a helpful, accurate, and concise AI assistant. ');
    buf.write('Give complete, well-structured answers.\n');

    // ── Custom user instructions (Global Memory) ───────────────────────────
    if (customInstructions.trim().isNotEmpty) {
      buf.write('User preferences: ${customInstructions.trim()}\n');
    }
    buf.write('\n');

    // ── Conversation history (last N messages) ─────────────────────────────
    for (final msg in history) {
      if (msg.role == 'user') {
        buf.write('User: ${msg.text}\n');
      } else if (msg.role == 'ai') {
        buf.write('Assistant: ${msg.text}\n');
      }
    }

    // ── Current turn ───────────────────────────────────────────────────────
    buf.write('User: $input\nAssistant:');
    return buf.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  MessageRole _roleFromString(String r) {
    switch (r) {
      case 'user':  return MessageRole.user;
      case 'error': return MessageRole.error;
      default:      return MessageRole.ai;
    }
  }

  // Grouped chat history for UI sidebar
  Map<String, List<Conversation>> groupedConversations() {
    final today    = <Conversation>[];
    final week     = <Conversation>[];
    final older    = <Conversation>[];
    final now      = DateTime.now();

    for (final c in conversations) {
      final diff = now.difference(c.updatedAt).inDays;
      if (diff == 0) {
        today.add(c);
      } else if (diff <= 7) {
        week.add(c);
      } else {
        older.add(c);
      }
    }

    return {
      if (today.isNotEmpty)  'Today': today,
      if (week.isNotEmpty)   'Previous 7 Days': week,
      if (older.isNotEmpty)  'Older': older,
    };
  }
}
