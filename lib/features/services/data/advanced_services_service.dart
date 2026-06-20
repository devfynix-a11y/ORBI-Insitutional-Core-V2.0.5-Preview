import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class AdvancedServicesService {
  AdvancedServicesService([ApiClient? client])
    : _dio = (client ?? ApiClient()).client;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listWallets() async {
    final response = await _dio.get(AppConfig.endpoints['wallets'] ?? '/wallets');
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> listDocuments() async {
    final response = await _dio.get(
      AppConfig.endpoints['userDocuments'] ?? '/user/documents',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> uploadDocument(String filePath) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post(
      AppConfig.endpoints['userDocuments'] ?? '/user/documents',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _extractItem(response.data);
  }

  Future<void> deleteDocument(String documentId) async {
    await _dio.delete(
      '${AppConfig.endpoints['userDocuments'] ?? '/user/documents'}/$documentId',
    );
  }

  Future<List<Map<String, dynamic>>> listServiceAccessRequests() async {
    final response = await _dio.get(
      AppConfig.endpoints['serviceAccessRequestMine'] ??
          '/service-access/requests/my',
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> submitServiceAccessRequest({
    required String requestedRole,
    String? businessName,
    String? note,
    String? phone,
  }) async {
    final response = await _dio.post(
      AppConfig.endpoints['serviceAccessRequestCreate'] ??
          '/service-access/requests',
      data: {
        'requested_role': requestedRole.trim().toUpperCase(),
        if (businessName != null && businessName.trim().isNotEmpty)
          'business_name': businessName.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return _extractItem(response.data);
  }

  String displayFileSize(dynamic bytes) {
    final count = bytes is num ? bytes.toDouble() : double.tryParse('$bytes');
    if (count == null || count <= 0) return '';
    if (count >= 1024 * 1024) {
      return '${(count / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (count >= 1024) {
      return '${(count / 1024).toStringAsFixed(0)} KB';
    }
    return '${count.toStringAsFixed(0)} B';
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    final data = _unwrap(raw);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final items =
          data['items'] ??
          data['results'] ??
          data['documents'] ??
          data['devices'] ??
          data['wallets'] ??
          data['history'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractItem(dynamic raw) {
    final data = _unwrap(raw);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
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
