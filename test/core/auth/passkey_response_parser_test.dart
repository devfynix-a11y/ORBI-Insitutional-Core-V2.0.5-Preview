import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_mobileapp/core/auth/passkey_response_parser.dart';

void main() {
  group('PasskeyResponseParser.requiresOtpChallenge', () {
    test('does not force OTP when passkey options already exist', () {
      final payload = <String, dynamic>{
        'requestId': 'req_123',
        'options': <String, dynamic>{
          'challenge': 'abc123',
          'rp': <String, dynamic>{'id': 'example.com'},
          'pubKeyCredParams': const [],
        },
      };

      expect(PasskeyResponseParser.hasOptions(payload), isTrue);
      expect(PasskeyResponseParser.requiresOtpChallenge(payload), isFalse);
    });

    test('requires OTP when backend explicitly signals challenge', () {
      final payload = <String, dynamic>{
        'status': 'CHALLENGE_REQUIRED',
        'requestId': 'req_123',
      };

      expect(PasskeyResponseParser.requiresOtpChallenge(payload), isTrue);
    });

    test(
      'requires OTP when only request id is returned and no options exist',
      () {
        final payload = <String, dynamic>{
          'requestId': 'req_123',
          'data': <String, dynamic>{},
        };

        expect(PasskeyResponseParser.hasOptions(payload), isFalse);
        expect(PasskeyResponseParser.requiresOtpChallenge(payload), isTrue);
      },
    );
  });
}
