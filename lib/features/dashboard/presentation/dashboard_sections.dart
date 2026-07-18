part of 'dashboard_screen.dart';

String _formatAmount(BuildContext context, double value) {
  final settings = context.read<AppSettingsController>();
  if (settings.hideBalances) {
    return AppSettingsController.hiddenBalanceText;
  }
  final controller = context.read<DashboardController>();
  return formatDisplayMoney(
    value,
    controller.currencyCode,
    hideBalances: settings.hideBalances,
  );
}

String _formatSignedPercent(double value) {
  if (value.abs() < 0.05) return '0%';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(0)}%';
}

String _formatCompactChartValue(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000000000) {
    return '${(value / 1000000000000).toStringAsFixed(1)}T';
  }
  if (absolute >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(0);
}

class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent({
    required this.snapshot,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onOpenMore,
  });

  final DashboardHomeSnapshot snapshot;
  final bool isLoading;
  final String? error;
  final Future<void> Function({bool showErrorStatus}) onRetry;
  final Future<void> Function() onOpenMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !snapshot.hasData) {
      return const _DashboardSkeleton();
    }

    if (error != null && !snapshot.hasData) {
      return _DashboardErrorState(
        message: error!,
        onRetry: () => onRetry(showErrorStatus: true),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final canSplitSecondary = width >= 760;
        final secondaryWidth = canSplitSecondary ? (width - 12) / 2 : width;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrbiMotionReveal(
              delay: const Duration(milliseconds: 40),
              duration: const Duration(milliseconds: 640),
              beginOffset: const Offset(0, 0.035),
              child: _HeroLayer(snapshot: snapshot, onOpenMore: onOpenMore),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OrbiMotionReveal(
                  delay: const Duration(milliseconds: 190),
                  duration: const Duration(milliseconds: 680),
                  beginOffset: const Offset(0, 0.045),
                  child: SizedBox(
                    width: width,
                    child: _SmartCarouselLayer(cards: snapshot.carouselCards),
                  ),
                ),
                OrbiMotionReveal(
                  delay: const Duration(milliseconds: 260),
                  duration: const Duration(milliseconds: 680),
                  beginOffset: const Offset(-0.035, 0.05),
                  child: SizedBox(
                    width: secondaryWidth,
                    child: _GuardianAiLayer(items: snapshot.aiFeed),
                  ),
                ),
                OrbiMotionReveal(
                  delay: const Duration(milliseconds: 320),
                  duration: const Duration(milliseconds: 680),
                  beginOffset: const Offset(0.035, 0.05),
                  child: SizedBox(
                    width: secondaryWidth,
                    child: _FinancialJourneyLayer(snapshot: snapshot.journey),
                  ),
                ),
                OrbiMotionReveal(
                  delay: const Duration(milliseconds: 390),
                  duration: const Duration(milliseconds: 680),
                  beginOffset: const Offset(0, 0.05),
                  child: SizedBox(
                    width: width,
                    child: _RecentActivityLayer(items: snapshot.recentActivity),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeroLayer extends StatelessWidget {
  const _HeroLayer({required this.snapshot, required this.onOpenMore});

  final DashboardHomeSnapshot snapshot;
  final Future<void> Function() onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NetWorthHeroCard(netWorth: snapshot.netWorth),
        const SizedBox(height: 10),
        _ActionDockLayer(onOpenMore: onOpenMore, compact: true),
        const SizedBox(height: 10),
        _FinancialHealthCard(
          health: snapshot.financialHealth,
          security: snapshot.deviceSecurity,
          recentActivity: snapshot.recentActivity,
        ),
      ],
    );
  }
}

class _FinancialHealthCard extends StatelessWidget {
  const _FinancialHealthCard({
    required this.health,
    required this.security,
    required this.recentActivity,
  });

  final FinancialHealthSnapshot health;
  final DeviceSecuritySnapshot security;
  final List<RecentActivityItem> recentActivity;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreValue = health.score.clamp(0, 100);
    final needsAttention = (100 - scoreValue).clamp(0, 100);
    final healthStatusLabel = sw
        ? switch (health.status) {
            FinancialHealthStatus.excellent => 'Bora sana',
            FinancialHealthStatus.good => 'Nzuri',
            FinancialHealthStatus.needsAttention => 'Inahitaji uangalizi',
          }
        : health.statusLabel;
    final securityLabel = sw
        ? (security.isSecure ? 'Imelindwa' : 'Angalia usalama')
        : security.label;
    final onTrackColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF67E8F9);
    final needsAttentionColor = isDark
        ? const Color(0xFFF59E0B)
        : const Color(0xFFFFB36B);
    final segments = [
      OrbiWealthRingSegment(
        value: scoreValue.toDouble(),
        color: onTrackColor,
        label: sw ? 'Imara' : 'On track',
      ),
      OrbiWealthRingSegment(
        value: needsAttention.toDouble(),
        color: needsAttentionColor,
        label: sw ? 'Angalia' : 'Needs attention',
      ),
    ];
    final compact = screenWidth < 400;
    final dense = screenWidth < 370;
    return OrbiActivityCard(
      accent: ui.accent,
      hero: true,
      variant: OrbiGradientCardVariant.neon,
      padding: EdgeInsets.fromLTRB(dense ? 13 : 15, 13, dense ? 13 : 15, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sw ? 'Afya ya fedha' : 'Financial Health',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sw
                          ? 'Muonekano wa bajeti, akiba, malengo na usalama.'
                          : 'A quick view of budget, savings, goals, and security.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.68 : 0.88,
                        ),
                        fontSize: dense ? 10.2 : 10.8,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SecurityPulseBadge(
                    secure: security.isSecure,
                    label: securityLabel,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FinancialHealthOrbit(
            score: health.score,
            statusLabel: healthStatusLabel,
            segments: segments,
            scoreValue: scoreValue,
            needsAttention: needsAttention,
            onTrackColor: onTrackColor,
            needsAttentionColor: needsAttentionColor,
            compact: compact,
            dense: dense,
            sw: sw,
          ),
          SizedBox(height: dense ? 4 : 6),
          _FinancialHealthTrend(
            items: recentActivity,
            compact: compact,
            score: health.score,
          ),
        ],
      ),
    );
  }
}

class _NetWorthHeroCard extends StatelessWidget {
  const _NetWorthHeroCard({required this.netWorth});

  final NetWorthSnapshot netWorth;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dashboard = context.watch<DashboardController>();
    final settings = context.watch<AppSettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = screenWidth < 400;
    final extraCompact = screenWidth < 370;
    final internalBalanceTotal = math.max(
      0.0,
      dashboard.totalInternalVaultBalance,
    );
    final unallocatedValue = math.min(
      math.max(0.0, dashboard.unallocatedAmount),
      internalBalanceTotal,
    );
    final allocatedValue = math.max(
      0.0,
      internalBalanceTotal - unallocatedValue,
    );
    final allocatedColor = isDark
        ? const Color(0xFF4AC5F2)
        : const Color(0xFF073B4C);
    final unallocatedColor = isDark
        ? const Color(0xFF9ED8EA)
        : const Color(0xFFBFE8F2);
    final visibleSliceValues = _resolveVisibleRingSplit(
      allocated: allocatedValue,
      unallocated: unallocatedValue,
    );
    final segments = <OrbiWealthRingSegment>[
      OrbiWealthRingSegment(
        value: visibleSliceValues.$1,
        color: allocatedColor,
        label: sw ? 'Imepangwa' : 'Allocated',
      ),
      OrbiWealthRingSegment(
        value: visibleSliceValues.$2,
        color: unallocatedColor,
        label: sw ? 'Haijapangwa' : 'Unallocated',
      ),
    ].where((segment) => segment.value > 0.009).toList();
    final ringSize = extraCompact
        ? 154.0
        : compact
        ? 166.0
        : 178.0;
    final ringHostHeight = extraCompact
        ? 170.0
        : compact
        ? 184.0
        : 194.0;
    final ringSurfaceColor = isDark
        ? (Color.lerp(ui.cardStrong, ui.card, 0.32) ?? ui.card)
        : Colors.white.withValues(alpha: 0.78);
    return OrbiActivityCard(
      accent: ui.accent,
      hero: true,
      variant: OrbiGradientCardVariant.oceanic,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sw ? 'Salio la Akaunti' : 'Account Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                      : null,
                ),
                child: IconButton(
                  tooltip: settings.hideBalances
                      ? 'Show balances'
                      : 'Hide balances',
                  onPressed: () => context
                      .read<AppSettingsController>()
                      .toggleHideBalances(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      settings.hideBalances
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      key: ValueKey(settings.hideBalances),
                      size: 18,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.88)
                          : const Color(0xFF07566B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          OrbiMotionReveal(
            delay: const Duration(milliseconds: 110),
            duration: const Duration(milliseconds: 620),
            beginOffset: const Offset(0, 0.04),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: ringHostHeight,
                    width: ringHostHeight - (extraCompact ? 8 : 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isDark)
                          Positioned.fill(
                            child: _AnimatedOrbitField(
                              colors: [
                                allocatedColor,
                                unallocatedColor,
                                ui.accent,
                                Color.lerp(
                                      allocatedColor,
                                      Colors.white,
                                      0.16,
                                    ) ??
                                    allocatedColor,
                              ],
                              density: extraCompact
                                  ? 0.72
                                  : (compact ? 0.9 : 1.0),
                            ),
                          ),
                        OrbiWealthRing(
                          size: ringSize,
                          duration: const Duration(milliseconds: 1050),
                          separatorColor: ringSurfaceColor,
                          segments: segments.isEmpty
                              ? [
                                  OrbiWealthRingSegment(
                                    value: internalBalanceTotal <= 0
                                        ? 1.0
                                        : internalBalanceTotal,
                                    color: ui.accent,
                                    label: sw
                                        ? 'Salio la ndani'
                                        : 'Internal balance',
                                  ),
                                ]
                              : segments,
                          center: SizedBox(
                            width: ringSize * 0.62,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  sw ? 'Jumla ya salio' : 'Total balance',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: isDark ? 0.68 : 0.92,
                                    ),
                                    fontSize: extraCompact ? 9.2 : 9.8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                _HomeBalanceDisplay(
                                  amount: internalBalanceTotal,
                                  mainFontSize: extraCompact ? 24.0 : 28.0,
                                  sideFontSize: extraCompact ? 9.8 : 10.8,
                                  mainColor: Colors.white,
                                  sideColor: Colors.white.withValues(
                                    alpha: 0.74,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: extraCompact ? 10 : 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: extraCompact ? 14 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroLegendItem(
                          color: allocatedColor,
                          label: sw ? 'Imepangwa' : 'Allocated',
                          amount: allocatedValue,
                        ),
                        const SizedBox(height: 8),
                        _HeroLegendItem(
                          color: unallocatedColor,
                          label: sw ? 'Haijapangwa' : 'Unallocated',
                          amount: unallocatedValue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OrbiMotionReveal(
            delay: const Duration(milliseconds: 180),
            duration: const Duration(milliseconds: 680),
            beginOffset: const Offset(0, 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDark ? 0.16 : 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                _HeroIncomeTrendSection(
                  transactions: dashboard.transactions,
                  sw: sw,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDockLayer extends StatelessWidget {
  const _ActionDockLayer({required this.onOpenMore, this.compact = false});

  final Future<void> Function() onOpenMore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final items = <_QuickActionItem>[
      _QuickActionItem(
        label: 'Send',
        icon: Icons.north_east_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SendMoneyScreen())),
      ),
      _QuickActionItem(
        label: 'Pay',
        icon: Icons.qr_code_scanner_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PaymentScreen())),
      ),
      _QuickActionItem(
        label: 'Request',
        icon: Icons.call_received_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RequestMoneyScreen())),
      ),
      _QuickActionItem(
        label: 'Save',
        icon: Icons.savings_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
      ),
      _QuickActionItem(
        label: 'More',
        icon: Icons.apps_rounded,
        onTap: onOpenMore,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          const _SectionHeading(
            title: 'Action Dock',
            subtitle: 'Your fastest money actions.',
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 10 : 12,
            compact ? 10 : 12,
            compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? ui.card : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isDark
                ? Border.all(color: ui.border.withValues(alpha: 0.72))
                : null,
            boxShadow: null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sw ? 'Vitendo vya haraka' : 'Quick Actions',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: compact ? 12.8 : 13.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sw
                              ? 'Njia zako za haraka za fedha.'
                              : 'Your fastest money actions.',
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: compact ? 10.2 : 10.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: ui.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt_rounded, size: 14, color: ui.accent),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              SizedBox(
                height: compact ? 88 : 96,
                child: Stack(
                  children: [
                    ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(width: compact ? 10 : 12),
                      itemBuilder: (context, index) => _QuickActionTile(
                        item: items[index],
                        compact: compact,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: compact ? 14 : 18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                ui.card.withValues(alpha: 0.84),
                                ui.card.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: compact ? 34 : 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                ui.card.withValues(alpha: 0),
                                ui.card.withValues(alpha: 0.94),
                                ui.card,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmartCarouselLayer extends StatefulWidget {
  const _SmartCarouselLayer({required this.cards});

  final List<SmartCarouselCardData> cards;

  @override
  State<_SmartCarouselLayer> createState() => _SmartCarouselLayerState();
}

class _SmartCarouselLayerState extends State<_SmartCarouselLayer> {
  final PageController _controller = PageController(viewportFraction: 0.96);
  Timer? _autoSlideTimer;
  int _page = 0;
  bool _pauseAutoSlide = false;

  @override
  void initState() {
    super.initState();
    _restartAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _SmartCarouselLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length) {
      _restartAutoSlide();
    }
  }

  void _restartAutoSlide() {
    _autoSlideTimer?.cancel();
    if (widget.cards.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _pauseAutoSlide || !_controller.hasClients) return;
      final count = widget.cards.length;
      if (count <= 1) return;
      final nextPage = (_page + 1) % count;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 540),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final cards = widget.cards.isEmpty
        ? [
            SmartCarouselCardData(
              type: SmartCarouselCardType.goalProgress,
              title: sw ? 'Huduma na Kazi' : 'Services & Tasks',
              headline: sw
                  ? 'Hakuna pendekezo jipya'
                  : 'No live recommendation yet',
              supportingText: sw
                  ? 'Vuta chini ili kuangalia taarifa mpya.'
                  : 'Pull to refresh when new data arrives.',
              amountLabel: '',
              statusLabel: sw ? 'Inasubiri' : 'Waiting',
              progress: 0.0,
              icon: Icons.swipe_rounded,
            ),
          ]
        : widget.cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: sw ? 'Huduma na Kazi' : 'Services & Tasks',
          subtitle: sw
              ? 'Fuatilia huduma, maombi na kazi muhimu hapa.'
              : 'Track services, requests, and important tasks here.',
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final cardHeight =
                184.0 + ((textScale - 1.0) * 44.0).clamp(0.0, 34.0);
            return Listener(
          onPointerDown: (_) => setState(() => _pauseAutoSlide = true),
          onPointerUp: (_) => setState(() => _pauseAutoSlide = false),
          onPointerCancel: (_) => setState(() => _pauseAutoSlide = false),
          child: SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index == cards.length - 1 ? 0 : 10,
                ),
                child: _SmartCard(card: cards[index], sw: sw),
              ),
            ),
          ),
        );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(cards.length, (index) {
            final active = index == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              width: active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? OrbiTheme.uiOf(context).accent
                    : OrbiTheme.uiOf(context).border,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GuardianAiLayer extends StatelessWidget {
  const _GuardianAiLayer({required this.items});

  final List<GuardianInsightData> items;

  @override
  Widget build(BuildContext context) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final seen = <String>{};
    final uniqueItems = items
        .where((item) {
          final key =
              '${item.type.name}:${item.message.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
          return seen.add(key);
        })
        .take(3)
        .toList(growable: false);
    final resolved = uniqueItems.isEmpty
        ? [
            GuardianInsightData(
              type: GuardianInsightType.savingSuggestion,
              title: 'Guardian AI',
              message: sw
                  ? 'Mapendekezo yataonekana hapa baada ya ORBI kupata mwenendo wa matumizi yako.'
                  : 'Insights will appear after ORBI learns your money patterns.',
              severityLabel: sw ? 'Inasubiri' : 'Standby',
            ),
          ]
        : uniqueItems;
    final featured = resolved.first;
    final secondary = resolved.skip(1).toList(growable: false);
    return _GuardianIntelligencePanel(
      featured: featured,
      secondary: secondary,
      sw: sw,
    );
  }
}

class _FinancialJourneyLayer extends StatefulWidget {
  const _FinancialJourneyLayer({required this.snapshot});

  final FinancialJourneySnapshot snapshot;

  @override
  State<_FinancialJourneyLayer> createState() => _FinancialJourneyLayerState();
}

class _FinancialJourneyLayerState extends State<_FinancialJourneyLayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final snapshot = widget.snapshot;
    return Container(
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Journey',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.activeGoals} Active Goals  •  ${snapshot.sharedPots} Fungu  •  ${snapshot.activeBudgets} Mezani',
                          style: TextStyle(color: ui.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ui.iconMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  _JourneyBlock(title: 'Goals', items: snapshot.goalItems),
                  const SizedBox(height: 12),
                  _JourneyBlock(title: 'Mezani', items: snapshot.budgetItems),
                  const SizedBox(height: 12),
                  _JourneyBlock(title: 'Fungu', items: snapshot.potItems),
                  const SizedBox(height: 12),
                  _JourneyBlock(
                    title: 'Upcoming Commitments',
                    items: snapshot.commitmentItems,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityLayer extends StatelessWidget {
  const _RecentActivityLayer({required this.items});

  final List<RecentActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final resolved = items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Recent Activity',
          subtitle: 'Your newest money movement.',
        ),
        const SizedBox(height: 12),
        if (resolved.isEmpty)
          const _EmptyStateCard(
            title: 'No activity yet',
            message:
                'Your latest transfers, payments, and incoming funds will appear here.',
          )
        else
          ...resolved.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecentActivityCard(item: item),
            ),
          ),
      ],
    );
  }
}

typedef _SmartCardDisplay = ({
  String title,
  String headline,
  String supporting,
  String amount,
  String status,
});

_SmartCardDisplay _localizedSmartCard(
  BuildContext context,
  SmartCarouselCardData card,
  bool sw,
) {
  final amountValue = double.tryParse(
    card.amountLabel.replaceAll(',', '').trim(),
  );
  final amount = amountValue == null || amountValue.abs() < 0.009
      ? ''
      : _formatAmount(context, amountValue);

  String title;
  String status;
  String supporting = card.supportingText.trim();

  switch (card.type) {
    case SmartCarouselCardType.goalProgress:
      title = sw ? 'Maendeleo ya lengo' : 'Goal progress';
      status = sw ? 'Inaendelea' : 'On track';
      supporting = _localizeProgressText(supporting, sw);
    case SmartCarouselCardType.budgetStatus:
      title = sw ? 'Hali ya bajeti' : 'Budget status';
      status = card.progress >= 0.9
          ? (sw ? 'Tahadhari' : 'At risk')
          : (sw ? 'Nzuri' : 'Healthy');
      supporting = _localizeProgressText(supporting, sw);
    case SmartCarouselCardType.upcomingBill:
      title = sw ? 'Bili inayokuja' : 'Upcoming bill';
      status = sw ? 'Angalia' : 'Watch';
      supporting = _friendlyDashboardDate(supporting, sw);
    case SmartCarouselCardType.sharedPot:
      title = 'Fungu';
      status = sw ? 'Pamoja' : 'Shared';
      supporting = _localizeProgressText(supporting, sw);
    case SmartCarouselCardType.offlineTransaction:
      title = sw ? 'Hali ya muamala' : 'Transaction status';
      status = _localizedTransactionStatus(card.statusLabel, sw);
      supporting = _localizedTransactionStatus(supporting, sw);
    case SmartCarouselCardType.merchantRecommendation:
      title = sw ? 'Pendekezo la mfanyabiashara' : 'Merchant recommendation';
      status = sw ? 'Gundua' : 'Discover';
      if (supporting == 'No personalized recommendation is ready yet.') {
        supporting = sw
            ? 'Pendekezo litaonekana baada ya mwenendo wako kupatikana.'
            : 'A recommendation will appear after your activity is available.';
      }
  }

  return (
    title: title,
    headline: card.headline,
    supporting: supporting,
    amount: amount,
    status: status,
  );
}

String _friendlyDashboardDate(String raw, bool sw) {
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  const enMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const swMonths = [
    'Jan',
    'Feb',
    'Mac',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final month = (sw ? swMonths : enMonths)[parsed.month - 1];
  return sw
      ? 'Inalipwa ${parsed.day} $month ${parsed.year}'
      : 'Due ${parsed.day} $month ${parsed.year}';
}

String _localizeProgressText(String raw, bool sw) {
  if (!sw) return raw;
  final funded = RegExp(
    r'^(\d+)% funded$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (funded != null) return '${funded.group(1)}% imefadhiliwa';
  final used = RegExp(r'^(\d+)% used$', caseSensitive: false).firstMatch(raw);
  if (used != null) return '${used.group(1)}% imetumika';
  if (raw.toLowerCase() == 'active balance') return 'Salio linalotumika';
  return raw;
}

String _localizedTransactionStatus(String raw, bool sw) {
  if (!sw) return raw;
  final normalized = raw.trim().toLowerCase();
  if (normalized.contains('pending')) return 'Inasubiri';
  if (normalized.contains('failed')) return 'Imeshindikana';
  if (normalized.contains('complete') || normalized.contains('success')) {
    return 'Imekamilika';
  }
  return raw;
}

String _localizedInsightSeverity(GuardianInsightType type, bool sw) {
  return switch (type) {
    GuardianInsightType.spendingAlert =>
      sw ? 'Tahadhari ya matumizi' : 'Spending alert',
    GuardianInsightType.savingSuggestion =>
      sw ? 'Ushauri wa akiba' : 'Saving suggestion',
    GuardianInsightType.goalPrediction =>
      sw ? 'Mwelekeo wa lengo' : 'Goal outlook',
    GuardianInsightType.budgetWarning =>
      sw ? 'Tahadhari ya bajeti' : 'Budget warning',
    GuardianInsightType.securityWarning =>
      sw ? 'Tahadhari ya usalama' : 'Security warning',
  };
}

String _localizedInsightMessage(String raw, bool sw) {
  if (!sw) return raw;
  final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const translations = <String, String>{
    'no immediate spending pressure detected from your latest activity.':
        'Hakuna shinikizo la matumizi lililoonekana kwenye miamala yako ya hivi karibuni.',
    'keep one budget category deliberately underused and route the difference into savings.':
        'Punguza matumizi kwenye kundi moja la bajeti na uhamishie tofauti hiyo kwenye akiba.',
    'spending is running ahead of your active budgets. tighten one category this week.':
        'Matumizi yanazidi bajeti zako. Punguza kundi moja la matumizi wiki hii.',
    'your strongest goal is gaining momentum. keep the same weekly saving pace.':
        'Lengo lako linaendelea vizuri. Endelea na kiwango hiki cha akiba kila wiki.',
    'you can redirect part of available cash into savings without slowing everyday spending.':
        'Unaweza kuhamisha sehemu ya fedha zinazopatikana kwenda akiba bila kuathiri matumizi ya kila siku.',
  };
  return translations[normalized] ?? raw;
}

class _SmartCard extends StatelessWidget {
  const _SmartCard({required this.card, required this.sw});

  final SmartCarouselCardData card;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final percent = (card.progress.clamp(0.0, 1.0) * 100).round();
    final display = _localizedSmartCard(context, card, sw);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(ui.cardStrong, ui.accent, 0.12) ?? ui.cardStrong,
            ui.cardStrong,
            ui.card,
          ],
          stops: const [0, 0.42, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: ui.accent.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -10,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ui.accent.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 16,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.22,
                child: SizedBox(
                  width: 84,
                  height: 32,
                  child: CustomPaint(
                    painter: _SmartCardTrendPainter(color: ui.accent),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ui.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ui.accent.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(card.icon, color: ui.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display.title,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          display.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 14.6,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Tag(text: display.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                display.supporting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 14.4,
                  fontWeight: FontWeight.w800,
                  height: 1.14,
                ),
              ),
              if (display.amount.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  display.amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: card.progress.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, progress, _) {
                          return LinearProgressIndicator(
                            minHeight: 9,
                            value: progress,
                            backgroundColor: ui.cardMuted,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ui.accent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ui.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        color: ui.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmartCardTrendPainter extends CustomPainter {
  const _SmartCardTrendPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.36,
        size.width * 0.34,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.70,
        size.width * 0.70,
        size.height * 0.28,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.10,
        size.width,
        size.height * 0.18,
      );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.70),
            color.withValues(alpha: 0.20),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _SmartCardTrendPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _GuardianIntelligencePanel extends StatelessWidget {
  const _GuardianIntelligencePanel({
    required this.featured,
    required this.secondary,
    required this.sw,
  });

  final GuardianInsightData featured;
  final List<GuardianInsightData> secondary;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF132733), Color(0xFF10212B), Color(0xFF0C1820)]
              : const [Color(0xFFFFFFFF), Color(0xFFF2FAFC), Color(0xFFE8F5F8)],
          stops: const [0.0, 0.54, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        border: isDark
            ? Border.all(color: ui.accent.withValues(alpha: 0.16))
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GuardianFieldPainter(
                    color: isDark
                        ? const Color(0xFF4AC5F2)
                        : const Color(0xFF1596B3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [Color(0xFF4AC5F2), Color(0xFF2596BE)]
                                : const [Color(0xFF32B7D0), Color(0xFF087F9F)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guardian Intelligence',
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sw
                                  ? 'Uchambuzi wa fedha unaoendelea'
                                  : 'Continuous financial analysis',
                              style: TextStyle(
                                color: ui.textMuted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ui.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(color: ui.accent),
                            const SizedBox(width: 6),
                            Text(
                              sw ? 'Hai' : 'Live',
                              style: TextStyle(
                                color: ui.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _GuardianFeaturedInsight(item: featured, sw: sw),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (var index = 0; index < secondary.length; index++) ...[
                      _GuardianSignalRow(item: secondary[index], sw: sw),
                      if (index < secondary.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Divider(
                            height: 1,
                            color: ui.border.withValues(alpha: 0.62),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: ui.textSoft, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sw
                              ? 'Ushauri unatokana na mwenendo wa akaunti yako.'
                              : 'Guidance is based on your account activity.',
                          style: TextStyle(
                            color: ui.textSoft,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianFeaturedInsight extends StatelessWidget {
  const _GuardianFeaturedInsight({required this.item, required this.sw});

  final GuardianInsightData item;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = _localizedInsightMessage(item.message, sw);
    final severity = _localizedInsightSeverity(item.type, sw);
    final tone = _guardianInsightTone(item.type, isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: isDark ? 0.20 : 0.14),
            tone.withValues(alpha: isDark ? 0.07 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForInsight(item.type), color: tone, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sw ? 'Kipaumbele sasa' : 'Priority insight',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _GuardianToneTag(text: severity, color: tone),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 13.2,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianSignalRow extends StatelessWidget {
  const _GuardianSignalRow({required this.item, required this.sw});

  final GuardianInsightData item;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = _guardianInsightTone(item.type, isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_iconForInsight(item.type), color: tone, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedInsightSeverity(item.type, sw),
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _localizedInsightMessage(item.message, sw),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 11.5,
                    height: 1.28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianToneTag extends StatelessWidget {
  const _GuardianToneTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _guardianInsightTone(GuardianInsightType type, bool isDark) {
  return switch (type) {
    GuardianInsightType.spendingAlert || GuardianInsightType.budgetWarning =>
      isDark ? const Color(0xFFFFB36B) : const Color(0xFFD65A31),
    GuardianInsightType.savingSuggestion =>
      isDark ? const Color(0xFF4AC5F2) : const Color(0xFF087F9F),
    GuardianInsightType.goalPrediction =>
      isDark ? const Color(0xFF9B8AFB) : const Color(0xFF5B4BC4),
    GuardianInsightType.securityWarning =>
      isDark ? const Color(0xFFFF7A72) : const Color(0xFFC83E3E),
  };
}

class _GuardianFieldPainter extends CustomPainter {
  const _GuardianFieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final node = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.52, -6)
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.05,
        size.width * 1.04,
        size.height * 0.24,
      )
      ..moveTo(size.width * 0.64, size.height * 0.62)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.48,
        size.width * 0.91,
        size.height * 0.74,
        size.width * 1.06,
        size.height * 0.58,
      );
    canvas.drawPath(path, line);
    for (final point in <Offset>[
      Offset(size.width * 0.68, size.height * 0.11),
      Offset(size.width * 0.86, size.height * 0.16),
      Offset(size.width * 0.77, size.height * 0.59),
      Offset(size.width * 0.94, size.height * 0.64),
    ]) {
      canvas.drawCircle(point, 2.2, node);
    }
  }

  @override
  bool shouldRepaint(covariant _GuardianFieldPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _JourneyBlock extends StatelessWidget {
  const _JourneyBlock({required this.title, required this.items});

  final String title;
  final List<JourneyItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'No live items yet.',
              style: TextStyle(color: ui.textMuted, fontSize: 12),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.detail,
                          style: TextStyle(color: ui.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: item.progress.clamp(0.0, 1.0),
                        backgroundColor: ui.border,
                        valueColor: AlwaysStoppedAnimation<Color>(ui.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.item});

  final RecentActivityItem item;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final amountColor = item.isCredit ? ui.success : ui.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ui.cardMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: ui.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.provider} • ${item.channel}',
                  style: TextStyle(color: ui.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.isCredit ? '+' : '-'}${_formatAmount(context, item.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.status} • ${_timeAgo(item.time)}',
                style: TextStyle(color: ui.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonBlock(height: 190),
        SizedBox(height: 16),
        _SkeletonBlock(height: 104),
        SizedBox(height: 16),
        _SkeletonBlock(height: 188),
        SizedBox(height: 16),
        _SkeletonBlock(height: 124),
        SizedBox(height: 16),
        _SkeletonBlock(height: 120),
        SizedBox(height: 16),
        _SkeletonBlock(height: 136),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyStateCard(
      title: 'Unable to load Home',
      message: message,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: ui.textMuted, fontSize: 13, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle.isEmpty ? 22 : 30,
          margin: const EdgeInsets.only(top: 2, right: 10),
          decoration: BoxDecoration(
            color: ui.accent.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: ui.accent.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ui.textMuted, fontSize: 11.6),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final FutureOr<void> Function() onTap;
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.item, this.compact = false});

  final _QuickActionItem item;
  final bool compact;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final compact = widget.compact;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            HapticFeedback.lightImpact();
            await item.onTap();
          },
          child: Ink(
            width: compact ? 82 : 92,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(ui.cardStrong, ui.accent, 0.06) ??
                            ui.cardStrong,
                        ui.card,
                      ]
                    : [
                        Colors.white,
                        Color.lerp(ui.cardMuted, ui.accent, 0.03) ??
                            ui.cardMuted,
                      ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: isDark
                  ? Border.all(color: ui.border.withValues(alpha: 0.70))
                  : null,
              boxShadow: null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              ui.accent.withValues(
                                alpha: _pressed ? 0.18 : 0.12,
                              ),
                              ui.accent.withValues(
                                alpha: _pressed ? 0.08 : 0.04,
                              ),
                            ]
                          : [
                              ui.accent.withValues(
                                alpha: _pressed ? 0.20 : 0.14,
                              ),
                              ui.accent.withValues(
                                alpha: _pressed ? 0.10 : 0.06,
                              ),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: ui.accent,
                    size: compact ? 18 : 20,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: compact ? 10.8 : 11.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityPulseBadge extends StatelessWidget {
  const _SecurityPulseBadge({required this.secure, required this.label});

  final bool secure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? (secure ? const Color(0xFF34D399) : const Color(0xFFFBBF24))
        : (secure ? const Color(0xFF67E8F9) : const Color(0xFFFFB36B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.82 + (_controller.value * 0.18);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

class _FinancialHealthOrbit extends StatelessWidget {
  const _FinancialHealthOrbit({
    required this.score,
    required this.statusLabel,
    required this.segments,
    required this.scoreValue,
    required this.needsAttention,
    required this.onTrackColor,
    required this.needsAttentionColor,
    required this.compact,
    required this.dense,
    required this.sw,
  });

  final int score;
  final String statusLabel;
  final List<OrbiWealthRingSegment> segments;
  final int scoreValue;
  final int needsAttention;
  final Color onTrackColor;
  final Color needsAttentionColor;
  final bool compact;
  final bool dense;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        dense ? 8 : 10,
        dense ? 8 : 10,
        dense ? 8 : 10,
        dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.05))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniHealthScoreRing(
                score: score,
                color: onTrackColor,
                trackColor: needsAttentionColor.withValues(alpha: 0.24),
                compact: compact,
                dense: dense,
              ),
              SizedBox(width: dense ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: dense ? 12.4 : 13.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: dense ? 5 : 6),
                    _HealthLegendLine(
                      color: onTrackColor,
                      label: sw ? 'Imara' : 'On track',
                      value: scoreValue,
                      dense: dense,
                    ),
                    SizedBox(height: dense ? 6 : 7),
                    _HealthLegendLine(
                      color: needsAttentionColor,
                      label: sw ? 'Boresha' : 'Improve',
                      value: needsAttention,
                      dense: dense,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 8 : 10),
          Text(
            sw
                ? 'Kadri sehemu ya imara inavyoongezeka, ndivyo afya ya fedha inavyokuwa bora.'
                : 'A larger on-track share means a healthier money position.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isDark ? 0.72 : 0.80),
              fontSize: dense ? 10.0 : 10.8,
              fontWeight: FontWeight.w600,
              height: 1.22,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHealthScoreRing extends StatelessWidget {
  const _MiniHealthScoreRing({
    required this.score,
    required this.color,
    required this.trackColor,
    required this.compact,
    required this.dense,
  });

  final int score;
  final Color color;
  final Color trackColor;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ringSize = dense
        ? 58.0
        : compact
        ? 62.0
        : 68.0;
    final clamped = score.clamp(0, 100).toDouble();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: OrbiWealthRing(
        size: ringSize,
        duration: const Duration(milliseconds: 900),
        trackColor: trackColor,
        separatorColor: Theme.of(context).scaffoldBackgroundColor,
        segmentGapAngle: 0,
        segments: [
          OrbiWealthRingSegment(value: clamped, color: color, label: 'score'),
          OrbiWealthRingSegment(
            value: 100 - clamped,
            color: Colors.transparent,
            label: 'rest',
          ),
        ],
        center: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: clamped),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 820),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) {
            return Text(
              '${animatedValue.round()}',
              style: TextStyle(
                color: Colors.white,
                fontSize: dense ? 13 : 14.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HealthLegendLine extends StatelessWidget {
  const _HealthLegendLine({
    required this.color,
    required this.label,
    required this.value,
    required this.dense,
  });

  final Color color;
  final String label;
  final int value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: dense ? 10 : 12,
          height: dense ? 10 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(width: dense ? 8 : 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: dense ? 10.2 : 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 820),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) {
            return Text(
              '${animatedValue.round()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: dense ? 11.6 : 12.4,
                fontWeight: FontWeight.w900,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedOrbitField extends StatefulWidget {
  const _AnimatedOrbitField({required this.colors, this.density = 1});

  final List<Color> colors;
  final double density;

  @override
  State<_AnimatedOrbitField> createState() => _AnimatedOrbitFieldState();
}

class _AnimatedOrbitFieldState extends State<_AnimatedOrbitField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final rotation = reduceMotion
              ? 0.0
              : ((_controller.value - 0.5) * 0.08);
          final opacity = reduceMotion
              ? 1.0
              : (0.82 + ((_controller.value - 0.5).abs() * 0.18));
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rotation,
              child: CustomPaint(
                painter: _HealthOrbitFieldPainter(
                  colors: widget.colors,
                  density: widget.density,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HealthOrbitFieldPainter extends CustomPainter {
  const _HealthOrbitFieldPainter({required this.colors, this.density = 1});

  final List<Color> colors;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * density.clamp(0.7, 1.2);
    final nodes = Paint()..style = PaintingStyle.fill;

    final paths = <Path>[
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.26)
        ..quadraticBezierTo(
          size.width * 0.26,
          size.height * 0.12,
          size.width * 0.42,
          size.height * 0.18,
        )
        ..quadraticBezierTo(
          size.width * 0.62,
          size.height * 0.25,
          size.width * 0.82,
          size.height * 0.16,
        ),
      Path()
        ..moveTo(size.width * 0.14, size.height * 0.80)
        ..quadraticBezierTo(
          size.width * 0.34,
          size.height * 0.67,
          size.width * 0.54,
          size.height * 0.76,
        )
        ..quadraticBezierTo(
          size.width * 0.72,
          size.height * 0.84,
          size.width * 0.90,
          size.height * 0.66,
        ),
    ];

    for (var i = 0; i < paths.length; i++) {
      stroke.color = colors[i % colors.length].withValues(
        alpha: 0.18 * density.clamp(0.7, 1.0),
      );
      canvas.drawPath(paths[i], stroke);
    }

    final orbitNodes = <(Offset, Color)>[
      (Offset(size.width * 0.18, size.height * 0.23), colors[0]),
      (
        Offset(size.width * 0.74, size.height * 0.19),
        colors[1 % colors.length],
      ),
      (
        Offset(size.width * 0.22, size.height * 0.76),
        colors[2 % colors.length],
      ),
      (
        Offset(size.width * 0.83, size.height * 0.72),
        colors[3 % colors.length],
      ),
    ];
    for (final node in orbitNodes) {
      nodes.color = node.$2.withValues(alpha: 0.30 * density.clamp(0.7, 1.0));
      canvas.drawCircle(node.$1, 3.1 * density.clamp(0.7, 1.15), nodes);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthOrbitFieldPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.density != density;
  }
}

class _FinancialHealthTrend extends StatelessWidget {
  const _FinancialHealthTrend({
    required this.items,
    required this.compact,
    required this.score,
  });

  final List<RecentActivityItem> items;
  final bool compact;
  final int score;

  @override
  Widget build(BuildContext context) {
    return _FinancialHealthTrendBody(
      items: items,
      compact: compact,
      score: score,
    );
  }
}

class _FinancialHealthTrendBody extends StatefulWidget {
  const _FinancialHealthTrendBody({
    required this.items,
    required this.compact,
    required this.score,
  });

  final List<RecentActivityItem> items;
  final bool compact;
  final int score;

  @override
  State<_FinancialHealthTrendBody> createState() =>
      _FinancialHealthTrendBodyState();
}

class _FinancialHealthTrendBodyState extends State<_FinancialHealthTrendBody> {
  _HealthTrendFilter _filter = _HealthTrendFilter.sevenDays;

  @override
  Widget build(BuildContext context) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trend = _buildHealthTrendSeries(widget.items, _filter, sw);
    final incomeTotal = trend.income.reduce((sum, value) => sum + value);
    final expenseTotal = trend.expense.reduce((sum, value) => sum + value);
    final filterLabel = _healthTrendFilterLabel(_filter, sw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 8 : 10),
        Row(
          children: [
            Expanded(
              child: Text(
                sw ? 'Mwenendo wa fedha' : 'Money trend',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            PopupMenuButton<_HealthTrendFilter>(
              initialValue: _filter,
              onSelected: (value) => setState(() => _filter = value),
              color: isDark ? const Color(0xFF15232E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                for (final filter in _HealthTrendFilter.values)
                  PopupMenuItem(
                    value: filter,
                    child: Text(_healthTrendFilterLabel(filter, sw)),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.90),
                  borderRadius: BorderRadius.circular(999),
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterLabel,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.84)
                            : const Color(0xFF1E2F3A),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.72)
                          : const Color(0xFF5E727E),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _IncomeSpendingCompoundChart(
          income: trend.income,
          expense: trend.expense,
          labels: trend.labels,
          compact: widget.compact,
          sw: sw,
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TrendStatChip(
              color: isDark ? const Color(0xFF4AC5F2) : const Color(0xFF67E8F9),
              label: sw ? 'Mapato' : 'Income',
              value: _formatAmount(context, incomeTotal),
              amountValue: incomeTotal,
            ),
            _TrendStatChip(
              color: isDark ? const Color(0xFFF472B6) : const Color(0xFFFFB36B),
              label: sw ? 'Matumizi' : 'Spending',
              value: _formatAmount(context, expenseTotal),
              amountValue: expenseTotal,
            ),
            _TrendStatChip(
              color: isDark ? const Color(0xFF34D399) : const Color(0xFFFFFFFF),
              label: sw ? 'Alama' : 'Score',
              value: '${widget.score}%',
              numericValue: widget.score.toDouble(),
              suffix: '%',
            ),
          ],
        ),
      ],
    );
  }
}

class _IncomeSpendingCompoundChart extends StatelessWidget {
  const _IncomeSpendingCompoundChart({
    required this.income,
    required this.expense,
    required this.labels,
    required this.compact,
    required this.sw,
  });

  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  final bool compact;
  final bool sw;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = math.max(
      1,
      [
        ...income,
        ...expense,
      ].fold<double>(0, (max, value) => math.max(max, value)),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(2, compact ? 2 : 4, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(income.length, (index) {
          final incomeRatio = (income[index] / maxValue).clamp(0.0, 1.0);
          final expenseRatio = (expense[index] / maxValue).clamp(0.0, 1.0);
          return Expanded(
            child: OrbiMotionReveal(
              delay: Duration(milliseconds: 70 + (index * 55)),
              duration: const Duration(milliseconds: 520),
              beginOffset: const Offset(0, 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: compact ? 64 : 74,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _GroupedTrendBar(
                            ratio: incomeRatio,
                            height: compact ? 64 : 74,
                            width: compact ? 7 : 8,
                            colors: isDark
                                ? const [Color(0xFF7DD3FC), Color(0xFF38BDF8)]
                                : const [Color(0xFFBDF7FF), Color(0xFF4AD5EA)],
                            alignLeft: true,
                          ),
                          SizedBox(width: compact ? 3 : 4),
                          _GroupedTrendBar(
                            ratio: expenseRatio,
                            height: compact ? 64 : 74,
                            width: compact ? 7 : 8,
                            colors: isDark
                                ? const [Color(0xFFF9A8D4), Color(0xFFEC4899)]
                                : const [Color(0xFFFFD0A5), Color(0xFFFF9A55)],
                            alignLeft: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.62 : 0.76,
                      ),
                      fontSize: compact ? 9.2 : 9.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GroupedTrendBar extends StatelessWidget {
  const _GroupedTrendBar({
    required this.ratio,
    required this.height,
    required this.width,
    required this.colors,
    required this.alignLeft,
  });

  final double ratio;
  final double height;
  final double width;
  final List<Color> colors;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    final barHeight = math.max(2.0, height * safeRatio);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      width: width,
      height: barHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(alignLeft ? 8 : 3),
          bottomRight: Radius.circular(alignLeft ? 3 : 8),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
    );
  }
}

class _TrendSeries {
  const _TrendSeries({
    required this.income,
    required this.expense,
    required this.labels,
  });

  final List<double> income;
  final List<double> expense;
  final List<String> labels;
}

class _TrendStatChip extends StatelessWidget {
  const _TrendStatChip({
    required this.color,
    required this.label,
    required this.value,
    this.amountValue,
    this.numericValue,
    this.suffix,
  });

  final Color color;
  final String label;
  final String value;
  final double? amountValue;
  final double? numericValue;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(ui.cardStrong, color, 0.18) ??
                      color.withValues(alpha: 0.18),
                  Color.lerp(ui.card, color, 0.08) ??
                      color.withValues(alpha: 0.10),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
        borderRadius: BorderRadius.circular(999),
        border: isDark
            ? Border.all(color: color.withValues(alpha: 0.20))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 10.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: amountValue != null
                      ? _AnimatedTrendAmountText(amount: amountValue!)
                      : numericValue == null
                      ? Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: numericValue!),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 860),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, _) {
                            return Text(
                              '${animatedValue.round()}${suffix ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w900,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTrendAmountText extends StatelessWidget {
  const _AnimatedTrendAmountText({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsController>();
    if (settings.hideBalances) {
      return const Text(
        AppSettingsController.hiddenBalanceText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.8,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    final controller = context.read<DashboardController>();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 920),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          formatDisplayMoney(
            animatedValue,
            controller.currencyCode,
            hideBalances: settings.hideBalances,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
          ),
        );
      },
    );
  }
}

class _WealthTimelinePoint {
  const _WealthTimelinePoint({
    required this.date,
    required this.value,
    required this.netFlow,
  });

  final DateTime date;
  final double value;
  final double netFlow;
}

class _WealthTimelineSeries {
  const _WealthTimelineSeries({
    required this.points,
    required this.hasRealMovement,
  });

  final List<_WealthTimelinePoint> points;
  final bool hasRealMovement;
}

enum _HealthTrendFilter { sevenDays, thisMonth, thisYear }

String _healthTrendFilterLabel(_HealthTrendFilter filter, bool sw) {
  switch (filter) {
    case _HealthTrendFilter.sevenDays:
      return sw ? 'Siku 7' : '7 days';
    case _HealthTrendFilter.thisMonth:
      return sw ? 'Mwezi huu' : 'This month';
    case _HealthTrendFilter.thisYear:
      return sw ? 'Mwaka huu' : 'This year';
  }
}

enum _IncomeTrendFilter { thisWeek, thisMonth, thisYear }

enum _IncomeTrendDirection { up, down, flat }

class _IncomeTrendComparison {
  const _IncomeTrendComparison({
    required this.currentTotal,
    required this.previousTotal,
    required this.changePercent,
    required this.direction,
  });

  final double currentTotal;
  final double previousTotal;
  final double changePercent;
  final _IncomeTrendDirection direction;
}

String _incomeTrendFilterLabel(_IncomeTrendFilter filter, bool sw) {
  switch (filter) {
    case _IncomeTrendFilter.thisWeek:
      return sw ? 'Wiki hii' : 'This week';
    case _IncomeTrendFilter.thisMonth:
      return sw ? 'Mwezi huu' : 'This month';
    case _IncomeTrendFilter.thisYear:
      return sw ? 'Mwaka huu' : 'This year';
  }
}

bool _isCountedIncome(TransactionActivity transaction) {
  if (!transaction.isCredit || !_isIncomeSpendingMovement(transaction.movementFamily)) {
    return false;
  }
  final status = transaction.status.trim().toLowerCase();
  return !status.contains('failed') &&
      !status.contains('cancel') &&
      !status.contains('reversed') &&
      !status.contains('declined') &&
      !status.contains('pending');
}

bool _isIncomeSpendingMovement(String? movementFamily) {
  final family = movementFamily?.trim().toUpperCase();
  return family == 'INTERNAL_P2P' || family == 'EXTERNAL';
}

bool _isCountedHealthTrendItem(RecentActivityItem item) {
  if (!_isIncomeSpendingMovement(item.movementFamily)) return false;
  final status = item.status.trim().toLowerCase();
  return !status.contains('failed') &&
      !status.contains('cancel') &&
      !status.contains('reversed') &&
      !status.contains('declined') &&
      !status.contains('pending');
}

_IncomeTrendComparison _resolveIncomeTrendComparison(
  List<TransactionActivity> transactions,
  _IncomeTrendFilter filter,
) {
  final now = DateTime.now();
  late final DateTime currentStart;
  late final DateTime currentEnd;
  late final DateTime previousStart;
  late final DateTime previousEnd;

  switch (filter) {
    case _IncomeTrendFilter.thisWeek:
      currentStart = DateUtils.dateOnly(now).subtract(const Duration(days: 6));
      currentEnd = DateUtils.dateOnly(now).add(const Duration(days: 1));
      previousEnd = currentStart;
      previousStart = previousEnd.subtract(const Duration(days: 7));
    case _IncomeTrendFilter.thisMonth:
      currentStart = DateTime(now.year, now.month);
      currentEnd = DateUtils.dateOnly(now).add(const Duration(days: 1));
      previousStart = DateTime(now.year, now.month - 1);
      final previousMonthLastDay = DateTime(
        previousStart.year,
        previousStart.month + 1,
        0,
      ).day;
      previousEnd = DateTime(
        previousStart.year,
        previousStart.month,
        math.min(now.day, previousMonthLastDay) + 1,
      );
    case _IncomeTrendFilter.thisYear:
      currentStart = DateTime(now.year);
      currentEnd = DateUtils.dateOnly(now).add(const Duration(days: 1));
      previousStart = DateTime(now.year - 1);
      final previousYearMonthLastDay = DateTime(
        now.year - 1,
        now.month + 1,
        0,
      ).day;
      previousEnd = DateTime(
        now.year - 1,
        now.month,
        math.min(now.day, previousYearMonthLastDay) + 1,
      );
  }

  double sumBetween(DateTime start, DateTime end) {
    return transactions
        .where(
          (transaction) =>
              _isCountedIncome(transaction) &&
              !transaction.timestamp.isBefore(start) &&
              transaction.timestamp.isBefore(end),
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
  }

  final current = sumBetween(currentStart, currentEnd);
  final previous = sumBetween(previousStart, previousEnd);
  final change = previous.abs() < 0.009
      ? (current > 0 ? 100.0 : 0.0)
      : ((current - previous) / previous.abs()) * 100;
  final direction = change.abs() < 0.05
      ? _IncomeTrendDirection.flat
      : change > 0
      ? _IncomeTrendDirection.up
      : _IncomeTrendDirection.down;

  return _IncomeTrendComparison(
    currentTotal: current,
    previousTotal: previous,
    changePercent: change,
    direction: direction,
  );
}

(double, double) _resolveVisibleRingSplit({
  required double allocated,
  required double unallocated,
}) {
  final safeAllocated = math.max(0.0, allocated).toDouble();
  final safeUnallocated = math.max(0.0, unallocated).toDouble();
  final total = safeAllocated + safeUnallocated;
  if (total <= 0) return (0, 0);
  if (safeAllocated <= 0 || safeUnallocated <= 0) {
    return (safeAllocated, safeUnallocated);
  }

  const minVisibleShare = 0.18;
  final allocatedShare = safeAllocated / total;
  final unallocatedShare = safeUnallocated / total;

  if (allocatedShare < minVisibleShare) {
    final adjustedAllocated = total * minVisibleShare;
    return (adjustedAllocated, total - adjustedAllocated);
  }

  if (unallocatedShare < minVisibleShare) {
    final adjustedUnallocated = total * minVisibleShare;
    return (total - adjustedUnallocated, adjustedUnallocated);
  }

  return (safeAllocated, safeUnallocated);
}

_WealthTimelineSeries _buildIncomeTimelineForFilter(
  List<TransactionActivity> transactions,
  _IncomeTrendFilter filter,
) {
  switch (filter) {
    case _IncomeTrendFilter.thisWeek:
      return _buildWeeklyIncomeTimeline(transactions);
    case _IncomeTrendFilter.thisMonth:
      return _buildMonthlyIncomeTimeline(transactions);
    case _IncomeTrendFilter.thisYear:
      return _buildYearlyIncomeTimeline(transactions);
  }
}

_WealthTimelineSeries _buildWeeklyIncomeTimeline(
  List<TransactionActivity> transactions,
) {
  final now = DateUtils.dateOnly(DateTime.now());
  final dailyIncome = List<double>.filled(7, 0);

  for (final tx in transactions) {
    if (!_isCountedIncome(tx)) continue;
    final day = DateUtils.dateOnly(tx.timestamp);
    final diff = now.difference(day).inDays;
    if (diff < 0 || diff > 6) continue;
    final index = 6 - diff;
    dailyIncome[index] += tx.amount.abs();
  }

  final points = List<_WealthTimelinePoint>.generate(7, (index) {
    final date = now.subtract(Duration(days: 6 - index));
    final income = dailyIncome[index];
    return _WealthTimelinePoint(date: date, value: income, netFlow: income);
  });

  return _WealthTimelineSeries(
    points: points,
    hasRealMovement: dailyIncome.any((value) => value.abs() >= 0.009),
  );
}

_WealthTimelineSeries _buildMonthlyIncomeTimeline(
  List<TransactionActivity> transactions,
) {
  final now = DateTime.now();
  final dailyIncome = List<double>.filled(now.day, 0);

  for (final tx in transactions) {
    if (!_isCountedIncome(tx)) continue;
    final timestamp = tx.timestamp;
    if (timestamp.year != now.year || timestamp.month != now.month) continue;
    dailyIncome[timestamp.day - 1] += tx.amount.abs();
  }

  final points = List<_WealthTimelinePoint>.generate(now.day, (index) {
    final date = DateTime(now.year, now.month, index + 1);
    final income = dailyIncome[index];
    return _WealthTimelinePoint(date: date, value: income, netFlow: income);
  });

  return _WealthTimelineSeries(
    points: points,
    hasRealMovement: dailyIncome.any((value) => value.abs() >= 0.009),
  );
}

_WealthTimelineSeries _buildYearlyIncomeTimeline(
  List<TransactionActivity> transactions,
) {
  final now = DateTime.now();
  final monthlyIncome = List<double>.filled(12, 0);

  for (final tx in transactions) {
    if (!_isCountedIncome(tx)) continue;
    final timestamp = tx.timestamp;
    if (timestamp.year != now.year) continue;
    monthlyIncome[timestamp.month - 1] += tx.amount.abs();
  }

  final points = List<_WealthTimelinePoint>.generate(12, (index) {
    final date = DateTime(now.year, index + 1, 1);
    final income = monthlyIncome[index];
    return _WealthTimelinePoint(date: date, value: income, netFlow: income);
  });

  return _WealthTimelineSeries(
    points: points,
    hasRealMovement: monthlyIncome.any((value) => value.abs() >= 0.009),
  );
}

_TrendSeries _buildHealthTrendSeries(
  List<RecentActivityItem> items,
  _HealthTrendFilter filter,
  bool sw,
) {
  switch (filter) {
    case _HealthTrendFilter.sevenDays:
      final now = DateUtils.dateOnly(DateTime.now());
      final income = List<double>.filled(7, 0);
      final expense = List<double>.filled(7, 0);
      for (final item in items) {
        if (!_isCountedHealthTrendItem(item)) continue;
        final day = DateUtils.dateOnly(item.time);
        final diff = DateUtils.dateOnly(now).difference(day).inDays;
        if (diff < 0 || diff > 6) continue;
        final index = 6 - diff;
        if (item.isCredit) {
          income[index] += item.amount.abs();
        } else {
          expense[index] += item.amount.abs();
        }
      }
      return _TrendSeries(
        income: income,
        expense: expense,
        labels: sw
            ? const ['J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'Leo']
            : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    case _HealthTrendFilter.thisMonth:
      final now = DateTime.now();
      final weeklyIncome = List<double>.filled(5, 0);
      final weeklyExpense = List<double>.filled(5, 0);
      for (final item in items) {
        if (!_isCountedHealthTrendItem(item)) continue;
        final ts = item.time;
        if (ts.year != now.year || ts.month != now.month) continue;
        final bucket = math.min(4, ((ts.day - 1) / 7).floor());
        if (item.isCredit) {
          weeklyIncome[bucket] += item.amount.abs();
        } else {
          weeklyExpense[bucket] += item.amount.abs();
        }
      }
      return _TrendSeries(
        income: weeklyIncome,
        expense: weeklyExpense,
        labels: sw
            ? const ['W1', 'W2', 'W3', 'W4', 'W5']
            : const ['W1', 'W2', 'W3', 'W4', 'W5'],
      );
    case _HealthTrendFilter.thisYear:
      final now = DateTime.now();
      final monthlyIncome = List<double>.filled(12, 0);
      final monthlyExpense = List<double>.filled(12, 0);
      for (final item in items) {
        if (!_isCountedHealthTrendItem(item)) continue;
        final ts = item.time;
        if (ts.year != now.year) continue;
        final index = ts.month - 1;
        if (item.isCredit) {
          monthlyIncome[index] += item.amount.abs();
        } else {
          monthlyExpense[index] += item.amount.abs();
        }
      }
      return _TrendSeries(
        income: monthlyIncome,
        expense: monthlyExpense,
        labels: sw
            ? const [
                'Jan',
                'Feb',
                'Mac',
                'Apr',
                'Mei',
                'Jun',
                'Jul',
                'Ago',
                'Sep',
                'Okt',
                'Nov',
                'Des',
              ]
            : const [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
              ],
      );
  }
}

class _HeroLegendItem extends StatelessWidget {
  const _HeroLegendItem({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: color.withValues(alpha: 0.12))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.78),
                    fontSize: 10.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                _HomeBalanceDisplay(
                  amount: amount,
                  mainFontSize: 11.8,
                  sideFontSize: 8.6,
                  mainColor: Colors.white,
                  sideColor: Colors.white.withValues(alpha: 0.76),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIncomeTrendSection extends StatefulWidget {
  const _HeroIncomeTrendSection({required this.transactions, required this.sw});

  final List<TransactionActivity> transactions;
  final bool sw;

  @override
  State<_HeroIncomeTrendSection> createState() =>
      _HeroIncomeTrendSectionState();
}

class _HeroIncomeTrendSectionState extends State<_HeroIncomeTrendSection> {
  _IncomeTrendFilter _filter = _IncomeTrendFilter.thisWeek;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final series = _buildIncomeTimelineForFilter(widget.transactions, _filter);
    final comparison = _resolveIncomeTrendComparison(
      widget.transactions,
      _filter,
    );
    final trendChange = comparison.changePercent;
    final trendDirection = comparison.direction;
    final trendColor = switch (trendDirection) {
      _IncomeTrendDirection.up => ui.success,
      _IncomeTrendDirection.down => ui.danger,
      _IncomeTrendDirection.flat =>
        isDark ? Colors.white.withValues(alpha: 0.72) : Colors.white,
    };
    final filterLabel = _incomeTrendFilterLabel(_filter, widget.sw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.sw ? 'Mwenendo wa mapato' : 'Income trend',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<_IncomeTrendFilter>(
              initialValue: _filter,
              onSelected: (value) => setState(() => _filter = value),
              color: isDark ? const Color(0xFF15232E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _IncomeTrendFilter.thisWeek,
                  child: Text(
                    _incomeTrendFilterLabel(
                      _IncomeTrendFilter.thisWeek,
                      widget.sw,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: _IncomeTrendFilter.thisMonth,
                  child: Text(
                    _incomeTrendFilterLabel(
                      _IncomeTrendFilter.thisMonth,
                      widget.sw,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: _IncomeTrendFilter.thisYear,
                  child: Text(
                    _incomeTrendFilterLabel(
                      _IncomeTrendFilter.thisYear,
                      widget.sw,
                    ),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.90),
                  borderRadius: BorderRadius.circular(999),
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterLabel,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.84)
                            : const Color(0xFF1E2F3A),
                        fontSize: 11.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.72)
                          : const Color(0xFF607590),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: Tooltip(
                key: ValueKey(
                  '${_filter.name}-${trendDirection.name}-${trendChange.toStringAsFixed(2)}',
                ),
                message: widget.sw
                    ? 'Ikilinganishwa na kipindi kilichopita: ${_formatAmount(context, comparison.previousTotal)}'
                    : 'Compared with the previous period: ${_formatAmount(context, comparison.previousTotal)}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? trendColor.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TrendDirectionGlyph(
                        direction: trendDirection,
                        color: trendColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatSignedPercent(trendChange),
                        style: TextStyle(
                          color: trendColor,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.sw
              ? 'Mapato ya $filterLabel: ${_formatAmount(context, comparison.currentTotal)}'
              : 'Income for $filterLabel: ${_formatAmount(context, comparison.currentTotal)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: isDark ? 0.58 : 0.76),
            fontSize: 10.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 430),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _HeroIncomeSparkline(
            key: ValueKey(_filter),
            series: series,
            sw: widget.sw,
            filter: _filter,
          ),
        ),
      ],
    );
  }
}

class _TrendDirectionGlyph extends StatelessWidget {
  const _TrendDirectionGlyph({required this.direction, required this.color});

  final _IncomeTrendDirection direction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: CustomPaint(
        painter: _TrendDirectionGlyphPainter(
          direction: direction,
          color: color,
        ),
      ),
    );
  }
}

class _TrendDirectionGlyphPainter extends CustomPainter {
  const _TrendDirectionGlyphPainter({
    required this.direction,
    required this.color,
  });

  final _IncomeTrendDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (direction == _IncomeTrendDirection.flat) {
      final y = size.height / 2;
      canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), paint);
      canvas.drawCircle(Offset(size.width / 2, y), 1.35, paint);
      return;
    }

    final isUp = direction == _IncomeTrendDirection.up;
    final startY = isUp ? size.height - 2 : 2.0;
    final middleY = isUp ? size.height * 0.56 : size.height * 0.44;
    final endY = isUp ? 2.0 : size.height - 2;
    final path = Path()
      ..moveTo(1, startY)
      ..lineTo(size.width * 0.34, middleY)
      ..lineTo(size.width * 0.55, isUp ? middleY + 1.6 : middleY - 1.6)
      ..lineTo(size.width - 2, endY);
    canvas.drawPath(path, paint);

    final arrowTip = Offset(size.width - 2, endY);
    final arrowWingY = isUp ? endY + 4 : endY - 4;
    canvas.drawLine(arrowTip, Offset(size.width - 6, arrowWingY), paint);
    canvas.drawLine(arrowTip, Offset(size.width - 6.5, endY), paint);
  }

  @override
  bool shouldRepaint(covariant _TrendDirectionGlyphPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}

class _HeroIncomeSparkline extends StatelessWidget {
  const _HeroIncomeSparkline({
    super.key,
    required this.series,
    required this.sw,
    required this.filter,
  });

  final _WealthTimelineSeries series;
  final bool sw;
  final _IncomeTrendFilter filter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = series.points;
    final labels = points.map((point) {
      switch (filter) {
        case _IncomeTrendFilter.thisWeek:
          return DateFormat('E').format(point.date);
        case _IncomeTrendFilter.thisMonth:
          return DateFormat('d').format(point.date);
        case _IncomeTrendFilter.thisYear:
          return DateFormat('MMM').format(point.date);
      }
    }).toList();
    final values = points.map((point) => point.value).toList();
    final maxValue = values.isEmpty ? 1.0 : values.reduce(math.max);
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.18;
    final axisInterval = chartMax / 2;
    final lineColors = isDark
        ? const [Color(0xFF8AF2CC), Color(0xFF34D399), Color(0xFF20A66A)]
        : const [Color(0xFFFFFFFF), Color(0xFFC7F7DF), Color(0xFF35D99A)];
    final endpointColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFFC7F7DF);

    return SizedBox(
      height: 116,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          final animatedValues = values
              .map((value) => value * progress)
              .toList(growable: false);
          return LineChart(
            duration: const Duration(milliseconds: 0),
            LineChartData(
              minX: 0,
              maxX: math.max(0, points.length - 1).toDouble(),
              minY: 0,
              maxY: chartMax,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: axisInterval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.13),
                  strokeWidth: 0.8,
                  dashArray: const [4, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: axisInterval,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      space: 5,
                      child: Text(
                        _formatCompactChartValue(value),
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.40 : 0.58,
                          ),
                          fontSize: 8.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      final shouldShow = switch (filter) {
                        _IncomeTrendFilter.thisWeek => true,
                        _IncomeTrendFilter.thisMonth =>
                          index == 0 ||
                              index == labels.length - 1 ||
                              index % 5 == 0,
                        _IncomeTrendFilter.thisYear =>
                          index == labels.length - 1 || index.isEven,
                      };
                      if (!shouldShow) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.46)
                                : Colors.white.withValues(alpha: 0.64),
                            fontSize: 9.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) =>
                    spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.28),
                          strokeWidth: 1,
                          dashArray: const [3, 4],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, dotIndex) =>
                              FlDotCirclePainter(
                                radius: 4.5,
                                color: endpointColor,
                                strokeWidth: 2.2,
                                strokeColor: Colors.white,
                              ),
                        ),
                      );
                    }).toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      const Color(0xFF102A32).withValues(alpha: 0.94),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final index = spot.x.round();
                    return LineTooltipItem(
                      '${labels[index]}\n${_formatAmount(context, values[index])}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    animatedValues.length,
                    (i) => FlSpot(i.toDouble(), animatedValues[i]),
                  ),
                  isCurved: true,
                  curveSmoothness: 0.36,
                  preventCurveOverShooting: true,
                  barWidth: 3.2,
                  isStrokeCapRound: true,
                  gradient: LinearGradient(colors: lineColors),
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) =>
                        spot.x == (points.length - 1).toDouble(),
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4.2,
                          color: endpointColor,
                          strokeWidth: 2.2,
                          strokeColor: Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        endpointColor.withValues(alpha: isDark ? 0.22 : 0.28),
                        endpointColor.withValues(alpha: 0.015),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ui.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ui.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HomeBalanceDisplay extends StatelessWidget {
  const _HomeBalanceDisplay({
    required this.amount,
    required this.mainFontSize,
    required this.sideFontSize,
    required this.mainColor,
    required this.sideColor,
  });

  final double amount;
  final double mainFontSize;
  final double sideFontSize;
  final Color mainColor;
  final Color sideColor;

  @override
  Widget build(BuildContext context) {
    return MoneyText(
      value: _formatAmount(context, amount),
      mainFontSize: mainFontSize,
      sideFontSize: sideFontSize,
      fitToWidth: true,
      mainColor: mainColor,
      sideColor: sideColor,
      fontWeight: FontWeight.w800,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ui.border),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE06C2F),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You are viewing the last synced dashboard state.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForInsight(GuardianInsightType type) {
  switch (type) {
    case GuardianInsightType.spendingAlert:
      return Icons.trending_up_rounded;
    case GuardianInsightType.savingSuggestion:
      return Icons.savings_rounded;
    case GuardianInsightType.goalPrediction:
      return Icons.flag_rounded;
    case GuardianInsightType.budgetWarning:
      return Icons.warning_amber_rounded;
    case GuardianInsightType.securityWarning:
      return Icons.verified_user_rounded;
  }
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
