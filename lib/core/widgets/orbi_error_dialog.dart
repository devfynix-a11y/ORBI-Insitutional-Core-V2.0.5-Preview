import 'package:flutter/material.dart';
import '../theme/orbi_theme.dart';

/// Beautiful error dialog that matches ORBI's theme and supports localization
///
/// Usage:
/// ```dart
/// await OrbiErrorDialog.show(
///   context: context,
///   title: 'Transaction Failed',
///   message: 'Insufficient funds in your account.',
///   icon: Icons.wallet_outlined,
/// );
/// ```
class OrbiErrorDialog {
  /// Show an error dialog with optional retry action
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.error_outline_rounded,
    String? actionLabel,
    VoidCallback? onAction,
    bool barrierDismissible = true,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return _ErrorDialogContent(
          title: title,
          message: message,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          barrierDismissible: barrierDismissible,
        );
      },
    );

    return result ?? false;
  }

  /// Show network error
  static Future<bool> showNetworkError(
    BuildContext context, {
    String? customMessage,
  }) =>
      show(
        context: context,
        title: 'Connection Error',
        message: customMessage ?? 'Unable to connect. Please check your internet.',
        icon: Icons.wifi_off_rounded,
      );

  /// Show session expired error
  static Future<bool> showSessionExpired(BuildContext context) =>
      show(
        context: context,
        title: 'Session Expired',
        message: 'Your session has ended. Please log in again.',
        icon: Icons.lock_clock_rounded,
      );

  /// Show generic error
  static Future<bool> showGeneric(
    BuildContext context, {
    required String message,
  }) =>
      show(
        context: context,
        title: 'Something Went Wrong',
        message: message,
        icon: Icons.error_outline_rounded,
      );
}

class _ErrorDialogContent extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool barrierDismissible;

  const _ErrorDialogContent({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    required this.barrierDismissible,
  });

  @override
  State<_ErrorDialogContent> createState() => _ErrorDialogContentState();
}

class _ErrorDialogContentState extends State<_ErrorDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: widget.barrierDismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: ui.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ui.border.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (theme.brightness == Brightness.dark
                          ? Colors.black
                          : Colors.black)
                      .withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon with animated entrance
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ui.danger.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: ui.danger,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Message
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.barrierDismissible
                              ? () => Navigator.of(context).pop(false)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: ui.border,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null && widget.onAction != null)
                        ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                                widget.onAction?.call();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: ui.danger,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
