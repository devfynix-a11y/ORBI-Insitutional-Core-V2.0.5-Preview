import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'notifications_screen.dart';
import '../state/notification_controller.dart';

/// Lightweight prompt that appears over any screen.
/// Reuses NotificationItem list logic from NotificationsScreen.
class NotificationsPrompt extends StatefulWidget {
  const NotificationsPrompt({super.key});

  @override
  State<NotificationsPrompt> createState() => _NotificationsPromptState();
}

class _NotificationsPromptState extends State<NotificationsPrompt> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final notifications = controller.items;
    final unread = controller.unreadCount;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ui = OrbiTheme.uiOf(context);
    final visibleNotifications = notifications.take(4).toList();
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeVertical = mediaQuery.padding.top + mediaQuery.padding.bottom;
    final compact = screenWidth < 380;
    final short = screenHeight < 740;
    final cardWidth = screenWidth < 420 ? screenWidth - 24 : 380.0;
    final maxCardHeight = (screenHeight - safeVertical - 24).clamp(
      short ? 230.0 : 250.0,
      short ? 300.0 : 340.0,
    );

    return Material(
      color: Colors.black.withValues(alpha: 0.14),
      child: Align(
        alignment: Alignment.topRight,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            width: cardWidth.clamp(0, 380),
            constraints: BoxConstraints(
              maxWidth: 380,
              maxHeight: maxCardHeight,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ui.card.withValues(alpha: 0.985),
                  ui.cardStrong.withValues(alpha: 0.98),
                  ui.sheet.withValues(alpha: 0.975),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ui.borderStrong.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                short ? 12 : 14,
                14,
                short ? 10 : 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: compact ? 32 : 34,
                        height: compact ? 32 : 34,
                        decoration: BoxDecoration(
                          color: ui.cardStrong.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ui.borderStrong.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: compact ? 17 : 18,
                          color: ui.iconMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ui.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              unread > 0
                                  ? '$unread unread'
                                  : 'Up to date',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ui.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        icon: Icon(Icons.close_rounded, color: ui.iconMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: short ? 8 : 10),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: ui.card.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ui.borderStrong.withValues(alpha: 0.74),
                        ),
                      ),
                      child: controller.isLoading
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: colors.secondary,
                                ),
                              ),
                            )
                          : controller.error != null
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                controller.error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.error,
                                ),
                              ),
                            )
                          : visibleNotifications.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    color: ui.iconMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No notifications',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: ui.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: visibleNotifications.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (context, index) {
                                final n = visibleNotifications[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  child: _promptNotificationCard(
                                    context,
                                    n,
                                    compact: compact || short,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  SizedBox(height: short ? 8 : 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0)
                        TextButton(
                          onPressed: controller.markAllAsRead,
                          child: Text(
                            'Mark read',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ui.iconMuted),
                          ),
                        ),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View all',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ui.textMuted),
                          ),
                        ),
                      ),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }

  Widget _promptNotificationCard(
    BuildContext context,
    NotificationItem notification, {
    required bool compact,
  }) {
    final controller = context.read<NotificationController>();
    final theme = Theme.of(context);
    final ui = OrbiTheme.uiOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        controller.markAsRead(notification.id);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 9 : 10,
          compact ? 10 : 12,
          compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: ui.cardMuted.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? ui.border.withValues(alpha: 0.78)
                : ui.borderStrong.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      notification.icon,
                      size: compact ? 15 : 17,
                      color: notification.color,
                    ),
                  ),
                  if (!notification.isRead)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: ui.iconMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          toCustomerFriendlyText(notification.title),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ui.textPrimary,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _formatTime(notification.timestamp),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ui.textSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toCustomerFriendlyText(notification.message),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ui.textMuted,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => controller.delete(notification.id),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ui.iconMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
