import 'package:flutter_test/flutter_test.dart';

import 'package:orbi_mobileapp/features/enterprise/data/enterprise_service.dart';
import 'package:orbi_mobileapp/features/enterprise/state/enterprise_controller.dart';

class _FakeEnterpriseService extends EnterpriseService {
  _FakeEnterpriseService() : super(baseUrl: 'https://example.com');

  @override
  Future<Map<String, dynamic>> fetchOrganizationDetails(
    String token,
    String organizationId,
  ) async {
    return {
      'success': true,
      'data': {
        'name': 'Acme',
        'members': [
          {'id': 'u1'},
        ],
        'goals': [
          {'id': 'g1', 'name': 'Tax Reserve'},
        ],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> fetchBudgetAlerts(
    String token,
    String organizationId,
  ) async {
    return {
      'success': true,
      'data': [
        {'id': 'a1', 'alert_type': 'WARNING_80_PERCENT'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchPendingApprovals(
    String token,
    String organizationId,
  ) async {
    return {
      'success': true,
      'data': [
        {'id': 'p1', 'reason': 'Payroll'},
      ],
    };
  }
}

void main() {
  test('EnterpriseController loads org, goals, alerts, approvals', () async {
    final controller = EnterpriseController(service: _FakeEnterpriseService());
    await controller.loadOrganization('token', 'org1');
    await controller.loadBudgetAlerts('token', 'org1');
    await controller.loadPendingApprovals('token', 'org1');

    expect(controller.organization?['name'], 'Acme');
    expect(controller.members.length, 1);
    expect(controller.goals.length, 1);
    expect(controller.budgetAlerts.length, 1);
    expect(controller.pendingApprovals.length, 1);
  });

  test('EnterpriseController addBudgetAlert de-dupes by id', () {
    final controller = EnterpriseController(service: _FakeEnterpriseService());
    controller.addBudgetAlert({'id': 'a1', 'alert_type': 'EXCEEDED'});
    controller.addBudgetAlert({'id': 'a1', 'alert_type': 'BLOCKED'});
    expect(controller.budgetAlerts.length, 1);
    expect(
      (controller.budgetAlerts.first as Map)['alert_type'],
      'BLOCKED',
    );
  });
}
