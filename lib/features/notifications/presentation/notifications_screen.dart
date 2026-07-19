import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_responsive.dart';
import '../../../core/widgets/orbi_shimmer.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../../payment/data/service_payment_challenge_service.dart';
import '../state/notification_controller.dart';

String toCustomerFriendlyText(String raw) {
  var text = raw;
  final rules = <MapEntry<RegExp, String>>[
    MapEntry(
      RegExp(r'\bsovereign financial node\b', caseSensitive: false),
      'account',
    ),
    MapEntry(RegExp(r'\bnode\b', caseSensitive: false), 'account'),
    MapEntry(RegExp(r'\bsovereign\b', caseSensitive: false), 'secure'),
    MapEntry(RegExp(r'\bvaults\b', caseSensitive: false), 'wallets'),
    MapEntry(RegExp(r'\bvault\b', caseSensitive: false), 'wallet'),
    MapEntry(RegExp(r'\bledger\b', caseSensitive: false), 'records'),
    MapEntry(RegExp(r'\binstitutional\b', caseSensitive: false), 'personal'),
    MapEntry(RegExp(r'\bprovisioned\b', caseSensitive: false), 'set up'),
    MapEntry(RegExp(r'\bdilpesa\b', caseSensitive: false), 'Orbi'),
    MapEntry(RegExp(r'\bpaysafe\b', caseSensitive: false), 'Orbi'),
  ];

  for (final rule in rules) {
    text = text.replaceAll(rule.key, rule.value);
  }

  return text;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isSelecting = false;
  final Set<String> _selectedIds = <String>{};

  List<NotificationItem> get _notifications =>
      context.watch<NotificationController>().items;
  int get _unreadCount => context.watch<NotificationController>().unreadCount;

  void _markAsRead(String id) {
    context.read<NotificationController>().markAsRead(id);
  }

  void _markAllAsRead() {
    context.read<NotificationController>().markAllAsRead();
  }

  void _deleteSelected() {
    context.read<NotificationController>().deleteMultiple(_selectedIds);
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _notifications.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_notifications.map((notification) => notification.id));
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _openDetail(NotificationItem notification) {
    _markAsRead(notification.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(notification: notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final controller = context.watch<NotificationController>();
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 380;

    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelecting) {
          _exitSelection();
        }
      },
      child: Scaffold(
        backgroundColor: ui.sheet,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: ui.appBarMid.withValues(alpha: 0.72),
          surfaceTintColor: Colors.transparent,
          title: Text(
            _isSelecting
                ? l10n.notificationsSelectedCount(_selectedIds.length)
                : l10n.notificationsTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: _isSelecting
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                )
              : null,
          actions: [
            if (_isSelecting)
              IconButton(
                tooltip: _selectedIds.length == _notifications.length
                    ? l10n.notificationsClearSelection
                    : l10n.notificationsSelectAll,
                onPressed: _notifications.isEmpty ? null : _toggleSelectAll,
                icon: Icon(
                  _selectedIds.length == _notifications.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
              ),
            if (_isSelecting)
              IconButton(
                icon: Icon(Icons.delete_sweep_outlined, color: ui.danger),
                onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: OrbiBackground(
            padding: EdgeInsets.zero,
            child: OrbiResponsiveContent(
              padding: OrbiResponsive.pagePadding(context, top: 8, bottom: 12),
              child: controller.isLoading
                  ? const _NotificationsLoadingState()
                  : controller.error != null
                  ? _NotificationErrorState(message: controller.error!)
                  : _notifications.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _notifications.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _notificationListHeader(
                              ui,
                              l10n,
                              compact: compact,
                            ),
                          );
                        }

                        final notification = _notifications[index - 1];
                        final isSelected = _selectedIds.contains(
                          notification.id,
                        );

                        final card = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onLongPress: () {
                              if (!_isSelecting) {
                                HapticFeedback.mediumImpact();
                                setState(() => _isSelecting = true);
                              }
                              _toggleSelection(notification.id);
                            },
                            onTap: () {
                              if (_isSelecting) {
                                _toggleSelection(notification.id);
                              } else {
                                _openDetail(notification);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ui.cardStrong
                                    : notification.isRead
                                    ? ui.card
                                    : ui.cardMuted,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected
                                      ? ui.iconMuted.withValues(alpha: 0.28)
                                      : notification.isRead
                                      ? ui.border
                                      : ui.borderStrong.withValues(alpha: 0.72),
                                  width: isSelected ? 1.3 : 1,
                                ),
                              ),
                              child: _notificationTile(
                                context,
                                notification,
                                isSelected: isSelected,
                                ui: ui,
                              ),
                            ),
                          ),
                        );
                        if (_isSelecting) {
                          return card;
                        }
                        return Dismissible(
                          key: ValueKey('notification-${notification.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: ui.dangerSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ui.danger.withValues(alpha: 0.22),
                              ),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: ui.danger,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            context.read<NotificationController>().delete(
                              notification.id,
                            );
                            _selectedIds.remove(notification.id);
                            return true;
                          },
                          child: card,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationTile(
    BuildContext context,
    NotificationItem notification, {
    required bool isSelected,
    required OrbiUiTokens ui,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactBody = constraints.maxWidth < 300;
        final title = toCustomerFriendlyText(notification.title);
        final message = toCustomerFriendlyText(notification.message);
        final timestamp = _formatTime(notification.timestamp);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSelecting) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? ui.iconMuted
                      : ui.iconMuted.withValues(alpha: 0.45),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  size: 18,
                  color: notification.color,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compactBody ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 14.5,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isSelecting) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: ui.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ui.iconMuted.withValues(alpha: 0.76),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _notificationListHeader(
    OrbiUiTokens ui,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_none_rounded, size: 18, color: ui.iconMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sw
                  ? '${_notifications.length} arifa'
                  : '${_notifications.length} notifications',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ui.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
          if (!_isSelecting && _unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.done_all_rounded, color: ui.iconMuted, size: 17),
              label: Text(
                l10n.notificationsMarkAllRead,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ui.iconMuted,
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.notificationsJustNow;
    }
    if (diff.inMinutes < 60) {
      return l10n.notificationsMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.notificationsHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return l10n.notificationsDaysAgo(diff.inDays);
    }

    return '${time.day}/${time.month}/${time.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: OrbiStateCard(
        icon: Icons.notifications_none,
        title: l10n.notificationsEmptyTitle,
        message: l10n.notificationsEmptyMessage,
        accentColor: ui.iconMuted,
        accentBackground: ui.cardStrong,
      ),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  final String message;

  const _NotificationErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: OrbiStateCard(
        icon: Icons.notifications_off_outlined,
        title: l10n.notificationsLoadFailedTitle,
        message: message,
        accentColor: ui.danger,
        accentBackground: ui.dangerSoft,
        action: FilledButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          child: Text(l10n.actionClose),
        ),
      ),
    );
  }
}

class _NotificationsLoadingState extends StatelessWidget {
  const _NotificationsLoadingState();

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ui.cardMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ui.border),
          ),
          child: const Row(
            children: [
              OrbiShimmerBlock(width: 40, height: 40, radius: 20),
              SizedBox(width: 12),
              Expanded(child: OrbiShimmerLines(lines: [12, 10], spacing: 8)),
            ],
          ),
        );
      },
    );
  }
}

class NotificationDetailPage extends StatefulWidget {
  final NotificationItem notification;

  const NotificationDetailPage({super.key, required this.notification});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  final ServicePaymentChallengeService _challengeService =
      ServicePaymentChallengeService();
  final Map<String, String> _challengeIdempotencyKeys = <String, String>{};
  final Map<String, TextEditingController> _otcControllers =
      <String, TextEditingController>{};
  String? _respondingDecision;

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    for (final controller in _otcControllers.values) {
      controller.dispose();
    }
    _otcControllers.clear();
    super.dispose();
  }

  Future<void> _openLink(String raw) async {
    final value = raw.trim();
    final isEmail = value.contains('@');
    final isPhone = RegExp(r'^\+?\d[\d\s\-]{7,}\d$').hasMatch(value);

    Uri uri;
    if (isEmail) {
      uri = Uri(scheme: 'mailto', path: value);
    } else if (isPhone) {
      final digitsOnly = value.replaceAll(RegExp(r'[^\d+]'), '');
      uri = Uri(scheme: 'tel', path: digitsOnly);
    } else {
      return;
    }

    final launched = await launchUrl(uri);
    if (!launched || !mounted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.notificationsCouldNotOpenMessage(value),
          ),
        ),
      );
    }
  }

  List<InlineSpan> _buildMessageSpans(String message, TextStyle baseStyle) {
    final ui = OrbiTheme.uiOf(context);

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final normalized = message.replaceAll('\r\n', '\n');
    final pattern = RegExp(
      r'(\*[^*\n]+\*)|([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})|(\+?\d[\d\s\-]{7,}\d)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(normalized)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: normalized.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final token = match.group(0) ?? '';
      final isBold =
          token.startsWith('*') && token.endsWith('*') && token.length > 2;
      final isLink =
          token.contains('@') ||
          RegExp(r'^\+?\d[\d\s\-]{7,}\d$').hasMatch(token.trim());

      if (isBold) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: ui.textPrimary,
            ),
          ),
        );
      } else if (isLink) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            _openLink(token);
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: ui.accent,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }

      cursor = match.end;
    }

    if (cursor < normalized.length) {
      spans.add(TextSpan(text: normalized.substring(cursor), style: baseStyle));
    }

    return spans;
  }

  Map<String, dynamic>? _servicePaymentChallenge() {
    final metadata = widget.notification.metadata;
    final direct = metadata['servicePaymentChallenge'];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    final snake = metadata['service_payment_challenge'];
    if (snake is Map) return Map<String, dynamic>.from(snake);
    final challenge = metadata['challenge'];
    if (challenge is Map && challenge['challengeId'] != null) {
      return Map<String, dynamic>.from(challenge);
    }
    return null;
  }

  Future<void> _respondToServiceChallenge(
    Map<String, dynamic> challenge,
    String decision,
  ) async {
    final challengeId = (challenge['challengeId'] ?? challenge['challenge_id'])
        .toString()
        .trim();
    if (challengeId.isEmpty || _respondingDecision != null) return;
    final otcRequired =
        challenge['otcRequired'] == true ||
        challenge['otc_required'] == true ||
        (challenge['challengeType'] ?? challenge['type'])
                .toString()
                .toUpperCase() ==
            'OTP';
    final otcRequestId =
        (challenge['otcRequestId'] ?? challenge['otc_request_id'] ?? '')
            .toString()
            .trim();
    final otcCode = _otcControllers[challengeId]?.text.trim() ?? '';
    if (decision == 'approve' && otcRequired && otcCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weka msimbo wa OTC uliotumwa kwanza.')),
      );
      return;
    }

    setState(() => _respondingDecision = decision);
    try {
      final idempotencyKey = _challengeIdempotencyKeys.putIfAbsent(
        '$challengeId:$decision',
        () => _challengeService.createIdempotencyKey(
          'service-challenge-$decision',
        ),
      );
      final result = await _challengeService.respond(
        challengeId: challengeId,
        decision: decision,
        idempotencyKey: idempotencyKey,
        otcRequestId: otcRequestId,
        otcCode: otcCode,
      );
      if (!mounted) return;
      final approved = decision == 'approve';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Ombi limethibitishwa. ORBI inaendelea kushughulikia malipo.'
                : 'Ombi limekataliwa.',
          ),
        ),
      );
      context.read<NotificationController>().markAsRead(widget.notification.id);
      setState(() {
        _respondingDecision = null;
      });
      if ((result['status'] ?? '').toString().toLowerCase() !=
          'requires_action') {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _respondingDecision = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toCustomerFriendlyText(error.toString()))),
      );
    }
  }

  Widget _buildServicePaymentChallengeCard(Map<String, dynamic> challenge) {
    final ui = OrbiTheme.uiOf(context);
    final amount = (challenge['amount'] ?? '').toString().trim();
    final currency = (challenge['currency'] ?? '').toString().trim();
    final reference = (challenge['reference'] ?? '').toString().trim();
    final serviceName =
        (challenge['merchantName'] ??
                challenge['serviceName'] ??
                challenge['serviceCode'] ??
                'ORBI service')
            .toString()
            .trim();
    final expiresAt = (challenge['expiresAt'] ?? '').toString().trim();
    final challengeId = (challenge['challengeId'] ?? challenge['challenge_id'])
        .toString()
        .trim();
    final otcRequired =
        challenge['otcRequired'] == true ||
        challenge['otc_required'] == true ||
        (challenge['challengeType'] ?? challenge['type'])
                .toString()
                .toUpperCase() ==
            'OTP';
    final otcDelivery =
        (challenge['otcDeliveryType'] ??
                challenge['otc_delivery_type'] ??
                challenge['deliveryType'] ??
                '')
            .toString()
            .trim();
    final otcController = _otcControllers.putIfAbsent(
      challengeId,
      TextEditingController.new,
    );
    final amountLabel = amount.isEmpty
        ? ''
        : '${currency.isEmpty ? 'TZS' : currency.toUpperCase()} $amount';
    final approving = _respondingDecision == 'approve';
    final rejecting = _respondingDecision == 'reject';
    final busy = _respondingDecision != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ui.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.verified_user_outlined, color: ui.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ombi la malipo',
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (amountLabel.isNotEmpty)
                      Text(
                        amountLabel,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Thibitisha kama unaruhusu $serviceName kuendelea na ombi hili.',
            style: TextStyle(color: ui.textMuted, height: 1.35),
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ref: $reference',
              style: TextStyle(color: ui.textSoft, fontWeight: FontWeight.w700),
            ),
          ],
          if (expiresAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Muda wa ombi unaisha: $expiresAt',
              style: TextStyle(color: ui.textSoft, fontSize: 12),
            ),
          ],
          if (otcRequired) ...[
            const SizedBox(height: 14),
            TextField(
              controller: otcController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Msimbo wa OTC',
                hintText: 'Weka tarakimu 6',
                helperText: otcDelivery.isEmpty
                    ? 'Umetumwa kwenye mawasiliano yako ya ORBI.'
                    : 'Umetumwa kupitia $otcDelivery.',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _respondToServiceChallenge(challenge, 'approve'),
                  icon: approving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Thibitisha'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _respondToServiceChallenge(challenge, 'reject'),
                  icon: rejecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close),
                  label: const Text('Kataa'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().markAsRead(widget.notification.id);
    });

    final ui = OrbiTheme.uiOf(context);
    final spans = _buildMessageSpans(
      toCustomerFriendlyText(widget.notification.message),
      TextStyle(color: ui.textMuted, fontSize: 16, height: 1.5),
    );
    final servicePaymentChallenge = _servicePaymentChallenge();

    return Scaffold(
      backgroundColor: ui.sheet,
      appBar: AppBar(
        backgroundColor: ui.appBarMid.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        title: Text(AppLocalizations.of(context)!.notificationsDetailsTitle),
      ),
      body: SafeArea(
        top: false,
        child: OrbiBackground(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: OrbiResponsiveContent(
              padding: OrbiResponsive.pagePadding(context, top: 20, bottom: 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ui.borderStrong),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toCustomerFriendlyText(widget.notification.title),
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFullTime(widget.notification),
                      style: TextStyle(color: ui.textSoft),
                    ),
                    Divider(height: 32, color: ui.border),
                    RichText(text: TextSpan(children: spans)),
                    if (servicePaymentChallenge != null)
                      _buildServicePaymentChallengeCard(
                        servicePaymentChallenge,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatFullTime(NotificationItem notification) {
    final auditTime = notification.metadata['audit_time'];
    if (auditTime is Map) {
      final dateTime = auditTime['display_date_time']?.toString().trim();
      if (dateTime != null && dateTime.isNotEmpty) return dateTime;
      final display = auditTime['display_timestamp']?.toString().trim();
      if (display != null && display.isNotEmpty) return display;
    }
    final time = notification.timestamp;
    return AppLocalizations.of(context)!.notificationsFullTime(
      '${time.day}/${time.month}/${time.year}',
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
    );
  }
}
