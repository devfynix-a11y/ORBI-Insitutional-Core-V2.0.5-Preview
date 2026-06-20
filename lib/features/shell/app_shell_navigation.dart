part of 'app_shell.dart';

extension on _AppShellState {
  Widget _buildGlassBottomNav({required int currentIndex}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    const lightSelectedNav = Color(0xFF0D3A4A);
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;
    final items = <_NavSpec>[
      _NavSpec(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        index: 0,
        label: l10n.shellNavHome,
        assetPath: 'assets/icons/home.svg',
      ),
      _NavSpec(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet,
        index: 1,
        label: l10n.walletTitle,
        assetPath: 'assets/icons/wallet.svg',
      ),
      _NavSpec(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        index: 2,
        label: l10n.shellNavTransactions,
        assetPath: 'assets/icons/transactions.svg',
      ),
      _NavSpec(
        icon: Icons.flag_outlined,
        activeIcon: Icons.flag,
        index: 3,
        label: l10n.shellNavGoals,
        assetPath: 'assets/icons/goal.svg',
      ),
    ];
    final leftItems = items.take(2).toList();
    final rightItems = items.skip(2).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        const fabDiameter = 62.0;
        final compactNav = constraints.maxWidth < 390;
        final shortNav = screenHeight < 760;
        final ultraCompactNav =
            constraints.maxWidth < 350 || screenHeight < 700;
        final fabCutoutRadius = (fabDiameter / 2) + 4.0;
        final navBottomOffset = bottomInset;
        final navHeight = ultraCompactNav
            ? 54.0
            : shortNav || compactNav
            ? 54.0
            : 58.0;
        final navRadius = ultraCompactNav
            ? 22.0
            : compactNav
            ? 26.0
            : 30.0;
        final centerGap = ultraCompactNav
            ? 68.0
            : compactNav
            ? 74.0
            : 82.0;
        final navDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ui.card.withValues(alpha: isDark ? 0.94 : 0.98),
              Color.lerp(
                ui.cardStrong,
                ui.card,
                isDark ? 0.20 : 0.55,
              )!.withValues(alpha: isDark ? 0.96 : 0.99),
              Color.lerp(
                ui.cardMuted,
                ui.cardStrong,
                isDark ? 0.28 : 0.35,
              )!.withValues(alpha: isDark ? 0.97 : 1),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(navRadius + 6),
            topRight: Radius.circular(navRadius + 6),
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? ui.accent.withValues(alpha: 0.18)
                  : ui.borderStrong.withValues(alpha: 0.52),
              width: 0.9,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.07),
              blurRadius: isDark ? 24 : 18,
              spreadRadius: isDark ? 0.5 : 0.12,
              offset: const Offset(0, -8),
            ),
          ],
        );
        return Container(
          color: Colors.transparent,
          child: MediaQuery.removeViewPadding(
            context: context,
            removeBottom: true,
            child: ClipPath(
              clipper: _BottomNavFabCutoutClipper(
                radius: fabCutoutRadius,
                cornerRadius: navRadius + 6,
              ),
              child: CustomPaint(
                foregroundPainter: _BottomNavOutlinePainter(
                  radius: fabCutoutRadius,
                  cornerRadius: navRadius + 6,
                  color: isDark
                      ? ui.accent.withValues(alpha: 0.12)
                      : lightSelectedNav.withValues(alpha: 0.12),
                ),
                child: DecoratedBox(
                  decoration: navDecoration,
                  child: SizedBox(
                    height: navHeight + navBottomOffset,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 6,
                        right: 6,
                        top: 4,
                        bottom: navBottomOffset,
                      ),
                      child: Row(
                        children: [
                          for (final item in leftItems)
                            Expanded(
                              child: _navItem(
                                item: item,
                                currentIndex: currentIndex,
                                compact: compactNav || shortNav,
                                ultraCompact: ultraCompactNav,
                              ),
                            ),
                          SizedBox(width: centerGap),
                          for (final item in rightItems)
                            Expanded(
                              child: _navItem(
                                item: item,
                                currentIndex: currentIndex,
                                compact: compactNav || shortNav,
                                ultraCompact: ultraCompactNav,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem({
    required _NavSpec item,
    required int currentIndex,
    required bool compact,
    required bool ultraCompact,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);
    final surfaces = OrbiTheme.surfacesOf(context);
    final isSelected = currentIndex == item.index;
    const lightSelectedNav = Color(0xFF0D3A4A);

    return GestureDetector(
      key: ValueKey<String>('shell-nav-${item.index}'),
      onTap: () async {
        await HapticFeedback.lightImpact();
        unawaited(_animateNavPress(item.index));
        _onTap(item.index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ultraCompact
              ? 2
              : compact
              ? 4
              : 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedRotation(
              // Future Rive hook: replace this icon subtree with a Rive widget
              // per nav item once ORBI exports .riv state machines. Keep the
              // current haptic + press animation as the deterministic fallback.
              turns: _navPressTurns[item.index] ?? 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ultraCompact
                      ? 8
                      : compact
                      ? 10
                      : 12,
                  vertical: ultraCompact
                      ? 4
                      : compact
                      ? 5
                      : 6,
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: _navItemColor(
                      isSelected: isSelected,
                      isDark: isDark,
                      ui: ui,
                      surfaces: surfaces,
                    ),
                    end: _navItemColor(
                      isSelected: isSelected,
                      isDark: isDark,
                      ui: ui,
                      surfaces: surfaces,
                    ),
                  ),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, color, child) {
                    return item.assetPath == null
                        ? Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: _navIconSize(
                              compact: compact,
                              ultraCompact: ultraCompact,
                            ),
                            color: color,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(1),
                            child: SvgPicture.asset(
                              item.assetPath!,
                              width: _navIconSize(
                                compact: compact,
                                ultraCompact: ultraCompact,
                              ),
                              height: _navIconSize(
                                compact: compact,
                                ultraCompact: ultraCompact,
                              ),
                              colorFilter: ColorFilter.mode(
                                color ?? Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          );
                  },
                ),
              ),
            ),
            SizedBox(height: ultraCompact ? 1 : 2),
            AnimatedRotation(
              turns: (_navPressTurns[item.index] ?? 0) * 0.35,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: (_navPressTurns[item.index] ?? 0) == 0 ? 1 : 0.92,
                child: AnimatedDefaultTextStyle(
                  style: TextStyle(
                    fontSize: ultraCompact
                        ? 8
                        : compact
                        ? 8.5
                        : 9.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? ui.accent : lightSelectedNav)
                        : (isDark
                              ? ui.textPrimary.withValues(alpha: 0.70)
                              : surfaces.subduedText.withValues(alpha: 0.82)),
                  ),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _navItemColor({
    required bool isSelected,
    required bool isDark,
    required OrbiUiTokens ui,
    required OrbiSurfaceTokens surfaces,
  }) {
    if (isSelected) {
      return isDark ? ui.accent : const Color(0xFF0D3A4A);
    }
    return isDark
        ? ui.textPrimary.withValues(alpha: 0.78)
        : surfaces.subduedText.withValues(alpha: 0.88);
  }

  double _navIconSize({required bool compact, required bool ultraCompact}) {
    if (ultraCompact) return 18;
    if (compact) return 20;
    return 22;
  }
}

class _BottomNavFabCutoutClipper extends CustomClipper<Path> {
  const _BottomNavFabCutoutClipper({
    required this.radius,
    required this.cornerRadius,
  });

  final double radius;
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    return _buildBottomNavPath(
      size: size,
      radius: radius,
      cornerRadius: cornerRadius,
    );
  }

  @override
  bool shouldReclip(covariant _BottomNavFabCutoutClipper oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

class _BottomNavOutlinePainter extends CustomPainter {
  const _BottomNavOutlinePainter({
    required this.radius,
    required this.cornerRadius,
    required this.color,
  });

  final double radius;
  final double cornerRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final path = _buildBottomNavPath(
      size: size,
      radius: radius,
      cornerRadius: cornerRadius,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomNavOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.color != color;
  }
}

Path _buildBottomNavPath({
  required Size size,
  required double radius,
  required double cornerRadius,
}) {
  final centerX = size.width / 2;
  return Path()
    ..moveTo(0, size.height)
    ..lineTo(0, cornerRadius)
    ..quadraticBezierTo(0, 0, cornerRadius, 0)
    ..lineTo(centerX - radius, 0)
    ..arcToPoint(
      Offset(centerX + radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    )
    ..lineTo(size.width - cornerRadius, 0)
    ..quadraticBezierTo(size.width, 0, size.width, cornerRadius)
    ..lineTo(size.width, size.height)
    ..close();
}

class _NavSpec {
  const _NavSpec({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.label,
    this.assetPath,
  });

  final IconData icon;
  final IconData activeIcon;
  final int index;
  final String label;
  final String? assetPath;
}
