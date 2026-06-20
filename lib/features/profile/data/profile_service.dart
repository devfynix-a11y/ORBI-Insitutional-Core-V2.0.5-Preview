import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';

class ProfileService {
  final Dio _dio = ApiClient().client;

  String _lookupPathForCustomer(String customerId) {
    final template =
        AppConfig.endpoints['lookupByCustomerTemplate'] ??
        '/user/lookup/{customerId}';
    return template.replaceFirst(
      '{customerId}',
      Uri.encodeComponent(customerId),
    );
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _dio.get(AppConfig.endpoints['profile']!);
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return _normalizeProfileMap(
      Map<String, dynamic>.from((data as Map?) ?? {}),
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      AppConfig.endpoints['profile']!,
      data: payload,
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return _normalizeProfileMap(
      Map<String, dynamic>.from((data as Map?) ?? {}),
    );
  }

  Future<Map<String, dynamic>> validateSession() async {
    final response = await _dio.get(
      AppConfig.endpoints['session'] ?? '/auth/session',
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> updateLoginInfo(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      AppConfig.endpoints['loginInfo'] ?? '/user/login-info',
      data: payload,
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<List<Map<String, dynamic>>> lookupUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const <Map<String, dynamic>>[];

    final response = await _dio.get(
      AppConfig.endpoints['lookup'] ?? '/user/lookup',
      queryParameters: {'q': trimmed},
    );
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final items = data['items'] ?? data['results'] ?? data['users'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> lookupUserByCustomerId(String customerId) async {
    final response = await _dio.get(_lookupPathForCustomer(customerId.trim()));
    final data = response.data is Map<String, dynamic>
        ? response.data['data'] ?? response.data
        : response.data;
    return Map<String, dynamic>.from((data as Map?) ?? {});
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(String filePath) async {
    String? lastError;
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final avatarPath = AppConfig.endpoints['avatar'] ?? '/user/avatar';

    try {
      final rawBinary = await _uploadAvatarRawBinary(
        path: avatarPath,
        filePath: filePath,
      );
      if (rawBinary.isNotEmpty) {
        return rawBinary;
      }
    } on DioException catch (e) {
      lastError =
          'Upload failed on POST $avatarPath (raw): ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}';
      debugPrint(lastError);
    } catch (e) {
      lastError = 'Upload failed on POST $avatarPath (raw): $e';
      debugPrint(lastError);
    }

    final candidates = <({String path, String method, String field})>[
      (path: avatarPath, method: 'POST', field: 'file'),
      (path: avatarPath, method: 'POST', field: 'image'),
      (path: avatarPath, method: 'POST', field: 'avatar'),
      (path: '/user/profile/avatar', method: 'PATCH', field: 'avatar'),
      (path: '/user/profile/photo', method: 'POST', field: 'photo'),
      (path: '/user/profile/photo', method: 'POST', field: 'file'),
      (path: AppConfig.endpoints['profile']!, method: 'PATCH', field: 'avatar'),
      (path: AppConfig.endpoints['profile']!, method: 'PATCH', field: 'photo'),
      (path: AppConfig.endpoints['profile']!, method: 'PATCH', field: 'file'),
    ];

    for (final c in candidates) {
      try {
        // NOTE: FormData is single-use in Dio; recreate for each retry attempt.
        final formData = FormData.fromMap({
          c.field: await MultipartFile.fromFile(filePath, filename: fileName),
        });

        final response = c.method == 'POST'
            ? await _dio.post(
                c.path,
                data: formData,
                options: Options(contentType: 'multipart/form-data'),
              )
            : await _dio.patch(
                c.path,
                data: formData,
                options: Options(contentType: 'multipart/form-data'),
              );
        final data = response.data is Map<String, dynamic>
            ? response.data['data'] ?? response.data
            : response.data;
        if (data is Map) {
          return _normalizeProfileMap(Map<String, dynamic>.from(data));
        }
      } on DioException catch (e) {
        lastError =
            'Upload failed on ${c.method} ${c.path}: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}';
        debugPrint(lastError);
        if (_isFormatError(e)) {
          final fallback = await _uploadBase64(
            path: c.path,
            filePath: filePath,
            fieldCandidates: const ['image', 'file', 'avatar'],
          );
          if (fallback != null) return fallback;
        }
      } catch (e) {
        lastError = 'Upload failed on ${c.method} ${c.path}: $e';
        debugPrint(lastError);
      }
    }

    throw Exception(
      lastError ??
          'Failed to upload profile photo. Supported: multipart/form-data, raw binary, or base64 JSON (PNG/JPG/JPEG/HEIC/HEIF/WEBP, max 20MB).',
    );
  }

  Future<Map<String, dynamic>> submitKyc({
    required String fullName,
    required String idType,
    required String idNumber,
    required String imagePath,
  }) async {
    final fileName = imagePath.split(RegExp(r'[\\/]')).last;
    String? lastError;

    final kycUploadPath =
        AppConfig.endpoints['kycUpload'] ?? '/user/kyc/upload';
    final kycSubmitPath = AppConfig.endpoints['kycSubmit'] ?? '/user/kyc';

    // Preferred flow: upload raw doc -> submit JSON with URLs.
    try {
      final uploadPayload = await _uploadKycDocument(
        path: kycUploadPath,
        filePath: imagePath,
        fileName: fileName,
      );
      final uploadedUrl = _extractUploadUrl(uploadPayload);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        final submitted = await _submitKycJson(
          path: kycSubmitPath,
          fullName: fullName,
          idType: idType,
          idNumber: idNumber,
          documentUrl: uploadedUrl,
          selfieUrl: uploadedUrl,
        );
        return submitted;
      }
    } catch (e) {
      lastError = 'KYC upload/submit failed: $e';
      debugPrint(lastError);
    }

    final candidates = <({String path, String method, String imageField})>[
      (path: kycUploadPath, method: 'POST', imageField: 'file'),
      (path: kycUploadPath, method: 'POST', imageField: 'image'),
      (path: '/user/kyc/submit', method: 'POST', imageField: 'file'),
      (path: '/user/kyc/submit', method: 'POST', imageField: 'image'),
      (path: kycSubmitPath, method: 'POST', imageField: 'file'),
      (path: kycSubmitPath, method: 'POST', imageField: 'image'),
      (path: '/user/profile/kyc', method: 'POST', imageField: 'file'),
      (path: '/user/profile/kyc', method: 'POST', imageField: 'image'),
    ];

    for (final c in candidates) {
      try {
        final formData = FormData.fromMap({
          'full_name': fullName,
          'id_type': idType,
          'id_number': idNumber,
          c.imageField: await MultipartFile.fromFile(
            imagePath,
            filename: fileName,
          ),
        });

        final response = c.method == 'POST'
            ? await _dio.post(
                c.path,
                data: formData,
                options: Options(contentType: 'multipart/form-data'),
              )
            : await _dio.patch(
                c.path,
                data: formData,
                options: Options(contentType: 'multipart/form-data'),
              );
        final data = response.data is Map<String, dynamic>
            ? response.data['data'] ?? response.data
            : response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return {};
        }
      } on DioException catch (e) {
        lastError =
            'KYC submit failed on ${c.method} ${c.path}: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}';
        debugPrint(lastError);
        if (_isFormatError(e)) {
          final fallback = await _submitKycBase64(
            path: c.path,
            fullName: fullName,
            idType: idType,
            idNumber: idNumber,
            imagePath: imagePath,
            imageField: c.imageField,
          );
          if (fallback != null) return fallback;
        }
      } catch (e) {
        lastError = 'KYC submit failed on ${c.method} ${c.path}: $e';
        debugPrint(lastError);
      }
    }

    throw Exception(
      lastError ??
          'Failed to submit KYC. Supported: multipart/form-data or base64 JSON image (max 20MB).',
    );
  }

  Future<Map<String, dynamic>> scanKycDocument(String imagePath) async {
    final fileName = imagePath.split(RegExp(r'[\\/]')).last;
    String? lastError;

    final scanPath = AppConfig.endpoints['kycScan'] ?? '/user/kyc/scan';
    final candidates = <({String path, String fileField})>[
      (path: scanPath, fileField: 'file'),
      (path: scanPath, fileField: 'image'),
      (path: scanPath, fileField: 'document'),
    ];

    for (final c in candidates) {
      try {
        final formData = FormData.fromMap({
          c.fileField: await MultipartFile.fromFile(
            imagePath,
            filename: fileName,
          ),
        });

        final response = await _dio.post(
          c.path,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        final payload = response.data;
        final data = payload is Map<String, dynamic>
            ? payload['data'] ?? payload
            : payload;
        final source = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final normalized = _normalizeKycScan(source);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      } on DioException catch (e) {
        lastError =
            'KYC scan failed on POST ${c.path}: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}';
        debugPrint(lastError);
        if (_isFormatError(e)) {
          final fallback = await _scanKycBase64(
            path: c.path,
            imagePath: imagePath,
            field: c.fileField,
          );
          if (fallback != null && fallback.isNotEmpty) {
            return fallback;
          }
        }
      } catch (e) {
        lastError = 'KYC scan failed on POST ${c.path}: $e';
        debugPrint(lastError);
      }
    }

    throw Exception(
      lastError ??
          'Failed to scan KYC document. Upload a clear PNG/JPG/JPEG/HEIC/HEIF/WEBP image (max 20MB).',
    );
  }

  Map<String, dynamic> _normalizeKycScan(Map<String, dynamic> raw) {
    final extracted = raw['extracted'] is Map
        ? Map<String, dynamic>.from(raw['extracted'] as Map)
        : (raw['ocr'] is Map
              ? Map<String, dynamic>.from(raw['ocr'] as Map)
              : raw);

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = extracted[key] ?? raw[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final fullName = pick([
      'full_name',
      'fullName',
      'name',
      'id_name',
      'document_name',
      'holder_name',
    ]);
    final idNumber = pick([
      'id_number',
      'idNumber',
      'document_number',
      'documentNumber',
      'national_id',
      'nationalId',
      'passport_number',
      'passportNumber',
      'id_no',
    ]);
    final idType = pick([
      'id_type',
      'idType',
      'document_type',
      'documentType',
      'type',
    ]);
    final dob = pick(['dob', 'date_of_birth', 'dateOfBirth', 'birth_date']);

    final normalized = <String, dynamic>{};
    if (fullName != null) normalized['full_name'] = fullName;
    if (idNumber != null) normalized['id_number'] = idNumber;
    if (idType != null) normalized['id_type'] = idType;
    if (dob != null) normalized['dob'] = dob;
    if (normalized.isNotEmpty) {
      normalized['raw'] = raw;
    }
    return normalized;
  }

  String _inferImageContentType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg')) return 'image/jpg';
    if (lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.webp')) return 'image/webp';
    // Safe default for unknown extension.
    return 'application/octet-stream';
  }

  dynamic _extractPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw['data'] ?? raw;
    return raw;
  }

  Map<String, dynamic> _normalizeProfileMap(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    for (final key in const [
      'avatar_url',
      'avatarUrl',
      'profile_photo_url',
      'photo_url',
    ]) {
      final value = normalized[key];
      if (value is String && value.trim().isNotEmpty) {
        normalized[key] = _normalizeUrl(value.trim());
      }
    }
    return normalized;
  }

  String _normalizeUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = AppConfig.baseUrl;
    if (raw.startsWith('/')) {
      return '$base$raw';
    }
    return '$base/$raw';
  }

  bool _isFormatError(DioException e) {
    final status = e.response?.statusCode ?? 0;
    if (status == 400 || status == 415 || status == 422) return true;
    final body = e.response?.data?.toString().toLowerCase() ?? '';
    return body.contains('invalid file format') ||
        body.contains('unsupported') ||
        body.contains('mime') ||
        body.contains('file format');
  }

  Future<String> _toDataUri(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final mime = _inferImageContentType(filePath);
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded';
  }

  Future<Map<String, dynamic>?> _uploadBase64({
    required String path,
    required String filePath,
    required List<String> fieldCandidates,
  }) async {
    final dataUri = await _toDataUri(filePath);
    for (final field in fieldCandidates) {
      try {
        final response = await _dio.post(path, data: {field: dataUri});
        final data = _extractPayload(response.data);
        if (data is Map) {
          return _normalizeProfileMap(Map<String, dynamic>.from(data));
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>> _uploadKycDocument({
    required String path,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final response = await _dio.post(
        path,
        data: Stream.fromIterable(bytes.map((b) => [b])),
        options: Options(
          contentType: _inferImageContentType(filePath),
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
      final data = _extractPayload(response.data);
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } on DioException catch (e) {
      debugPrint(
        'KYC upload (raw) failed on POST $path: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      debugPrint('KYC upload (raw) failed on POST $path: $e');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = _extractPayload(response.data);
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw Exception('KYC upload returned an invalid response.');
  }

  Future<Map<String, dynamic>> _submitKycJson({
    required String path,
    required String fullName,
    required String idType,
    required String idNumber,
    required String documentUrl,
    required String selfieUrl,
  }) async {
    final response = await _dio.post(
      path,
      data: {
        'full_name': fullName,
        'id_type': idType,
        'id_number': idNumber,
        'document_url': documentUrl,
        'selfie_url': selfieUrl,
      },
    );
    final data = _extractPayload(response.data);
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return <String, dynamic>{};
    }
    throw Exception('KYC submit returned an invalid response.');
  }

  String? _extractUploadUrl(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['url'],
      payload['file_url'],
      payload['fileUrl'],
      payload['document_url'],
      payload['documentUrl'],
      payload['selfie_url'],
      payload['selfieUrl'],
    ];
    final data = payload['data'];
    if (data is Map) {
      candidates.addAll([
        data['url'],
        data['file_url'],
        data['fileUrl'],
        data['document_url'],
        data['documentUrl'],
        data['selfie_url'],
        data['selfieUrl'],
      ]);
    }
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _uploadAvatarRawBinary({
    required String path,
    required String filePath,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final response = await _dio.post(
      path,
      data: Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        contentType: _inferImageContentType(filePath),
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
    final data = _extractPayload(response.data);
    if (data is Map) {
      return _normalizeProfileMap(Map<String, dynamic>.from(data));
    }
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return <String, dynamic>{};
    }
    throw Exception('Avatar upload returned an invalid response.');
  }

  Future<Map<String, dynamic>?> _submitKycBase64({
    required String path,
    required String fullName,
    required String idType,
    required String idNumber,
    required String imagePath,
    required String imageField,
  }) async {
    final dataUri = await _toDataUri(imagePath);
    final fields = <String>{imageField, 'image', 'file'};
    for (final field in fields) {
      try {
        final response = await _dio.post(
          path,
          data: {
            'full_name': fullName,
            'id_type': idType,
            'id_number': idNumber,
            field: dataUri,
          },
        );
        final data = _extractPayload(response.data);
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return <String, dynamic>{};
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> _scanKycBase64({
    required String path,
    required String imagePath,
    required String field,
  }) async {
    final dataUri = await _toDataUri(imagePath);
    final fields = <String>{field, 'image', 'file', 'document'};
    for (final key in fields) {
      try {
        final response = await _dio.post(path, data: {key: dataUri});
        final data = _extractPayload(response.data);
        final source = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        final normalized = _normalizeKycScan(source);
        if (normalized.isNotEmpty) return normalized;
      } catch (_) {}
    }
    return null;
  }
}
