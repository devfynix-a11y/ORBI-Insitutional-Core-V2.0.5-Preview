import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class FxQuote {
  final double originalAmount;
  final String fromCurrency;
  final String toCurrency;
  final double exchangeRate;
  final double? baseRate;
  final double? marketRate;
  final double? bidRate;
  final double? askRate;
  final double? spreadAmount;
  final String? spreadCurrency;
  final String? spreadModel;
  final double? fixedPips;
  final int? marginBps;
  final int? riskBufferBps;
  final double fee;
  final double finalAmount;
  final String? quoteId;
  final DateTime? expiresAt;
  final int? expiresInSeconds;
  final bool lockedRate;

  const FxQuote({
    required this.originalAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.exchangeRate,
    this.baseRate,
    this.marketRate,
    this.bidRate,
    this.askRate,
    this.spreadAmount,
    this.spreadCurrency,
    this.spreadModel,
    this.fixedPips,
    this.marginBps,
    this.riskBufferBps,
    required this.fee,
    required this.finalAmount,
    this.quoteId,
    this.expiresAt,
    this.expiresInSeconds,
    this.lockedRate = false,
  });
}

class FxQuoteService {
  final Dio _dio;
  static const Uuid _uuid = Uuid();
  String? _lastErrorMessage;

  FxQuoteService([ApiClient? client]) : _dio = (client ?? ApiClient()).client;

  String? get lastErrorMessage => _lastErrorMessage;

  Future<FxQuote?> fetch({
    required String from,
    required String to,
    required double amount,
    String? sourceWalletId,
    String? targetWalletId,
    String? description,
    bool lock = false,
  }) async {
    _lastErrorMessage = null;
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty || fromCode == toCode) return null;
    if (amount <= 0) return null;

    try {
      final response = await _dio.get(
        AppConfig.endpoints['fxQuote'] ?? '/fx/quote',
        queryParameters: {
          'from': fromCode,
          'to': toCode,
          'amount': amount,
          'lock': lock,
          if (sourceWalletId?.trim().isNotEmpty == true)
            'sourceWalletId': sourceWalletId!.trim(),
          if (targetWalletId?.trim().isNotEmpty == true)
            'targetWalletId': targetWalletId!.trim(),
          if (description?.trim().isNotEmpty == true)
            'description': description!.trim(),
        },
      );
      final data = _unwrap(response.data);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final backendError = _extractBackendError(map);
        if (backendError != null) {
          _lastErrorMessage = backendError;
          return null;
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
    return null;
  }

  Future<Map<String, dynamic>> settle({
    required FxQuote quote,
    required String sourceWalletId,
    required String targetWalletId,
    required String description,
    String? idempotencyKey,
  }) async {
    final quoteId = quote.quoteId?.trim() ?? '';
    if (quoteId.isEmpty) {
      throw StateError('FX quote is missing a settlement reference.');
    }
    final resolvedIdempotencyKey =
        idempotencyKey?.trim().isNotEmpty == true
            ? idempotencyKey!.trim()
            : 'fx-conversion-${_uuid.v4()}';
    final payload = {
      'quoteId': quoteId,
      'sourceWalletId': sourceWalletId.trim(),
      'targetWalletId': targetWalletId.trim(),
      'amount': quote.originalAmount,
      'currency': quote.fromCurrency,
      'type': 'FX_CONVERSION',
      'description': description.trim().isEmpty
          ? 'FX conversion ${quote.fromCurrency} to ${quote.toCurrency}'
          : description.trim(),
      'metadata': {
        'category': 'FX',
        'fx_quote': true,
        'source_currency': quote.fromCurrency,
        'target_currency': quote.toCurrency,
      },
    };
    final response = await _dio.post(
      AppConfig.endpoints['transactionSettle'] ?? '/transactions/settle',
      data: payload,
      options: Options(
        headers: {
          'Idempotency-Key': resolvedIdempotencyKey,
          'x-idempotency-key': resolvedIdempotencyKey,
        },
      ),
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': true, 'data': data};
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
      baseRate: _firstNullableDouble([map['baseRate'], map['midRate'], map['wholesaleRate']]),
      marketRate: _firstNullableDouble([map['marketRate'], map['baseRate'], map['midRate']]),
      bidRate: _firstNullableDouble([map['bidRate']]),
      askRate: _firstNullableDouble([map['askRate']]),
      spreadAmount: _firstNullableDouble([map['spreadAmount'], map['spread_amount']]),
      spreadCurrency: _toNullableString(map['spreadCurrency'] ?? map['spread_currency']),
      spreadModel: _toNullableString(map['spreadModel'] ?? map['spread_model']),
      fixedPips: _firstNullableDouble([map['fixedPips'], map['fixed_pips']]),
      marginBps: _firstNullableInt([map['marginBps'], map['spreadBps']]),
      riskBufferBps: _firstNullableInt([map['riskBufferBps'], map['bufferBps']]),
      fee: fee,
      finalAmount: finalAmount,
      quoteId: _toNullableString(map['quoteId'] ?? map['quote_id'] ?? map['quoteContext']?['quoteId']),
      expiresAt: _toDateTime(map['expiresAt'] ?? map['expires_at'] ?? map['quoteContext']?['expiresAt']),
      expiresInSeconds: _firstNullableInt([
        map['expiresInSeconds'],
        map['expires_in_seconds'],
        map['quoteContext']?['expiresInSeconds'],
      ]),
      lockedRate: map['lockedRate'] == true || map['quoteContext']?['lockedRate'] == true,
    );
  }

  double _firstDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }
    return 0.0;
  }

  double? _firstNullableDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }
    return null;
  }

  int? _firstNullableInt(List<dynamic> values) {
    for (final value in values) {
      if (value is int && value >= 0) return value;
      if (value is num && value >= 0) return value.round();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
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

  String? _toNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  DateTime? _toDateTime(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
