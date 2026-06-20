import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/backend_status_message.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/widgets/orbi_async_feedback.dart';
import '../../../../core/widgets/pin_prompt.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/wallet_models.dart';
import '../../data/wallet_service.dart';
import '../../state/wallet_view_model.dart';

class WalletTransactionBottomSheet extends StatefulWidget {
  const WalletTransactionBottomSheet({
    super.key,
    required this.wallet,
  });

  final WalletRecord wallet;

  static Future<void> show(BuildContext context, WalletRecord wallet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrbiTheme.uiOf(context).sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: context.read<WalletViewModel>(),
          child: WalletTransactionBottomSheet(wallet: wallet),
        );
      },
    );
  }

  @override
  State<WalletTransactionBottomSheet> createState() =>
      _WalletTransactionBottomSheetState();
}

class _WalletTransactionBottomSheetState
    extends State<WalletTransactionBottomSheet> {
  TransactionLifecycle? _selectedLifecycle;
  List<WalletTransactionRecord> _visibleItems = const [];
  int _lastCount = -1;
  TransactionLifecycle? _lastLifecycle;
  final WalletService _walletService = WalletService();
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;

  WalletRecord _currentWallet(WalletViewModel viewModel) {
    for (final wallet in viewModel.wallets) {
      if (wallet.id == widget.wallet.id) return wallet;
    }
    return widget.wallet;
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
      setState(() {
        _statusMessage = mapBackendStatusMessage(
          l10n.loginInvalidPinMessage,
          sw: sw,
          fallback: l10n.loginInvalidPinMessage,
        );
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _busy = true;
          _busyMessage = wallet.isLocked
              ? (sw ? 'Inafungua walleti...' : 'Unlocking wallet...')
              : (sw ? 'Inafunga walleti...' : 'Locking wallet...');
        });
      }
      if (wallet.isLocked) {
        await _walletService.unlockWallet(wallet.id, pin: pin.trim());
      } else {
        await _walletService.lockWallet(
          wallet.id,
          pin: pin.trim(),
          reason: sw ? 'Imefungwa na mtumiaji' : 'Locked by user',
        );
      }
      if (!context.mounted) return;
      await context.read<WalletViewModel>().refresh();
      if (!context.mounted) return;
      final message = wallet.isLocked
          ? (sw ? 'Wallet imefunguliwa.' : 'Wallet unlocked.')
          : (sw ? 'Wallet imefungwa.' : 'Wallet locked.');
      setState(() {
        _statusMessage = mapBackendStatusMessage(
          message,
          sw: sw,
          fallback: message,
        );
        _statusTone = OrbiStatusTone.success;
      });
    } catch (e) {
      if (!context.mounted) return;
      final message = UserFacingError.from(
        e,
        fallback: sw
            ? 'Imeshindikana kubadilisha hali ya wallet.'
            : 'Unable to change wallet status.',
      );
      setState(() {
        _statusMessage = mapBackendStatusMessage(
          message,
          sw: sw,
          fallback: message,
        );
        _statusTone = OrbiStatusTone.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
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
              ? 'Akaunti hii ya nje itaondolewa kwenye orodha yako ya wallet.'
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

    try {
      setState(() {
        _busy = true;
        _busyMessage = sw ? 'Inafuta akaunti...' : 'Deleting wallet...';
      });
      await _walletService.deleteWallet(wallet.id);
      if (!context.mounted) return;
      await context.read<WalletViewModel>().refresh();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      final message = UserFacingError.from(
        e,
        fallback: sw ? 'Imeshindikana kufuta akaunti.' : 'Unable to delete wallet.',
      );
      setState(() {
        _statusMessage = mapBackendStatusMessage(
          message,
          sw: sw,
          fallback: message,
        );
        _statusTone = OrbiStatusTone.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletViewModel>().loadTransactions(widget.wallet);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibleItems();
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<WalletViewModel>();
    final txState = viewModel.transactionsFor(widget.wallet.id);
    final wallet = _currentWallet(viewModel);
    _syncVisibleItems();

    return OrbiLoadingOverlay(
      loading: _busy,
      message: _busyMessage,
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: () {
        if (!mounted) return;
        setState(() => _statusMessage = null);
      },
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ui.cardStrong.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ui.borderStrong.withValues(alpha: 0.74),
                      ),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: ui.iconMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.walletTransactionsTitle(wallet.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: wallet.isLocked
                        ? l10n.actionUnlock
                        : (Localizations.localeOf(context)
                                    .languageCode
                                    .toLowerCase() ==
                                'sw'
                            ? 'Funga'
                            : 'Lock'),
                    onPressed: () => _handleWalletLockToggle(context, wallet),
                    icon: Icon(
                      wallet.isLocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      color: wallet.isLocked ? ui.success : ui.iconMuted,
                    ),
                  ),
                  if (wallet.isLinked)
                    IconButton(
                      tooltip: Localizations.localeOf(context)
                                  .languageCode
                                  .toLowerCase() ==
                              'sw'
                          ? 'Futa'
                          : 'Delete',
                      onPressed: () => _handleWalletDelete(context, wallet),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: ui.danger,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: ui.iconMuted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.transactionsFilterByMoneyState,
                style: TextStyle(
                  color: ui.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(
                      context,
                      label: l10n.transactionsFilterAll,
                      selected: _selectedLifecycle == null,
                      onTap: () => setState(() => _selectedLifecycle = null),
                    ),
                    ...TransactionLifecycle.values.map(
                      (lifecycle) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _chip(
                          context,
                          label: _lifecycleLabel(l10n, lifecycle),
                          selected: _selectedLifecycle == lifecycle,
                          onTap: () => setState(() => _selectedLifecycle = lifecycle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (txState.isLoading && txState.items.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (txState.error != null && txState.items.isEmpty) {
                      return Center(
                        child: Text(
                          txState.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ui.textMuted, fontSize: 13),
                        ),
                      );
                    }
                    if (_visibleItems.isEmpty) {
                      return Center(
                        child: Text(
                          txState.items.isEmpty
                              ? l10n.walletNoTransactionsFound
                              : l10n.transactionsNoFilteredMatchesMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ui.textMuted, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: _visibleItems.length + (txState.hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          Divider(color: ui.border),
                      itemBuilder: (context, index) {
                        if (index == _visibleItems.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: txState.isLoading
                                    ? null
                                    : () => context
                                        .read<WalletViewModel>()
                                        .loadTransactions(widget.wallet, loadMore: true),
                                child: Text(
                                  txState.isLoading ? 'Loading...' : 'Load more',
                                ),
                              ),
                            ),
                          );
                        }
                        final tx = _visibleItems[index];
                        final amountColor = tx.isCredit
                            ? ui.success
                            : (tx.isDebit ? ui.danger : ui.textPrimary);
                        final tileAccent = tx.isCredit
                            ? ui.success
                            : (tx.isDebit ? ui.danger : ui.accent);
                        final amountText = _formatTransactionAmount(
                          context,
                          tx,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tileAccent.withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              color: tileAccent,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            tx.kind.toUpperCase(),
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${l10n.walletTransactionRef(tx.reference)} • ${_lifecycleLabel(l10n, tx.lifecycle)}${tx.createdAt.isNotEmpty ? '\n${tx.createdAt}' : ''}',
                            style: TextStyle(
                              color: ui.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Text(
                            amountText,
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _syncVisibleItems() {
    final txState = context.read<WalletViewModel>().transactionsFor(widget.wallet.id);
    if (_lastCount == txState.items.length && _lastLifecycle == _selectedLifecycle) {
      return;
    }
    _lastCount = txState.items.length;
    _lastLifecycle = _selectedLifecycle;
    _visibleItems = _selectedLifecycle == null
        ? txState.items
        : (txState.groupedByLifecycle[_selectedLifecycle] ?? const []);
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ui = OrbiTheme.uiOf(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? ui.textPrimary : ui.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: ui.cardStrong.withValues(alpha: 0.96),
      backgroundColor: ui.cardMuted.withValues(alpha: 0.76),
      side: BorderSide(
        color: selected
            ? ui.borderStrong.withValues(alpha: 0.86)
            : ui.border.withValues(alpha: 0.78),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  String _formatTransactionAmount(
    BuildContext context,
    WalletTransactionRecord tx,
  ) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    final sign = tx.isCredit ? '+' : (tx.isDebit ? '-' : '');
    return '$sign${formatAppBalanceAmount(tx.amount.abs(), tx.currency, locale: localeTag)}';
  }

  String _lifecycleLabel(
    AppLocalizations l10n,
    TransactionLifecycle lifecycle,
  ) {
    switch (lifecycle) {
      case TransactionLifecycle.available:
        return l10n.moneyStateAvailable;
      case TransactionLifecycle.allocated:
        return l10n.moneyStateAllocated;
      case TransactionLifecycle.budgeted:
        return l10n.moneyStateBudgeted;
      case TransactionLifecycle.saved:
        return l10n.moneyStateSaved;
      case TransactionLifecycle.locked:
        return l10n.moneyStateLocked;
      case TransactionLifecycle.spent:
        return l10n.moneyStateSpent;
    }
  }
}
