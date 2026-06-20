import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredChatMessage {
  final String role;
  final String text;
  final DateTime timestamp;

  const StoredChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  static StoredChatMessage? fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final text = json['text'];
    final timestamp = json['timestamp'];
    if (role is! String || text is! String || timestamp is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return null;
    return StoredChatMessage(role: role, text: text, timestamp: parsed);
  }
}

class ChatLocalStore {
  static const String _conversationIdKey = 'obi_chat_conversation_id';
  static const String _messagesKey = 'obi_chat_messages';
  static const int _maxMessages = 24;

  Future<String?> loadConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_conversationIdKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<List<StoredChatMessage>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_messagesKey) ?? const <String>[];
    final messages = <StoredChatMessage>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          final message = StoredChatMessage.fromJson(decoded);
          if (message != null) {
            messages.add(message);
          }
        } else if (decoded is Map) {
          final message = StoredChatMessage.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (message != null) {
            messages.add(message);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return messages;
  }

  Future<void> saveConversation({
    required String? conversationId,
    required List<StoredChatMessage> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (conversationId == null || conversationId.trim().isEmpty) {
      await prefs.remove(_conversationIdKey);
    } else {
      await prefs.setString(_conversationIdKey, conversationId.trim());
    }

    final trimmed = messages.length <= _maxMessages
        ? messages
        : messages.sublist(messages.length - _maxMessages);
    await prefs.setStringList(
      _messagesKey,
      trimmed.map((message) => jsonEncode(message.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationIdKey);
    await prefs.remove(_messagesKey);
  }
}
