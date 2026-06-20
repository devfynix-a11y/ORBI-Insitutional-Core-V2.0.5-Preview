import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/orbi_request_headers.dart';
import '../../../core/security/device_fingerprint.dart';
import '../../../core/utils/user_facing_error.dart';

class GoalsService {
  GoalsService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? AppConfig.baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Uuid _uuid = const Uuid();
  final String _fingerprint = DeviceFingerprint.generate();

  Map<String, String> _headers(String token) {
    return OrbiRequestHeaders.build(
      token: token,
      fingerprint: _fingerprint,
      trace: _uuid.v4(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchGoals(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/goals'),
      headers: _headers(token),
    );
    return _extractList(
      _decodeResponse(response),
      itemNormalizer: _normalizeGoalItem,
    );
  }

  Future<List<Map<String, dynamic>>> fetchCategories(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/categories'),
      headers: _headers(token),
    );
    return _extractList(_decodeResponse(response));
  }

  Future<Map<String, dynamic>> createGoal(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/goals'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response), itemNormalizer: _normalizeGoalItem);
  }

  Future<Map<String, dynamic>> updateGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/v1/goals/$goalId'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response), itemNormalizer: _normalizeGoalItem);
  }

  Future<Map<String, dynamic>> allocateGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/goals/$goalId/allocate'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response), itemNormalizer: _normalizeGoalItem);
  }

  Future<Map<String, dynamic>> withdrawGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/goals/$goalId/withdraw'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(
      _decodeResponse(response),
      itemNormalizer: _normalizeGoalItem,
    );
  }

  Future<void> deleteGoal(String token, String goalId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/goals/$goalId'),
      headers: _headers(token),
    );
    _assertSuccess(_decodeResponse(response));
  }

  Future<Map<String, dynamic>> createCategory(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/categories'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response));
  }

  Future<Map<String, dynamic>> updateCategory(
    String token,
    String categoryId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/v1/categories/$categoryId'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response));
  }

  Future<void> deleteCategory(String token, String categoryId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/categories/$categoryId'),
      headers: _headers(token),
    );
    _assertSuccess(_decodeResponse(response));
  }

  Future<List<Map<String, dynamic>>> fetchTasks(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1${AppConfig.endpoints['tasks'] ?? '/tasks'}'),
      headers: _headers(token),
    );
    return _extractList(_decodeResponse(response));
  }

  Future<Map<String, dynamic>> createTask(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1${AppConfig.endpoints['tasks'] ?? '/tasks'}'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response));
  }

  Future<Map<String, dynamic>> updateTask(
    String token,
    String taskId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.patch(
      Uri.parse(
        '$_baseUrl/v1${AppConfig.endpoints['tasks'] ?? '/tasks'}/$taskId',
      ),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _extractItem(_decodeResponse(response));
  }

  Future<void> deleteTask(String token, String taskId) async {
    final response = await _client.delete(
      Uri.parse(
        '$_baseUrl/v1${AppConfig.endpoints['tasks'] ?? '/tasks'}/$taskId',
      ),
      headers: _headers(token),
    );
    _assertSuccess(_decodeResponse(response));
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (response.body.trim().isEmpty) {
      return {'success': isSuccess, 'data': const []};
    }

    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        if (!isSuccess && parsed['success'] != true) {
          throw Exception(
            UserFacingError.from(
              Exception(
                parsed['error']?.toString().trim().isNotEmpty == true
                    ? parsed['error']
                    : parsed['message'] ?? 'Request failed',
              ),
              fallback: 'Unable to complete this goals request right now.',
            ),
          );
        }
        return parsed;
      }
    } catch (e) {
      if (!isSuccess) rethrow;
    }

    if (!isSuccess) {
      throw Exception(
        UserFacingError.from(
          Exception('status ${response.statusCode}'),
          fallback: 'Unable to complete this goals request right now.',
        ),
      );
    }
    return {'success': true, 'data': const []};
  }

  void _assertSuccess(Map<String, dynamic> payload) {
    final success = payload['success'];
    if (success == false) {
      throw Exception(
        UserFacingError.from(
          Exception(payload['error'] ?? payload['message'] ?? 'Request failed'),
          fallback: 'Unable to complete this goals request right now.',
        ),
      );
    }
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> payload, {
    Map<String, dynamic> Function(Map<String, dynamic> item)? itemNormalizer,
  }) {
    _assertSuccess(payload);
    final data = _unwrapPayloadData(payload);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map((item) => itemNormalizer?.call(item) ?? item)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final nested =
          data['items'] ??
          data['results'] ??
          data['rows'] ??
          data['goals'] ??
          data['categories'] ??
          data['tasks'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map((item) => itemNormalizer?.call(item) ?? item)
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractItem(
    Map<String, dynamic> payload, {
    Map<String, dynamic> Function(Map<String, dynamic> item)? itemNormalizer,
  }) {
    _assertSuccess(payload);
    final data = _unwrapPayloadData(payload);
    if (data is Map<String, dynamic>) {
      final item = Map<String, dynamic>.from(data);
      return itemNormalizer?.call(item) ?? item;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      final item = Map<String, dynamic>.from(data.first);
      return itemNormalizer?.call(item) ?? item;
    }
    final item = Map<String, dynamic>.from(payload);
    return itemNormalizer?.call(item) ?? item;
  }

  dynamic _unwrapPayloadData(dynamic value) {
    dynamic current = value;
    for (var i = 0; i < 4; i++) {
      if (current is! Map<String, dynamic>) return current;
      final next =
          current['data'] ??
          current['result'] ??
          current['payload'] ??
          current['response'];
      if (next == null) return current;
      current = next;
    }
    return current;
  }

  Map<String, dynamic> _normalizeGoalItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);
    normalized['id'] = _pickValue(item, const ['id', 'goalId', 'goal_id']);
    normalized['name'] = _pickValue(item, const ['name', 'title']) ?? '';
    normalized['target'] = _pickValue(item, const [
      'target',
      'target_amount',
      'targetAmount',
    ]);
    normalized['current'] = _pickValue(item, const [
      'current',
      'current_amount',
      'currentAmount',
    ]);
    normalized['deadline'] = _pickValue(item, const [
      'deadline',
      'deadline_at',
      'due_date',
      'dueDate',
    ]);
    normalized['fundingStrategy'] = _pickValue(item, const [
      'fundingStrategy',
      'funding_strategy',
    ]);
    normalized['autoAllocationEnabled'] = _pickValue(item, const [
      'autoAllocationEnabled',
      'auto_allocation_enabled',
    ]);
    normalized['linkedIncomePercentage'] = _pickValue(item, const [
      'linkedIncomePercentage',
      'linked_income_percentage',
    ]);
    normalized['monthlyTarget'] = _pickValue(item, const [
      'monthlyTarget',
      'monthly_target',
    ]);
    normalized['sourceWalletId'] = _pickValue(item, const [
      'sourceWalletId',
      'source_wallet_id',
      'walletId',
      'wallet_id',
      'operating_wallet_id',
      'operatingWalletId',
    ]);
    normalized['currency'] = _pickValue(item, const [
      'currency',
      'currency_code',
      'asset_currency',
    ]);
    return normalized;
  }

  dynamic _pickValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      if (item.containsKey(key) && item[key] != null) {
        return item[key];
      }
    }
    return null;
  }
}
