import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_theme.dart';

class InviteeLookupCard extends StatelessWidget {
  const InviteeLookupCard({
    super.key,
    required this.data,
    required this.accent,
    required this.isSw,
  });

  final Map<String, dynamic> data;
  final Color accent;
  final bool isSw;

  String _pick(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final name = _pick([
      data['display_name'],
      data['full_name'],
      data['fullName'],
      data['name'],
      isSw ? 'Mtumiaji wa ORBI' : 'ORBI user',
    ]);
    final identifier = _pick([
      data['customer_id'],
      data['customerId'],
      data['recipient_id'],
      data['recipientId'],
      data['email'],
      data['phone'],
    ]);
    final contact = _pick([data['email'], data['phone']]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          ui.cardMuted.withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.verified_user_rounded, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  identifier.isEmpty
                      ? (isSw ? 'Akaunti imethibitishwa' : 'Account verified')
                      : identifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                if (contact.isNotEmpty && contact != identifier) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ui.textSoft, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: accent, size: 19),
        ],
      ),
    );
  }
}
