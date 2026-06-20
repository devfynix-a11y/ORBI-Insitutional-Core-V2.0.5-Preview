import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../storage/secure_storage_service.dart';
import 'security_otp_dialog.dart';

Future<bool> promptPinSetup(BuildContext context) async {
  bool valid = false;
  String pin = '';
  String confirm = '';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(l10n.settingsSetPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              onChanged: (value) => pin = value,
              decoration: InputDecoration(labelText: l10n.loginPinLabel),
            ),
            TextField(
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              onChanged: (value) => confirm = value,
              decoration: InputDecoration(labelText: l10n.pinConfirmLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionSave),
          ),
        ],
      );
    },
  );

  if (result == true) {
    final trimmedPin = pin.trim();
    final trimmedConfirm = confirm.trim();
    if (trimmedPin.length >= 4 &&
        trimmedPin.length <= 6 &&
        trimmedPin == trimmedConfirm) {
      await SecureStorageService().setPin(trimmedPin);
      valid = true;
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsPinsInvalidMessage,
          ),
        ),
      );
    }
  }

  return valid;
}

Future<String?> promptCurrentPin(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return showSecurityCodeDialog(
    context: context,
    title: l10n.loginEnterPinTitle,
    helperText: l10n.loginUsePinInstead,
    fieldLabel: l10n.loginPinLabel,
    confirmLabel: l10n.actionUnlock,
    cancelLabel: l10n.actionCancel,
    maxLength: 6,
    minLength: 4,
    obscureText: true,
    digitsOnly: true,
    keyboardType: TextInputType.number,
  );
}
