import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';

class WealthService {
  WealthService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  final Dio _dio;
  static const Uuid _uuid = Uuid();

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _get('/wealth/summary');
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listBillReserves() async {
    final response = await _get('/wealth/bill-reserves');
    return _extractList(
      response.data,
      keys: const ['reserves', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> createBillReserve(
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/wealth/bill-reserves', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> updateBillReserve(
    String reserveId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _patch('/wealth/bill-reserves/$reserveId', payload);
    return _extractItem(response.data);
  }

  Future<void> deleteBillReserve(String reserveId) async {
    await _delete('/wealth/bill-reserves/$reserveId');
  }

  Future<List<Map<String, dynamic>>> listSharedPots() async {
    final response = await _get('/wealth/shared-pots');
    return _extractList(
      response.data,
      keys: const ['pots', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>?> lookupInvitee(String query) async {
    final normalized = query.trim();
    if (normalized.length < 3) return null;
    try {
      final response = await _dio.get(
        '/user/lookup',
        queryParameters: {'q': normalized},
      );
      final data = _extractLookupData(response.data);
      if (data.isEmpty) return null;
      final displayName = _pickFirstString([
        data['full_name'],
        data['fullName'],
        data['display_name'],
        data['name'],
      ]);
      final customerId = _pickFirstString([
        data['customer_id'],
        data['customerId'],
        data['recipient_id'],
        data['recipientId'],
      ]);
      return {
        ...data,
        ...?(displayName == null ? null : {'display_name': displayName}),
        ...?(customerId == null ? null : {'customer_id': customerId}),
      };
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  String resolveInviteeIdentifier(
    Map<String, dynamic>? invitee, {
    String fallback = '',
  }) {
    return _pickFirstString([
          invitee?['customer_id'],
          invitee?['customerId'],
          invitee?['recipient_id'],
          invitee?['recipientId'],
          invitee?['email'],
          invitee?['phone'],
          invitee?['msisdn'],
          invitee?['identifier'],
          invitee?['id'],
          invitee?['user_id'],
          invitee?['userId'],
          invitee?['profile_id'],
          invitee?['profileId'],
        ]) ??
        fallback.trim();
  }

  Map<String, dynamic> buildInvitePayload({
    required Map<String, dynamic>? invitee,
    required String fallback,
    required String role,
    Map<String, dynamic> extra = const {},
  }) {
    final identifier = resolveInviteeIdentifier(invitee, fallback: fallback);
    final customerId = _pickFirstString([
      invitee?['customer_id'],
      invitee?['customerId'],
      invitee?['recipient_id'],
      invitee?['recipientId'],
      invitee?['orbi_id'],
      invitee?['orbiId'],
    ]);
    final internalUserId = _pickFirstString([
      invitee?['id'],
      invitee?['user_id'],
      invitee?['userId'],
      invitee?['profile_id'],
      invitee?['profileId'],
    ]);
    final email = _pickFirstString([invitee?['email']]);
    final phone = _pickFirstString([
      invitee?['phone'],
      invitee?['phone_number'],
      invitee?['phoneNumber'],
      invitee?['msisdn'],
    ]);

    return {
      'identifier': identifier,
      'role': role,
      ...?customerId == null
          ? null
          : {
              'customer_id': customerId,
              'customerId': customerId,
              'invitee_customer_id': customerId,
              'inviteeCustomerId': customerId,
              'recipient_customer_id': customerId,
              'recipientCustomerId': customerId,
            },
      ...?internalUserId == null
          ? null
          : {
              'invitee_user_id': internalUserId,
              'inviteeUserId': internalUserId,
              'recipient_id': internalUserId,
              'recipientId': internalUserId,
            },
      ...?email == null ? null : {'email': email},
      ...?phone == null ? null : {'phone': phone, 'msisdn': phone},
      'invitee_lookup': {
        ...?customerId == null ? null : {'customer_id': customerId},
        ...?internalUserId == null ? null : {'user_id': internalUserId},
        ...?email == null ? null : {'email': email},
        ...?phone == null ? null : {'phone': phone},
      },
      ...extra,
    }..removeWhere((_, value) => value is String && value.trim().isEmpty);
  }

  Future<Map<String, dynamic>> createSharedPot(
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/wealth/shared-pots', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> updateSharedPot(
    String potId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _patch('/wealth/shared-pots/$potId', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> contributeToSharedPot(
    String potId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _postWithIdempotency(
      '/wealth/shared-pots/$potId/contribute',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> withdrawFromSharedPot(
    String potId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _postWithIdempotency(
      '/wealth/shared-pots/$potId/withdraw',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedPotWithdrawalRequests(
    String potId,
  ) async {
    final response = await _get(
      '/wealth/shared-pots/$potId/withdrawal-requests',
    );
    return _extractList(
      response.data,
      keys: const ['requests', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> respondToSharedPotWithdrawalRequest(
    String requestId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-pot-withdrawal-requests/$requestId/respond',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> requestSharedPotArchive(
    String potId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/wealth/shared-pots/$potId/delete-request',
        data: payload,
      );
      return _extractItem(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map &&
          data['error']?.toString().toUpperCase() == 'SECURITY_CHALLENGE') {
        return Map<String, dynamic>.from(data);
      }
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  Future<Map<String, dynamic>> cancelSharedPotArchiveRequest(
    String requestId,
  ) async {
    final response = await _post(
      '/wealth/shared-pot-delete-requests/$requestId/cancel',
      const <String, dynamic>{},
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedPotMembers(String potId) async {
    final response = await _get('/wealth/shared-pots/$potId/members');
    return _extractList(
      response.data,
      keys: const ['members', 'items', 'results'],
    );
  }

  Future<void> removeSharedPotMember(String potId, String memberId) async {
    await _delete('/wealth/shared-pots/$potId/members/$memberId');
  }

  Future<Map<String, dynamic>> leaveSharedPot(String potId) async {
    final response = await _post(
      '/wealth/shared-pots/$potId/leave',
      const <String, dynamic>{},
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> getSharedPotReport(
    String potId, {
    String range = 'month',
  }) async {
    final response = await _get(
      '/wealth/shared-pots/$potId/report?range=${Uri.encodeQueryComponent(range)}',
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> addSharedPotMember(
    String potId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-pots/$potId/invitations',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listMySharedPotInvitations() async {
    final response = await _get('/wealth/shared-pot-invitations');
    return _extractList(
      response.data,
      keys: const ['invitations', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> respondToSharedPotInvitation(
    String invitationId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-pot-invitations/$invitationId/respond',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedBudgets() async {
    final response = await _get('/wealth/shared-budgets');
    return _extractList(
      response.data,
      keys: const ['budgets', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> createSharedBudget(
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/wealth/shared-budgets', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> updateSharedBudget(
    String budgetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _patch('/wealth/shared-budgets/$budgetId', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> allocateSharedBudget(
    String budgetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _postWithIdempotency(
      '/wealth/shared-budgets/$budgetId/allocate',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedBudgetMembers(
    String budgetId,
  ) async {
    final response = await _get('/wealth/shared-budgets/$budgetId/members');
    return _extractList(
      response.data,
      keys: const ['members', 'items', 'results'],
    );
  }

  Future<void> removeSharedBudgetMember(
    String budgetId,
    String memberId,
  ) async {
    await _delete('/wealth/shared-budgets/$budgetId/members/$memberId');
  }

  Future<Map<String, dynamic>> leaveSharedBudget(String budgetId) async {
    final response = await _post(
      '/wealth/shared-budgets/$budgetId/leave',
      const <String, dynamic>{},
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedBudgetTransactions(
    String budgetId,
  ) async {
    final response = await _get(
      '/wealth/shared-budgets/$budgetId/transactions',
    );
    return _extractList(
      response.data,
      keys: const ['transactions', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> getSharedBudgetReport(
    String budgetId, {
    String range = 'month',
  }) async {
    final response = await _get(
      '/wealth/shared-budgets/$budgetId/report?range=${Uri.encodeQueryComponent(range)}',
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listSharedBudgetInvitations(
    String budgetId,
  ) async {
    final response = await _get('/wealth/shared-budgets/$budgetId/invitations');
    return _extractList(
      response.data,
      keys: const ['invitations', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> listSharedBudgetApprovals(
    String budgetId,
  ) async {
    final response = await _get('/wealth/shared-budgets/$budgetId/approvals');
    return _extractList(
      response.data,
      keys: const ['approvals', 'items', 'results'],
    );
  }

  Future<List<Map<String, dynamic>>> listMySharedBudgetInvitations() async {
    final response = await _get('/wealth/shared-budget-invitations');
    return _extractList(
      response.data,
      keys: const ['invitations', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> addSharedBudgetInvitation(
    String budgetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-budgets/$budgetId/invitations',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> respondToSharedBudgetInvitation(
    String invitationId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-budget-invitations/$invitationId/respond',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> respondToSharedBudgetApproval(
    String approvalId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-budget-approvals/$approvalId/respond',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> previewSharedBudgetSpend(
    String budgetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/wealth/shared-budgets/$budgetId/spend/preview',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> settleSharedBudgetSpend(
    String budgetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _postWithIdempotency(
      '/wealth/shared-budgets/$budgetId/spend/settle',
      payload,
    );
    return _extractItem(response.data);
  }

  Future<List<Map<String, dynamic>>> listAllocationRules() async {
    final response = await _get('/wealth/allocation-rules');
    return _extractList(
      response.data,
      keys: const ['rules', 'items', 'results'],
    );
  }

  Future<Map<String, dynamic>> createAllocationRule(
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/wealth/allocation-rules', payload);
    return _extractItem(response.data);
  }

  Future<Map<String, dynamic>> updateAllocationRule(
    String ruleId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _patch('/wealth/allocation-rules/$ruleId', payload);
    return _extractItem(response.data);
  }

  Future<Response<dynamic>> _get(String path) async {
    try {
      return await _dio.get(path);
    } on DioException catch (error) {
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  Future<Response<dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _dio.post(path, data: payload);
    } on DioException catch (error) {
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  Future<Response<dynamic>> _postWithIdempotency(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final idempotencyKey = _uuid.v4();
    try {
      return await _dio.post(
        path,
        data: {
          ...payload,
          'idempotencyKey': idempotencyKey,
          'idempotency_key': idempotencyKey,
        },
        options: Options(
          headers: {
            'Idempotency-Key': idempotencyKey,
            'x-idempotency-key': idempotencyKey,
          },
        ),
      );
    } on DioException catch (error) {
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  Future<Response<dynamic>> _patch(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _dio.patch(path, data: payload);
    } on DioException catch (error) {
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (error) {
      throw WealthServiceException(_extractDioMessage(error));
    }
  }

  String _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final details = data['details'];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map) {
          final detailMessage = _pickFirstString([
            first['message'],
            first['code'],
            first['error'],
          ]);
          if (detailMessage != null) {
            final path = first['path'];
            if (path is List && path.isNotEmpty) {
              return '${path.join('.')}: $detailMessage';
            }
            return detailMessage;
          }
        }
      }

      final direct = _pickFirstString([
        data['error'],
        data['message'],
        data['detail'],
        data['hint'],
      ]);
      if (direct != null) return direct;

      final nestedData = data['data'];
      if (nestedData is Map) {
        final nested = _pickFirstString([
          nestedData['error'],
          nestedData['message'],
          nestedData['detail'],
          nestedData['hint'],
        ]);
        if (nested != null) return nested;
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'Request failed';
  }

  String? _pickFirstString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractList(
    dynamic raw, {
    List<String> keys = const ['items', 'results'],
  }) {
    final data = _unwrap(raw);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      for (final key in keys) {
        final items = data[key];
        if (items is List) {
          return items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractItem(dynamic raw) {
    final data = _unwrap(raw);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _extractLookupData(dynamic raw) {
    final data = _unwrap(raw);
    if (data is Map) {
      final nestedData = data['data'];
      if (nestedData is Map) return Map<String, dynamic>.from(nestedData);
      final user = data['user'];
      if (user is Map) return Map<String, dynamic>.from(user);
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  dynamic _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['data'] ?? raw;
    }
    return raw;
  }
}

class WealthServiceException implements Exception {
  const WealthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
