import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class FxQuote {
  final double originalAmount;
  final String fromCurrency;
  final String toCurrency;
  final double exchangeRate;
  final double fee;
  final double finalAmount;

  const FxQuote({
    required this.originalAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.exchangeRate,
    required this.fee,
    required this.finalAmount,
  });
}

class FxQuoteService {
  final Dio _dio;
  String? _lastErrorMessage;

  FxQuoteService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  String? get lastErrorMessage => _lastErrorMessage;

  Future<FxQuote?> fetch({
    required String from,
    required String to,
    required double amount,
  }) async {
    _lastErrorMessage = null;
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty || fromCode == toCode) return null;
    if (amount <= 0) return null;

    final endpoints = _quoteEndpoints();
    for (final url in endpoints) {
      try {
        final response = await _dio.get(
          url,
          queryParameters: {'from': fromCode, 'to': toCode, 'amount': amount},
        );
        final data = _unwrap(response.data);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final backendError = _extractBackendError(map);
          if (backendError != null) {
            _lastErrorMessage = backendError;
            continue;
          }
          final parsed = _parseQuote(
            map,
            fallbackFrom: fromCode,
            fallbackTo: toCode,
            fallbackAmount: amount,
          );
          if (parsed != null) return parsed;
          _lastErrorMessage = 'FX quote response was missing rate or amount.';
        }
      } on DioException catch (error) {
        _lastErrorMessage = _formatDioError(error);
      } catch (error) {
        _lastErrorMessage = 'FX quote failed: $error';
      }
    }
    return null;
  }

  List<String> _quoteEndpoints() {
    final configuredPath = AppConfig.endpoints['fxQuote'] ?? '/fx/quote';
    final candidates = <String>[
      '${AppConfig.apiUrl}$configuredPath',
      '${AppConfig.apiUrl}/fx/quote',
      '${AppConfig.baseUrl}$configuredPath',
      '${AppConfig.baseUrl}/v1/fx/quote',
      '${AppConfig.baseUrl}/api/v1/fx/quote',
    ];
    return candidates.map(_normalizeUrl).toSet().toList(growable: false);
  }

  String _normalizeUrl(String value) {
    final schemeSplit = value.split('://');
    if (schemeSplit.length != 2) return value.replaceAll(RegExp(r'/+'), '/');
    return '${schemeSplit.first}://${schemeSplit.last.replaceAll(RegExp(r'/+'), '/')}';
  }

  dynamic _unwrap(dynamic value) {
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    return map['data'] ?? map['quote'] ?? map['result'] ?? map;
  }

  String? _extractBackendError(Map<String, dynamic> map) {
    if (map['success'] != false &&
        map['error'] == null &&
        map['message'] == null) {
      return null;
    }
    final code = _toString(map['code'] ?? map['errorCode']);
    final message = _toString(
      map['error'] ?? map['message'],
      fallback: 'FX quote unavailable',
    );
    return code.isEmpty ? message : '$code: $message';
  }

  String _formatDioError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    if (body is Map) {
      final bodyMap = Map<String, dynamic>.from(body);
      final backendError = _extractBackendError(bodyMap);
      if (backendError != null) {
        return status == null ? backendError : 'HTTP $status: $backendError';
      }
    }
    final message = error.message ?? error.type.name;
    return status == null ? message : 'HTTP $status: $message';
  }

  FxQuote? _parseQuote(
    Map<String, dynamic> map, {
    required String fallbackFrom,
    required String fallbackTo,
    required double fallbackAmount,
  }) {
    final originalAmount = _firstDouble([
      map['originalAmount'],
      map['sourceAmount'],
      map['fromAmount'],
      map['amount'],
      fallbackAmount,
    ]);
    final fee = _firstDouble([
      map['fee'],
      map['feeAmount'],
      map['fees'],
      map['providerFee'],
      map['totalFee'],
    ]);
    var finalAmount = _firstDouble([
      map['finalAmount'],
      map['convertedAmount'],
      map['targetAmount'],
      map['toAmount'],
      map['recipientGets'],
      map['receiveAmount'],
    ]);
    var exchangeRate = _firstDouble([
      map['exchangeRate'],
      map['rate'],
      map['fxRate'],
      map['midRate'],
      map['quotedRate'],
    ]);

    if (exchangeRate <= 0 && finalAmount > 0 && originalAmount > 0) {
      exchangeRate = finalAmount / originalAmount;
    }
    if (finalAmount <= 0 && exchangeRate > 0 && originalAmount > 0) {
      finalAmount = (originalAmount * exchangeRate) - fee;
    }
    if (exchangeRate <= 0 || finalAmount <= 0) return null;

    return FxQuote(
      originalAmount: originalAmount,
      fromCurrency: _toString(
        map['fromCurrency'] ?? map['sourceCurrency'] ?? map['from'],
        fallback: fallbackFrom,
      ),
      toCurrency: _toString(
        map['toCurrency'] ?? map['targetCurrency'] ?? map['to'],
        fallback: fallbackTo,
      ),
      exchangeRate: exchangeRate,
      fee: fee,
      finalAmount: finalAmount,
    );
  }

  double _firstDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }
    return 0.0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _toString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text.toUpperCase();
  }
}
