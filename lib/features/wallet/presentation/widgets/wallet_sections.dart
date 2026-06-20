import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../../core/state/app_settings_controller.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/widgets/orbi_primary_quick_actions.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/orbi_state_card.dart';
import '../../../../core/widgets/pin_prompt.dart';
import '../../data/wallet_models.dart';
import '../../data/wallet_service.dart';
import '../../state/wallet_view_model.dart';

class WalletHeroCard extends StatelessWidget {
  const WalletHeroCard({
    super.key,
    required this.theme,
    required this.ui,
    required this.walletCount,
    required this.customerName,
    required this.hideBalances,
    required this.onToggleBalanceVisibility,
    required this.balanceText,
  });

  final ThemeData theme;
  final OrbiUiTokens ui;
  final int walletCount;
  final String customerName;
  final bool hideBalances;
  final VoidCallback onToggleBalanceVisibility;
  final String balanceText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroTop = isDark
        ? ui.cardStrong.withValues(alpha: 0.96)
        : Color.lerp(ui.cardStrong, ui.accent, 0.10) ?? ui.cardStrong;
    final heroMid = isDark
        ? ui.card.withValues(alpha: 0.88)
        : Color.lerp(ui.cardMuted, ui.accent, 0.04) ?? ui.cardMuted;
    final heroTail = isDark
        ? ui.sheet.withValues(alpha: 0.98)
        : Color.lerp(ui.sheet, ui.cardStrong, 0.58) ?? ui.sheet;
    final heroPanelTop = isDark
        ? ui.cardStrong.withValues(alpha: 0.94)
        : ui.card;
    final heroPanelBottom = isDark
        ? ui.card.withValues(alpha: 0.82)
        : ui.cardMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            heroTop,
            heroMid,
            heroTail,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : ui.borderStrong.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0xFF0D3A4A).withValues(alpha: 0.065),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
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
                      l10n.walletTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: ui.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.walletSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ui.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? ui.cardMuted.withValues(alpha: 0.84)
                      : ui.cardStrong,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ui.border),
                ),
                child: Text(
                  '$walletCount ${sw ? 'akaunti' : 'wallets'}',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [heroPanelTop, heroPanelBottom],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : ui.border.withValues(alpha: 0.85),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      sw ? 'Salio kuu' : 'Operating balance',
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onToggleBalanceVisibility,
                      tooltip: hideBalances
                          ? l10n.walletShowBalances
                          : l10n.walletHideBalances,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? ui.cardStrong.withValues(alpha: 0.48)
                            : ui.cardStrong.withValues(alpha: 0.92),
                        foregroundColor: ui.iconMuted,
                        minimumSize: const Size(32, 32),
                        padding: const EdgeInsets.all(6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        hideBalances
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                hideBalances
                    ? SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppSettingsController.hiddenBalanceText,
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      )
                    : MoneyText(
                        value: balanceText,
                        mainFontSize: 26,
                        sideFontSize: 12.5,
                        fitToWidth: true,
                      ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WalletSignalTile(
                      ui: ui,
                      icon: Icons.person_outline_rounded,
                      label: sw ? 'Akaunti' : 'Account',
                      value: customerName,
                    ),
                    _WalletSignalTile(
                      ui: ui,
                      icon: Icons.verified_user_outlined,
                      label: sw ? 'Hali' : 'Status',
                      value: sw ? 'Inaendelea' : 'Active',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WalletControls extends StatelessWidget {
  const WalletControls({
    super.key,
    required this.viewModel,
    required this.hideBalances,
    required this.onToggleBalanceVisibility,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSend,
    required this.onScan,
  });

  final WalletViewModel viewModel;
  final bool hideBalances;
  final VoidCallback onToggleBalanceVisibility;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSend;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return OrbiPrimaryQuickActions(
      onDeposit: onDeposit,
      onWithdraw: onWithdraw,
      onSend: onSend,
      onScan: onScan,
    );
  }
}

class MasterStyleTransferCard extends StatelessWidget {
  const MasterStyleTransferCard({
    super.key,
    required this.wallet,
    required this.holderName,
    required this.cardNumber,
    required this.balanceText,
  });

  final WalletRecord wallet;
  final String holderName;
  final String cardNumber;
  final String balanceText;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final maskedNumber = _maskedCardNumber(cardNumber);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark
        ? (Color.lerp(wallet.accentColor, ui.cardStrong, 0.74) ??
            ui.cardStrong)
        : (Color.lerp(wallet.accentColor, Colors.white, 0.76) ??
            Colors.white);
    final midColor = isDark
        ? (Color.lerp(ui.card, wallet.accentColor, 0.10) ?? ui.card)
        : (Color.lerp(ui.card, wallet.accentColor, 0.08) ?? ui.card);
    final bottomColor = isDark
        ? (Color.lerp(ui.sheet, Colors.black, 0.16) ?? ui.sheet)
        : (Color.lerp(ui.sheet, Colors.white, 0.18) ?? ui.sheet);

    return AspectRatio(
      aspectRatio: 1.68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [topColor, midColor, bottomColor],
              ),
            border: Border.all(
              color: isDark
                  ? wallet.accentColor.withValues(alpha: 0.22)
                  : wallet.accentColor.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.32)
                    : wallet.accentColor.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -12,
                top: -24,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ui.success.withValues(alpha: isDark ? 0.18 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -18,
                bottom: -28,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        wallet.accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                        Colors.transparent,
                      ],
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
                        width: 38,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD9BA7A), Color(0xFFC4962E)],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 13,
                              color: ui.textSoft,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'ORBI',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: ui.textSoft,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    maskedNumber,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MoneyText(
                              value: balanceText,
                              mainFontSize: 18,
                              sideFontSize: 10,
                              fontWeight: FontWeight.w800,
                              mainColor: ui.textPrimary,
                              sideColor: ui.textMuted.withValues(alpha: 0.78),
                              fitToWidth: true,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              holderName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ui.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Primary wallet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ui.textMuted.withValues(alpha: 0.72),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5F00),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            left: 16,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFC300),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskedCardNumber(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '•••• •••• •••• 0000';
    final compact = clean.replaceAll(' ', '');
    if (compact.length < 4) return clean;
    final tail = compact.substring(compact.length - 4);
    return '•••• •••• •••• $tail';
  }
}

class WalletListSection extends StatefulWidget {
  const WalletListSection({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.hideBalances,
    required this.onWalletTap,
    required this.onLinkWallet,
    required this.runAsyncAction,
    required this.onStatus,
  });

  final ThemeData theme;
  final WalletViewModel viewModel;
  final bool hideBalances;
  final ValueChanged<WalletRecord> onWalletTap;
  final VoidCallback onLinkWallet;
  final Future<void> Function(String message, Future<void> Function() action)
  runAsyncAction;
  final void Function(String message, {required bool isError}) onStatus;

  @override
  State<WalletListSection> createState() => _WalletListSectionState();
}

class _WalletListSectionState extends State<WalletListSection> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _activePage = 0;
  double _pagePosition = 0;
  bool _autoSlidePaused = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92)
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _pagePosition = _pageController.page ?? _activePage.toDouble();
        });
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAutoSlide();
  }

  @override
  void didUpdateWidget(covariant WalletListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.viewModel.wallets.where((wallet) => wallet.isLinked).length;
    final newCount = widget.viewModel.wallets.where((wallet) => wallet.isLinked).length;
    if (oldCount != newCount) {
      if (_activePage >= newCount && newCount > 0) {
        _activePage = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
      _syncAutoSlide();
    }
  }

  void _syncAutoSlide() {
    _autoSlideTimer?.cancel();
    final linkedCount = widget.viewModel.wallets.where((wallet) => wallet.isLinked).length;
    if (linkedCount <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients || _autoSlidePaused) return;
      final nextPage = (_activePage + 1) % linkedCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setAutoSlidePaused(bool value) {
    if (_autoSlidePaused == value || !mounted) return;
    setState(() => _autoSlidePaused = value);
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleWalletDelete(
    BuildContext context,
    WalletRecord wallet,
  ) async {
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(sw ? 'Futa akaunti hii?' : 'Delete this wallet?'),
        content: Text(
          sw
              ? 'Akaunti hii ya nje itaondolewa kutoka kwenye orodha yako ya wallet.'
              : 'This linked wallet will be removed from your wallet list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(sw ? 'Ghairi' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(sw ? 'Futa' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final service = WalletService();
    try {
      await widget.runAsyncAction(
        sw ? 'Inafuta akaunti...' : 'Deleting wallet...',
        () => service.deleteWallet(wallet.id),
      );
      if (!context.mounted) return;
      await widget.viewModel.refresh();
      if (!context.mounted) return;
      widget.onStatus(
        sw ? 'Akaunti imefutwa.' : 'Wallet deleted.',
        isError: false,
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = UserFacingError.from(
        e,
        fallback: sw
            ? 'Imeshindikana kufuta akaunti.'
            : 'Unable to delete wallet.',
      );
      widget.onStatus(message, isError: true);
    }
  }

  Future<void> _handleWalletLockToggle(
    BuildContext context,
    WalletRecord wallet,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final storage = SecureStorageService();
    final hasPin = await storage.hasPin();
    if (!context.mounted) return;
    if (!hasPin) {
      final pinSet = await promptPinSetup(context);
      if (!context.mounted) return;
      if (!pinSet) return;
    }

    final pin = await promptCurrentPin(context);
    if (!context.mounted) return;
    if (pin == null || pin.trim().isEmpty) return;
    final ok = await storage.verifyPin(pin.trim());
    if (!context.mounted) return;
    if (!ok) {
      widget.onStatus(l10n.loginInvalidPinMessage, isError: true);
      return;
    }

    final service = WalletService();
    try {
      await widget.runAsyncAction(
        wallet.isLocked
            ? (sw ? 'Inafungua walleti...' : 'Unlocking wallet...')
            : (sw ? 'Inafunga walleti...' : 'Locking wallet...'),
        () async {
          if (wallet.isLocked) {
            await service.unlockWallet(wallet.id, pin: pin.trim());
          } else {
            await service.lockWallet(
              wallet.id,
              pin: pin.trim(),
              reason: sw ? 'Imefungwa na mtumiaji' : 'Locked by user',
            );
          }
        },
      );
      if (!context.mounted) return;
      await widget.viewModel.refresh();
      if (!context.mounted) return;
      final message = wallet.isLocked
          ? (sw ? 'Wallet imefunguliwa.' : 'Wallet unlocked.')
          : (sw ? 'Wallet imefungwa.' : 'Wallet locked.');
      widget.onStatus(message, isError: false);
    } catch (e) {
      if (!context.mounted) return;
      final message = UserFacingError.from(
        e,
        fallback: sw
            ? 'Imeshindikana kubadilisha hali ya wallet.'
            : 'Unable to change wallet status.',
      );
      widget.onStatus(message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    final linkedWallets = widget.viewModel.wallets.where((wallet) => wallet.isLinked).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                sw ? 'Walleti zilizounganishwa' : 'Linked wallets',
                style: widget.theme.textTheme.titleLarge?.copyWith(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.onLinkWallet,
              icon: const Icon(Icons.link_rounded, size: 17),
              label: Text(sw ? 'Unganisha' : 'Link wallet'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.viewModel.isLoading) const _WalletLoadingCard(),
        if (!widget.viewModel.isLoading && widget.viewModel.error != null)
          OrbiStateCard(
            icon: Icons.cloud_off_rounded,
            title: l10n.walletFailedLoadAccounts,
            message: widget.viewModel.error,
            accentColor: ui.danger,
            accentBackground: ui.dangerSoft,
          ),
        if (!widget.viewModel.isLoading &&
            widget.viewModel.error == null &&
            widget.viewModel.wallets.isEmpty)
          _LinkedWalletEmptyCard(
            icon: Icons.account_balance_wallet_outlined,
            title: sw ? 'Hakuna walleti zilizounganishwa bado.' : 'No linked wallets yet.',
            message: sw
                ? 'Unganisha walleti yako ya kwanza ili ionekane hapa.'
                : 'Link your first wallet and it will appear here.',
            accentColor: ui.iconMuted,
            accentBackground: ui.cardStrong,
          ),
        if (!widget.viewModel.isLoading &&
            widget.viewModel.error == null &&
            linkedWallets.isEmpty &&
            widget.viewModel.wallets.isNotEmpty)
          _LinkedWalletEmptyCard(
            icon: Icons.link_off_rounded,
            title: sw ? 'Hakuna walleti zilizounganishwa.' : 'No linked wallets.',
            message: sw
                ? 'Unganisha walleti mpya ili ionekane hapa.'
                : 'Link a wallet to show it here.',
            accentColor: ui.iconMuted,
            accentBackground: ui.cardStrong,
          ),
        if (!widget.viewModel.isLoading &&
            widget.viewModel.error == null &&
            linkedWallets.isNotEmpty)
          Column(
            children: [
              SizedBox(
                height: 188,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _setAutoSlidePaused(true);
                    } else if (notification is ScrollEndNotification) {
                      _setAutoSlidePaused(false);
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: linkedWallets.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() {
                        _activePage = index;
                        _pagePosition = index.toDouble();
                      });
                    },
                    itemBuilder: (context, index) {
                      final wallet = linkedWallets[index];
                      final distance = (_pagePosition - index).abs();
                      final scale = (1 - (distance * 0.06)).clamp(0.94, 1.0);
                      final topInset = (distance * 8).clamp(0, 8).toDouble();
                      final signedOffset = (_pagePosition - index) * 10;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: AnimatedScale(
                          scale: scale,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.only(top: topInset, bottom: 2),
                            child: Transform.translate(
                              offset: Offset(signedOffset.clamp(-10, 10).toDouble(), 0),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => _setAutoSlidePaused(true),
                                onTapUp: (_) => _setAutoSlidePaused(false),
                                onTapCancel: () => _setAutoSlidePaused(false),
                                onLongPressStart: (_) => _setAutoSlidePaused(true),
                                onLongPressEnd: (_) => _setAutoSlidePaused(false),
                              child: _WalletListCard(
                                wallet: wallet,
                                hideBalances: widget.hideBalances,
                                motionEmphasis: (1 - distance.clamp(0.0, 1.0)).toDouble(),
                                onTap: () => widget.onWalletTap(wallet),
                                onLockToggle: () => _handleWalletLockToggle(context, wallet),
                                onDelete: wallet.isLinked
                                    ? () => _handleWalletDelete(context, wallet)
                                    : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (linkedWallets.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    linkedWallets.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _activePage == index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _activePage == index
                            ? ui.accent
                            : ui.borderStrong.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _LinkedWalletEmptyCard extends StatelessWidget {
  const _LinkedWalletEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
    required this.accentBackground,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;
  final Color accentBackground;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 220),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ui.card.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ui.border.withValues(alpha: 0.78)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12.5,
                    height: 1.35,
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

class _WalletSignalTile extends StatelessWidget {
  const _WalletSignalTile({
    required this.ui,
    required this.icon,
    required this.label,
    required this.value,
  });

  final OrbiUiTokens ui;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? ui.cardStrong.withValues(alpha: 0.88)
                : ui.card,
            isDark
                ? ui.card.withValues(alpha: 0.76)
                : Color.lerp(ui.cardMuted, ui.accent, 0.035) ?? ui.cardMuted,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : ui.border.withValues(alpha: 0.86),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ui.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: ui.textMuted, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _WalletListCard extends StatelessWidget {
  const _WalletListCard({
    required this.wallet,
    required this.hideBalances,
    required this.motionEmphasis,
    required this.onTap,
    required this.onLockToggle,
    this.onDelete,
  });

  final WalletRecord wallet;
  final bool hideBalances;
  final double motionEmphasis;
  final VoidCallback onTap;
  final VoidCallback onLockToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final sw = Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    ui.cardStrong.withValues(alpha: 0.92),
                    ui.card.withValues(alpha: 0.82),
                  ]
                : [
                    ui.card,
                    Color.lerp(ui.cardMuted, wallet.accentColor, 0.04) ??
                        ui.cardMuted,
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : ui.border.withValues(alpha: 0.9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.16
                    : 0.04,
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: wallet.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _WalletAvatar(wallet: wallet),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: ui.cardMuted.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: ui.border),
                  ),
                  child: Text(
                    sw ? 'Imeunganishwa' : 'Linked',
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sw ? 'Walleti iliyounganishwa' : 'Connected wallet',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              wallet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
              ),
            ),
            const Spacer(),
            Text(
              sw ? 'Salio lililounganishwa' : 'Connected balance',
              style: TextStyle(color: ui.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            hideBalances
                ? SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppSettingsController.hiddenBalanceText,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  )
                : MoneyText(
                    value: formatCompactMoney(
                      wallet.balance,
                      wallet.currency,
                      locale: _localeTag(context),
                      compactFrom: kLargeCardCompactThreshold,
                    ),
                    mainFontSize: 19,
                    sideFontSize: 10.5,
                    fitToWidth: true,
                  ),
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: wallet.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (wallet.isLocked
                        ? 0.26 + (motionEmphasis * 0.16)
                        : 0.46 + (motionEmphasis * 0.18))
                    .clamp(0.24, 0.68),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: wallet.accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WalletMetaChip(
                  label: wallet.kindLabel,
                  foreground: wallet.accentColor,
                  background: wallet.accentColor.withValues(alpha: 0.10),
                ),
                _WalletMetaChip(
                  label: wallet.status.toUpperCase(),
                  foreground: ui.textSoft,
                  background: ui.cardStrong,
                ),
                if (wallet.isLocked)
                  _WalletMetaChip(
                    icon: Icons.lock_rounded,
                    label: sw ? 'IMEFUNGWA' : 'LOCKED',
                    foreground: ui.danger,
                    background: ui.dangerSoft,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WalletActionChip(
                  icon: Icons.receipt_long_rounded,
                  label: l10n.walletTransactionsButton,
                  color: wallet.accentColor,
                  onTap: onTap,
                ),
                _WalletActionChip(
                  icon: wallet.isLocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  label: wallet.isLocked ? l10n.actionUnlock : (sw ? 'Funga' : 'Lock'),
                  color: wallet.isLocked ? ui.success : ui.textMuted,
                  onTap: onLockToggle,
                ),
                if (onDelete != null)
                  _WalletActionChip(
                    icon: Icons.delete_outline_rounded,
                    label: sw ? 'Futa' : 'Delete',
                    color: ui.danger,
                    onTap: onDelete!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _localeTag(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }
}

class _WalletMetaChip extends StatelessWidget {
  const _WalletMetaChip({
    this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData? icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletActionChip extends StatelessWidget {
  const _WalletActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? ui.cardStrong.withValues(alpha: 0.56)
                : ui.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ui.border.withValues(alpha: 0.72)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.5, color: color.withValues(alpha: 0.92)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAvatar extends StatelessWidget {
  const _WalletAvatar({required this.wallet});

  final WalletRecord wallet;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final providerIcon = wallet.providerIcon;
    final providerColor = wallet.providerColor;
    final parsedProviderColor =
        providerColor == null ? null : _parseColor(providerColor);
    final badgeColor = parsedProviderColor ?? wallet.accentColor;

    Widget child = Icon(wallet.icon, color: badgeColor, size: 19);
    if (providerIcon != null && providerIcon.isNotEmpty && wallet.isLinked) {
      if (providerIcon.startsWith('http')) {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Image.network(
            providerIcon,
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              wallet.icon,
              color: badgeColor,
              size: 19,
            ),
          ),
        );
      } else if (providerIcon.startsWith('assets/')) {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Image.asset(
            providerIcon,
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: badgeColor.withValues(alpha: 0.18),
        border: Border.all(
          color: ui.border.withValues(alpha: 0.6),
        ),
      ),
      child: Center(child: child),
    );
  }

  Color? _parseColor(String value) {
    var hex = value.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

class _WalletLoadingCard extends StatelessWidget {
  const _WalletLoadingCard();

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: ui.cardMuted,
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.walletLoadingAccounts,
              style: TextStyle(
                color: ui.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
