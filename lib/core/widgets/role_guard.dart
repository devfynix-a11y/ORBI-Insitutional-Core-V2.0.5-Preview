import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/state/auth_controller.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final role = auth.orgRole.toUpperCase();
    final isAllowed =
        allowedRoles.map((e) => e.toUpperCase()).contains(role);
    if (isAllowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
