import 'package:flutter/foundation.dart';

import '../../../core/utils/user_facing_error.dart';
import '../data/enterprise_service.dart';

class EnterpriseController extends ChangeNotifier {
  EnterpriseController({EnterpriseService? service})
    : _service = service ?? EnterpriseService();

  final EnterpriseService _service;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _organization;
  List<dynamic> _members = const [];
  List<dynamic> _goals = const [];
  List<dynamic> _budgetAlerts = const [];
  List<dynamic> _pendingApprovals = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get organization => _organization;
  List<dynamic> get members => _members;
  List<dynamic> get goals => _goals;
  List<dynamic> get budgetAlerts => _budgetAlerts;
  List<dynamic> get pendingApprovals => _pendingApprovals;

  Future<void> loadOrganization(String token, String organizationId) async {
    _setLoading(true);
    try {
      final response = await _service.fetchOrganizationDetails(
        token,
        organizationId,
      );
      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      _organization = data;
      _members = (data['members'] as List?) ?? const [];
      _goals = (data['goals'] as List?) ?? const [];
      _error = null;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load organization details right now.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadBudgetAlerts(String token, String organizationId) async {
    _setLoading(true);
    try {
      final response = await _service.fetchBudgetAlerts(token, organizationId);
      _budgetAlerts = (response['data'] as List?) ?? const [];
      _error = null;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load budget alerts right now.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPendingApprovals(String token, String organizationId) async {
    _setLoading(true);
    try {
      final response = await _service.fetchPendingApprovals(
        token,
        organizationId,
      );
      _pendingApprovals = (response['data'] as List?) ?? const [];
      _error = null;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load approval requests right now.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> requestWithdrawal(
    String token,
    Map<String, dynamic> payload,
  ) {
    return _service.requestWithdrawal(token, payload);
  }

  Future<Map<String, dynamic>> approveWithdrawal(
    String token,
    Map<String, dynamic> payload,
  ) {
    return _service.approveWithdrawal(token, payload);
  }

  Future<Map<String, dynamic>> configureAutoSweep(
    String token,
    Map<String, dynamic> payload,
  ) {
    return _service.configureAutoSweep(token, payload);
  }

  void addBudgetAlert(Map<String, dynamic> alert) {
    final id = alert['id']?.toString();
    if (id != null && id.isNotEmpty) {
      _budgetAlerts = [
        alert,
        ..._budgetAlerts.where((item) => item is Map && item['id'] != id),
      ];
    } else {
      _budgetAlerts = [alert, ..._budgetAlerts];
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
