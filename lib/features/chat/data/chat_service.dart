import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';

class ChatReply {
  final String text;
  final String? conversationId;

  const ChatReply({required this.text, this.conversationId});
}

class ChatService {
  final ApiClient _apiClient;

  ChatService([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient();

  Future<ChatReply> initialize({String? conversationId}) {
    return _sendRequest(message: 'init', conversationId: conversationId);
  }

  Future<ChatReply> sendMessage(String message, {String? conversationId}) {
    return _sendRequest(message: message, conversationId: conversationId);
  }

  Future<ChatReply> _sendRequest({
    required String message,
    String? conversationId,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id': conversationId,
    };
    final endpoints = [
      '/chat',
      '${AppConfig.baseUrl}/api/v1/chat',
      '${AppConfig.baseUrl}/v1/chat',
    ];

    Response? response;
    for (final endpoint in endpoints) {
      try {
        response = await _apiClient.client.post(
          endpoint,
          data: payload,
          options: Options(headers: const {'Accept': 'application/json'}),
        );
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          break;
        }
      } catch (_) {}
    }

    if (response == null) {
      throw Exception('Chat service unavailable.');
    }

    final root = _asMap(response.data) ?? <String, dynamic>{};
    final payloadMap = _asMap(root['data']) ?? root;
    final text =
        _extractText(payloadMap) ??
        _extractText(root) ??
        'Hello. Your secure Orbi assistant is ready.';

    return ChatReply(
      text: text,
      conversationId:
          _extractString(payloadMap, const [
            'conversation_id',
            'conversationId',
            'session_id',
            'sessionId',
            'thread_id',
            'threadId',
          ]) ??
          _extractString(root, const [
            'conversation_id',
            'conversationId',
            'session_id',
            'sessionId',
            'thread_id',
            'threadId',
          ]),
    );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return null;
  }

  String? _extractText(Map<String, dynamic>? source) {
    if (source == null) return null;

    final direct = _extractString(source, const [
      'message',
      'reply',
      'response',
      'content',
      'text',
      'answer',
      'output',
    ]);
    if (direct != null) return direct;

    for (final nestedKey in const ['assistant', 'result', 'payload']) {
      final nested = _asMap(source[nestedKey]);
      final nestedText = _extractText(nested);
      if (nestedText != null) return nestedText;
    }

    final messages = source['messages'];
    if (messages is List) {
      for (final entry in messages.reversed) {
        final message = _asMap(entry);
        final role = _extractString(message, const ['role', 'sender']);
        if (role == null ||
            role.toLowerCase().contains('assistant') ||
            role.toLowerCase().contains('bot') ||
            role.toLowerCase().contains('ai')) {
          final nestedText = _extractText(message);
          if (nestedText != null) return nestedText;
        }
      }
    }

    return null;
  }

  String? _extractString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final raw = source[key];
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) return trimmed;
      } else if (raw is num || raw is bool) {
        return raw.toString();
      } else if (raw is List && raw.isNotEmpty) {
        final joined = raw.map((item) => item.toString()).join(' ').trim();
        if (joined.isNotEmpty) return joined;
      } else if (raw != null && raw is! Map) {
        final encoded = raw.toString().trim();
        if (encoded.isNotEmpty) return encoded;
      }
    }

    final delta = source['delta'];
    if (delta is List && delta.isNotEmpty) {
      final text = delta.map((item) => item.toString()).join().trim();
      if (text.isNotEmpty) return text;
    }

    final choices = source['choices'];
    if (choices is List && choices.isNotEmpty) {
      for (final choice in choices) {
        final mapped = _asMap(choice);
        final message = _asMap(mapped?['message']);
        final text = _extractText(message);
        if (text != null) return text;
      }
    }

    final json = source['json'];
    if (json is String && json.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(json);
        final mapped = _asMap(decoded);
        final text = _extractText(mapped);
        if (text != null) return text;
      } catch (_) {
        return json.trim();
      }
    }

    return null;
  }
}
