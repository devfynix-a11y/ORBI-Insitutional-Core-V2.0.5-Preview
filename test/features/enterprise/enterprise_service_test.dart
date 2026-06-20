import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:orbi_mobileapp/features/enterprise/data/enterprise_service.dart';

void main() {
  group('EnterpriseService', () {
    test('createOrganization posts to /v1/enterprise/organizations', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/organizations',
        );
        expect(request.headers['authorization'], 'Bearer token');
        expect(request.headers.containsKey('x-orbi-app-id'), true);
        expect(request.headers.containsKey('x-orbi-trace'), true);
        expect(request.headers.containsKey('x-orbi-fingerprint'), true);
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.createOrganization('token', {'name': 'Acme'});
      expect(res['success'], true);
    });

    test('linkUserToOrganization posts to /v1/enterprise/users/link', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/users/link',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.linkUserToOrganization(
        'token',
        {'userId': 'u1', 'organizationId': 'o1', 'role': 'ADMIN'},
      );
      expect(res['success'], true);
    });

    test('inviteUser posts to /v1/enterprise/users/invite', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/users/invite',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.inviteUser(
        'token',
        {'email': 'user@acme.com', 'organizationId': 'o1', 'role': 'EMPLOYEE'},
      );
      expect(res['success'], true);
    });

    test('fetchOrganizationDetails gets /v1/enterprise/organizations/:id', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/organizations/org-1',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.fetchOrganizationDetails('token', 'org-1');
      expect(res['success'], true);
    });

    test('fetchBudgetAlerts gets /v1/enterprise/budgets/alerts', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/budgets/alerts?orgId=org-1',
        );
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.fetchBudgetAlerts('token', 'org-1');
      expect(res['success'], true);
    });

    test('fetchPendingApprovals gets /v1/enterprise/treasury/approvals', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/treasury/approvals?orgId=org-1',
        );
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.fetchPendingApprovals('token', 'org-1');
      expect(res['success'], true);
    });

    test('requestWithdrawal posts to /v1/enterprise/treasury/withdraw/request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/treasury/withdraw/request',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.requestWithdrawal(
        'token',
        {'goalId': 'g1', 'amount': 10, 'destinationWalletId': 'w1'},
      );
      expect(res['success'], true);
    });

    test('approveWithdrawal posts to /v1/enterprise/treasury/withdraw/approve', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/treasury/withdraw/approve',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.approveWithdrawal('token', {'txId': 'tx-1'});
      expect(res['success'], true);
    });

    test('configureAutoSweep posts to /v1/enterprise/treasury/autosweep', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/v1/enterprise/treasury/autosweep',
        );
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final service = EnterpriseService(baseUrl: 'https://example.com', client: client);
      final res = await service.configureAutoSweep(
        'token',
        {'goalId': 'g1', 'enabled': true, 'threshold': 1000},
      );
      expect(res['success'], true);
    });
  });
}
