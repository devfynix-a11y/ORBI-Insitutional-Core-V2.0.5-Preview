import 'dart:convert';

import 'receipt_scan_service.dart';

class ScanPayIntent {
  const ScanPayIntent({
    required this.rawValue,
    this.recipientInput,
    this.amount,
    this.note,
    this.merchantId,
    this.merchantName,
    this.provider,
    this.billCategory,
    this.reference,
    this.schemaVersion,
    this.checksum,
    this.isOrbiSchema = false,
  });

  final String rawValue;
  final String? recipientInput;
  final String? amount;
  final String? note;
  final String? merchantId;
  final String? merchantName;
  final String? provider;
  final String? billCategory;
  final String? reference;
  final String? schemaVersion;
  final String? checksum;
  final bool isOrbiSchema;

  bool get canPrefillPayment =>
      recipientInput != null && recipientInput!.trim().isNotEmpty;
}

class ScanPayService {
  const ScanPayService();

  ScanPayIntent parseQr(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const ScanPayIntent(rawValue: '');
    }

    final json = _tryMap(jsonDecodeSafe(value));
    if (json != null) {
      final recipient = _recipientFromMap(json);
      final merchantId = _merchantIdFromMap(json);
      final merchantName = _merchantNameFromMap(json);
      final provider = _providerFromMap(json);
      final billCategory = _billCategoryFromMap(json);
      final reference = _referenceFromMap(json);
      return ScanPayIntent(
        rawValue: value,
        recipientInput: _normalizeRecipient(recipient ?? merchantId),
        amount: _amountFromMap(json),
        note: _composeNote(
          explicit: _noteFromMap(json),
          merchantName: merchantName,
          provider: provider,
          billCategory: billCategory,
          reference: reference,
        ),
        merchantId: merchantId,
        merchantName: merchantName,
        provider: provider,
        billCategory: billCategory,
        reference: reference,
        schemaVersion: _schemaVersionFromMap(json),
        checksum: _checksumFromMap(json),
        isOrbiSchema: _isOrbiSchemaMap(json),
      );
    }

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.hasQuery || uri.scheme.isNotEmpty)) {
      final params = uri.queryParameters;
      final recipient = _firstNonEmpty([
        params['recipient'],
        params['merchant_id'],
        params['merchantId'],
        params['recipientId'],
        params['recipient_customer_id'],
        params['customer_id'],
        params['phone'],
        params['email'],
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null,
      ]);
      final amount = _firstNonEmpty([params['amount'], params['total']]);
      final merchantName = _firstNonEmpty([
        params['merchant_name'],
        params['merchantName'],
        params['merchant'],
      ]);
      final provider = _firstNonEmpty([
        params['provider'],
        params['biller'],
      ]);
      final billCategory = _firstNonEmpty([
        params['bill_category'],
        params['billCategory'],
        params['service'],
        params['category'],
      ]);
      final reference = _firstNonEmpty([
        params['reference'],
        params['ref'],
        params['account'],
        params['meter'],
      ]);
      return ScanPayIntent(
        rawValue: value,
        recipientInput: _normalizeRecipient(recipient),
        amount: amount,
        note: _composeNote(
          explicit: _firstNonEmpty([
            params['note'],
            params['description'],
            merchantName,
          ]),
          merchantName: merchantName,
          provider: provider,
          billCategory: billCategory,
          reference: reference,
        ),
        merchantId: _firstNonEmpty([params['merchant_id'], params['merchantId']]),
        merchantName: merchantName,
        provider: provider,
        billCategory: billCategory,
        reference: reference,
        schemaVersion: _firstNonEmpty([params['v'], params['version']]),
        checksum: _firstNonEmpty([params['checksum'], params['sig']]),
        isOrbiSchema: _isOrbiUri(uri, params),
      );
    }

    if (value.contains('|')) {
      final parts = value.split('|').map((part) => part.trim()).toList();
      if (parts.length >= 5 && parts.first.toUpperCase() == 'ORBI') {
        final schemaVersion = parts.length >= 2 ? parts[1] : null;
        final kind = parts.length >= 3 ? parts[2].toUpperCase() : '';
        final recipient = parts.length >= 4 ? parts[3] : null;
        final amount = parts.length >= 5 ? parts[4] : null;
        final merchantName = parts.length >= 6 ? parts[5] : null;
        final provider = parts.length >= 7 ? parts[6] : null;
        final reference = parts.length >= 8 ? parts[7] : null;
        final checksum = parts.length >= 9 ? parts[8] : null;
        return ScanPayIntent(
          rawValue: value,
          recipientInput: _normalizeRecipient(recipient),
          amount: amount,
          note: _composeNote(
            explicit: null,
            merchantName: merchantName,
            provider: provider,
            billCategory: kind == 'BILL' ? provider : null,
            reference: reference,
          ),
          merchantId: kind == 'MERCHANT' ? recipient : null,
          merchantName: merchantName,
          provider: provider,
          billCategory: kind == 'BILL' ? provider : null,
          reference: reference,
          schemaVersion: schemaVersion,
          checksum: checksum,
          isOrbiSchema: true,
        );
      }
      if (parts.length >= 3) {
        return ScanPayIntent(
          rawValue: value,
          recipientInput: _normalizeRecipient(parts[2]),
          amount: parts.length >= 4 ? parts[3] : null,
          note: parts.length >= 5 ? parts.sublist(4).join(' ') : null,
        );
      }
    }

    return ScanPayIntent(
      rawValue: value,
      recipientInput: _looksLikeRecipient(value) ? value : null,
    );
  }

  ScanPayIntent fromReceipt(ReceiptScanResult result) {
    final merchant = result.merchant.trim();
    final amount = result.amount.toStringAsFixed(2);
    final date = result.date.trim();
    final noteParts = <String>[
      if (merchant.isNotEmpty) merchant,
      if (date.isNotEmpty) date,
    ];
    return ScanPayIntent(
      rawValue:
          '${result.merchant} ${result.amount} ${result.currency} ${result.date}',
      amount: amount,
      note: noteParts.join(' • '),
    );
  }

  dynamic jsonDecodeSafe(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _recipientFromMap(Map<String, dynamic> map) {
    return _normalizeRecipient(
      _firstNonEmpty([
        map['recipient_customer_id']?.toString(),
        map['recipientId']?.toString(),
        map['recipient_id']?.toString(),
        map['customer_id']?.toString(),
        map['customerId']?.toString(),
        map['recipient']?.toString(),
        map['phone']?.toString(),
        map['email']?.toString(),
        map['account']?.toString(),
      ]),
    );
  }

  String? _amountFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['amount']?.toString(),
      map['total']?.toString(),
      map['value']?.toString(),
    ]);
  }

  String? _noteFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['description']?.toString(),
      map['note']?.toString(),
      map['merchant']?.toString(),
      map['merchant_name']?.toString(),
    ]);
  }

  String? _merchantIdFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['merchant_id']?.toString(),
      map['merchantId']?.toString(),
      map['recipient_customer_id']?.toString(),
      map['recipientId']?.toString(),
    ]);
  }

  String? _merchantNameFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['merchant_name']?.toString(),
      map['merchantName']?.toString(),
      map['merchant']?.toString(),
      map['biller_name']?.toString(),
    ]);
  }

  String? _providerFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['provider']?.toString(),
      map['biller']?.toString(),
      map['service_provider']?.toString(),
    ]);
  }

  String? _billCategoryFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['bill_category']?.toString(),
      map['billCategory']?.toString(),
      map['service']?.toString(),
      map['category']?.toString(),
    ]);
  }

  String? _referenceFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['reference']?.toString(),
      map['ref']?.toString(),
      map['account']?.toString(),
      map['meter']?.toString(),
      map['control_number']?.toString(),
    ]);
  }

  String? _schemaVersionFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['schema_version']?.toString(),
      map['schemaVersion']?.toString(),
      map['version']?.toString(),
      map['v']?.toString(),
    ]);
  }

  String? _checksumFromMap(Map<String, dynamic> map) {
    return _firstNonEmpty([
      map['checksum']?.toString(),
      map['signature']?.toString(),
      map['sig']?.toString(),
    ]);
  }

  bool _isOrbiSchemaMap(Map<String, dynamic> map) {
    final marker = _firstNonEmpty([
      map['schema']?.toString(),
      map['namespace']?.toString(),
      map['issuer']?.toString(),
      map['platform']?.toString(),
    ]);
    final version = _schemaVersionFromMap(map);
    final merchantId = _merchantIdFromMap(map);
    if (marker != null && marker.toLowerCase().contains('orbi')) return true;
    return version != null && merchantId != null;
  }

  bool _isOrbiUri(Uri uri, Map<String, String> params) {
    if (uri.scheme.toLowerCase().contains('orbi')) return true;
    final marker = _firstNonEmpty([
      params['schema'],
      params['issuer'],
      params['platform'],
    ]);
    return marker != null && marker.toLowerCase().contains('orbi');
  }

  String? _composeNote({
    required String? explicit,
    required String? merchantName,
    required String? provider,
    required String? billCategory,
    required String? reference,
  }) {
    final parts = <String>[
      if (explicit != null && explicit.trim().isNotEmpty) explicit.trim(),
      if (explicit == null || explicit.trim().isEmpty) ...[
        if (merchantName != null && merchantName.trim().isNotEmpty)
          merchantName.trim(),
        if (provider != null &&
            provider.trim().isNotEmpty &&
            provider.trim() != merchantName?.trim())
          provider.trim(),
      ],
      if (billCategory != null && billCategory.trim().isNotEmpty)
        billCategory.trim(),
      if (reference != null && reference.trim().isNotEmpty)
        'Ref ${reference.trim()}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _normalizeRecipient(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _looksLikeRecipient(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) return true;
    if (RegExp(r'^\+?\d{6,15}$').hasMatch(trimmed)) return true;
    if (RegExp(r'^[A-Za-z0-9\-]{6,}$').hasMatch(trimmed)) return true;
    return false;
  }
}
