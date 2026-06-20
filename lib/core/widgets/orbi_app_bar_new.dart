import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../core/theme/orbi_theme.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/profile/state/profile_controller.dart';
import 'orbi_logo.dart';

class OrbiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onRealtimeStatusTap;
  final int notificationCount;
  final String? realtimeStatusLabel;
  final String? realtimeStatusTooltip;
  final Color? realtimeStatusColor;

  const OrbiAppBar({
    super.key,
    this.onNotificationPressed,
    this.onProfilePressed,
    this.onRealtimeStatusTap,
    this.notificationCount = 0,
    this.realtimeStatusLabel,
    this.realtimeStatusTooltip,
    this.realtimeStatusColor,
  });

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.appBarGreetingMorning;
    if (hour < 17) return l10n.appBarGreetingAfternoon;
    return l10n.appBarGreetingEvening;
  }

  bool _isKycVerifiedStatus(Object? rawStatus) {
    final normalized = rawStatus
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized == null || normalized.isEmpty) return false;

    if (normalized.contains('unverified') ||
        normalized.contains('not_verified') ||
        normalized.contains('incomplete') ||
        normalized.contains('inactive') ||
        normalized.contains('reject') ||
        normalized.contains('declin') ||
        normalized.contains('fail')) {
      return false;
    }

    const exactVerified = {
      'verified',
      'approved',
      'complete',
      'completed',
      'active',
      'kyc_verified',
      'kyc_approved',
      'kyc_complete',
      'kyc_completed',
      'kyc_active',
    };
    if (exactVerified.contains(normalized)) return true;

    return normalized.endsWith('_verified') ||
        normalized.endsWith('_approved') ||
        normalized.endsWith('_complete') ||
        normalized.endsWith('_completed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = OrbiTheme.uiOf(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 390;
    final veryCompact = screenWidth < 350;
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthController>();
    final profileCtrl = context.watch<ProfileController>();
    final profile = profileCtrl.profile;
    final userSessionMap = auth.session['user'] is Map
        ? Map<String, dynamic>.from(auth.session['user'] as Map)
        : <String, dynamic>{};
    final mergedProfile = {...userSessionMap, ...profile};

    // Extracting real user name from session metadata (robust)
    String userName = 'User';
    final userObj = mergedProfile;
    final nameCandidates = [
      userObj['full_name'],
      userObj['fullName'],
      userObj['name'],
      (userObj['first_name'] != null)
          ? '${userObj['first_name']}${userObj['last_name'] != null ? ' ${userObj['last_name']}' : ''}'
          : null,
    ];

    final found = nameCandidates.firstWhere(
      (c) => c != null && c.toString().trim().isNotEmpty,
      orElse: () => null,
    );

    if (found != null) {
      userName = found.toString();
    } else if (userObj['email'] != null && userObj['email'] is String) {
      userName = userObj['email'];
      debugPrint('ℹ️ OrbiAppBar: using email as fallback username ($userName)');
    } else {
      debugPrint(
        '⚠️ OrbiAppBar: user map present but no name/email field. keys=${userObj.keys}',
      );
    }

    // Prefer last name for greeting if multiple words
    String displayName = userName.trim();
    if (displayName.contains(' ')) {
      final parts = displayName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        displayName = parts.last;
      }
    }

    final greeting = _getGreeting(l10n);
    final userMap = mergedProfile;
    final kycStatus =
        userMap['kyc_status'] ??
        userMap['kycStatus'] ??
        (userMap['kyc'] is Map ? (userMap['kyc'] as Map)['status'] : null);
    final kycLevelRaw =
        userMap['kyc_level'] ??
        userMap['kycLevel'] ??
        (userMap['kyc'] is Map ? (userMap['kyc'] as Map)['level'] : null);
    final kycLevel = int.tryParse('${kycLevelRaw ?? ''}') ?? 0;
    final isVerified = kycLevel > 0 || _isKycVerifiedStatus(kycStatus);
    final rawAvatarUrl =
        (mergedProfile['avatar_url'] ??
                mergedProfile['avatarUrl'] ??
                mergedProfile['profile_photo_url'] ??
                mergedProfile['photo_url'])
            ?.toString();
    final avatarUrl = rawAvatarUrl != null && rawAvatarUrl.isNotEmpty
        ? '$rawAvatarUrl${rawAvatarUrl.contains('?') ? '&' : '?'}v=${profileCtrl.avatarRefreshTick}'
        : null;
    final customerId =
        [
          mergedProfile['customer_id'],
          mergedProfile['customerId'],
          mergedProfile['customerID'],
          (mergedProfile['user_metadata'] is Map
              ? (mergedProfile['user_metadata'] as Map)['customer_id']
              : null),
          (mergedProfile['user_metadata'] is Map
              ? (mergedProfile['user_metadata'] as Map)['customerId']
              : null),
          mergedProfile['fnx_id'],
          mergedProfile['fnxId'],
          auth.session['customer_id'],
          auth.session['customerId'],
        ].firstWhere(
          (v) => v != null && v.toString().trim().isNotEmpty,
          orElse: () => null,
        );
    final customerIdText = customerId?.toString() ?? 'Not available';
    return Container(
      decoration: BoxDecoration(
        color: isDark ? ui.appBarMid.withValues(alpha: 0.98) : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFAFCFD),
                  Color(0xFFF0F8FA),
                ],
                stops: [0.0, 0.62, 1.0],
              ),
        border: isDark
            ? Border(
                bottom: BorderSide(
                  color: ui.border.withValues(alpha: 0.58),
                  width: 0.9,
                ),
              )
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: compact ? 12 : 18,
              right: compact ? 12 : 18,
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    _LogoBrandLockup(
                      width: veryCompact
                          ? 58
                          : compact
                          ? 66
                          : 72,
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$greeting, $displayName',
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: compact ? 14.0 : 15.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.34,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${l10n.appBarCustomerIdLabel}: $customerIdText',
                            style: TextStyle(
                              color: ui.textMuted.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.96
                                    : 0.9,
                              ),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (realtimeStatusLabel != null &&
                              realtimeStatusLabel!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Tooltip(
                              message:
                                  realtimeStatusTooltip ?? realtimeStatusLabel!,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onRealtimeStatusTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (realtimeStatusColor ?? ui.accent)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: (realtimeStatusColor ?? ui.accent)
                                          .withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color:
                                              realtimeStatusColor ?? ui.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        realtimeStatusLabel!,
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: compact ? 42 : 44,
                          width: compact ? 42 : 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? ui.card.withValues(alpha: 0.82)
                                : const Color(0xFFE6F3F7),
                            shape: BoxShape.circle,
                            border: isDark
                                ? Border.all(
                                    color: ui.border.withValues(alpha: 0.92),
                                  )
                                : null,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.notifications_none,
                              color: isDark
                                  ? ui.iconMuted
                                  : const Color(0xFF07566B),
                              size: compact ? 22 : 24,
                            ),
                            onPressed: onNotificationPressed,
                          ),
                        ),
                        if (notificationCount > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              height: 16,
                              constraints: const BoxConstraints(minWidth: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ui.success,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                notificationCount > 99
                                    ? '99+'
                                    : notificationCount.toString(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: compact ? 7 : 9),
                    GestureDetector(
                      onTap: onProfilePressed,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _AnimatedProfileRingAvatar(
                            size: compact ? 48 : 52,
                            initial: displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            avatarUrl: avatarUrl,
                            verified: isVerified,
                          ),
                          if (isVerified)
                            Positioned(
                              right: -2,
                              bottom: -1,
                              child: Container(
                                width: isDark ? null : 16,
                                height: isDark ? null : 16,
                                padding: isDark
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      )
                                    : EdgeInsets.zero,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF57B26F)
                                      : const Color(0xFF0B6174),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? ui.card
                                        : const Color(0xFFF3F9FB),
                                    width: isDark ? 0.8 : 2,
                                  ),
                                  boxShadow: isDark
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x55000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isDark
                                    ? const Row(
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            size: 9,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'KYC',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size(double.infinity, 74);
}

class _LogoBrandLockup extends StatelessWidget {
  const _LogoBrandLockup({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: Center(child: OrbiLogoV2(width: width)),
    );
  }
}

class _AnimatedProfileRingAvatar extends StatefulWidget {
  final double size;
  final String initial;
  final String? avatarUrl;
  final bool verified;

  const _AnimatedProfileRingAvatar({
    required this.size,
    required this.initial,
    this.avatarUrl,
    this.verified = false,
  });

  @override
  State<_AnimatedProfileRingAvatar> createState() =>
      _AnimatedProfileRingAvatarState();
}

class _AnimatedProfileRingAvatarState extends State<_AnimatedProfileRingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    if (!isDark) {
      return Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF42C5DC), Color(0xFF1596B3), Color(0xFF073B4C)],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F9FB),
            shape: BoxShape.circle,
          ),
          child: _avatarFace(ui, hasAvatar, widget.size - 9),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ui.accent.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _OrbitRingPainter(
                    primary: (widget.verified ? ui.success : ui.accent)
                        .withValues(alpha: isDark ? 0.98 : 0.92),
                    secondary: (isDark ? Colors.white : ui.iconMuted)
                        .withValues(alpha: isDark ? 0.92 : 0.78),
                    highlight: (isDark ? Colors.white : Colors.white)
                        .withValues(alpha: isDark ? 0.82 : 0.96),
                    track: (isDark ? const Color(0xFF111821) : ui.cardStrong)
                        .withValues(alpha: isDark ? 0.88 : 0.86),
                  ),
                ),
              ),
              Container(
                width: widget.size - 6,
                height: widget.size - 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ui.card.withValues(alpha: 0.96),
                  border: Border.all(
                    color: ui.borderStrong.withValues(alpha: 0.76),
                  ),
                ),
                child: _avatarFace(ui, hasAvatar, widget.size - 8),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarFace(OrbiUiTokens ui, bool hasAvatar, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: ui.cardStrong,
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                widget.avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _avatarInitial(ui);
                },
              )
            : _avatarInitial(ui),
      ),
    );
  }

  Widget _avatarInitial(OrbiUiTokens ui) {
    return Center(
      child: Text(
        widget.initial,
        style: TextStyle(
          color: ui.textPrimary,
          fontSize: widget.size * 0.31,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.primary,
    required this.secondary,
    required this.highlight,
    required this.track,
  });

  final Color primary;
  final Color secondary;
  final Color highlight;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(
      center: center,
      radius: (size.width / 2) - 2.4,
    );
    final atomGlowRect = Rect.fromCircle(
      center: center,
      radius: (size.width / 2) - 6,
    );
    final atomCoreRect = Rect.fromCircle(
      center: center,
      radius: (size.width / 2) - 11,
    );
    final bridge = Color.lerp(primary, secondary, 0.42) ?? primary;
    final softWhite = Color.lerp(highlight, primary, 0.22) ?? highlight;
    final deepMix = Color.lerp(track, secondary, 0.58) ?? track;
    final trackPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          softWhite.withValues(alpha: 0.88),
          primary.withValues(alpha: 0.98),
          bridge.withValues(alpha: 0.96),
          secondary.withValues(alpha: 0.92),
          deepMix.withValues(alpha: 0.88),
          primary.withValues(alpha: 0.86),
          softWhite.withValues(alpha: 0.88),
        ],
        stops: const [0.0, 0.12, 0.28, 0.46, 0.66, 0.84, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          softWhite.withValues(alpha: 0.34),
          bridge.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.24, 0.62, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.6
      ..strokeCap = StrokeCap.round;
    final flashPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          softWhite.withValues(alpha: 0.24),
          highlight,
          bridge.withValues(alpha: 0.58),
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 0.5, 0.64, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    final atomEmitterPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          softWhite.withValues(alpha: 0.24),
          primary.withValues(alpha: 0.16),
          bridge.withValues(alpha: 0.10),
          secondary.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.24, 0.48, 0.68, 1.0],
      ).createShader(atomGlowRect)
      ..style = PaintingStyle.fill;
    final atomCorePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          deepMix.withValues(alpha: 0.96),
          track.withValues(alpha: 0.98),
          track.withValues(alpha: 0.82),
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(atomCoreRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, (size.width / 2) - 6, atomEmitterPaint);
    canvas.drawCircle(center, (size.width / 2) - 11, atomCorePaint);
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(rect, -math.pi / 3, math.pi * 1.2, false, glowPaint);
    canvas.drawArc(rect, -math.pi * 0.05, math.pi * 0.28, false, flashPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.highlight != highlight ||
        oldDelegate.track != track;
  }
}
