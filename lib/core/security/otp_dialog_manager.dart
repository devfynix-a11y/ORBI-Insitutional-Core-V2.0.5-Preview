import 'package:flutter/material.dart';

import '../widgets/security_otp_dialog.dart';

class OtpDialogManager {
  static Future<String?> requestOtpFromUser(
    BuildContext context,
    String message,
  ) {
    return showSecurityOtpDialog(
      context: context,
      title: 'Security Verification',
      helperText: message,
    );
  }
}
