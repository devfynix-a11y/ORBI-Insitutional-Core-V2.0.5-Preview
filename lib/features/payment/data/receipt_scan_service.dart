import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class ReceiptScanResult {
  final String merchant;
  final double amount;
  final String currency;
  final String date;

  const ReceiptScanResult({
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.date,
  });
}

class ReceiptScanService {
  final Dio _dio;

  ReceiptScanService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  Future<ReceiptScanResult?> scan(File file) async {
    Object? lastError;
    final endpoints = [
      '${AppConfig.baseUrl}/api/v1/receipt/scan',
      '${AppConfig.baseUrl}/v1/receipt/scan',
    ];
    for (final url in endpoints) {
      try {
        final formData = FormData.fromMap({
          'receipt': await MultipartFile.fromFile(file.path),
        });
        final response = await _dio.post(
          url,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        final data = response.data is Map<String, dynamic>
            ? response.data['data'] ?? response.data
            : response.data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          return ReceiptScanResult(
            merchant: _toString(map['merchant']),
            amount: _toDouble(map['amount']),
            currency: _toString(map['currency']),
            date: _toString(map['date']),
          );
        }
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) {
      throw Exception(_describeError(lastError));
    }
    return null;
  }

  String _describeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = _toString(
          data['message'] ?? data['error'] ?? data['detail'],
        );
        if (message.isNotEmpty) return message;
      }
      if (error.response?.statusCode != null) {
        return 'Receipt scan service failed (${error.response!.statusCode}).';
      }
      return 'Receipt scan service is unavailable right now.';
    }
    final text = error.toString().trim();
    if (text.isEmpty) return 'Receipt scan failed.';
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _toString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? '' : text;
  }
}
