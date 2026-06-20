import 'package:dio/dio.dart';
import '../security/otp_dialog_manager.dart';
import '../../globals.dart';

class OrbiSecurityInterceptor extends Interceptor {
  final Dio dio;
  OrbiSecurityInterceptor(this.dio);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final data = response.data;
    if (data is Map && data['status'] == 'STEP_UP_REQUIRED') {
      final requestId = data['requestId'];
      final message = data['message'] ?? 'Please enter your OTP.';
      final tempToken = data['tempToken'];
      final otpCode = await OtpDialogManager.requestOtpFromUser(globalNavigatorKey.currentContext!, message);
      if (otpCode == null || otpCode.isEmpty) {
        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            error: 'OTP Verification Cancelled',
          ),
        );
      }
      try {
        final verifyResponse = await dio.post(
          '/api/v1/auth/verify',
          data: {
            'requestId': requestId,
            'code': otpCode,
          },
          options: Options(
            headers: tempToken != null ? {'Authorization': 'Bearer $tempToken'} : null,
          ),
        );
        if (verifyResponse.data['success'] == true) {
          final retryResponse = await dio.request(
            response.requestOptions.path,
            options: Options(
              method: response.requestOptions.method,
              headers: response.requestOptions.headers,
            ),
            data: response.requestOptions.data,
            queryParameters: response.requestOptions.queryParameters,
          );
          return handler.resolve(retryResponse);
        } else {
          return handler.reject(
            DioException(requestOptions: response.requestOptions, error: 'Invalid OTP'),
          );
        }
      } catch (e) {
        return handler.reject(
          DioException(requestOptions: response.requestOptions, error: 'Verification Failed'),
        );
      }
    }
    super.onResponse(response, handler);
  }
}
