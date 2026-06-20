import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/orbi_theme.dart';

class AdvancedHubSheet extends StatelessWidget {
  const AdvancedHubSheet({
    super.key,
    required this.onSend,
    required this.onTransfer,
    required this.onRequest,
    required this.onScanPay,
    required this.onPaySafe,
    required this.onSharedPot,
    required this.onSharedBudget,
    required this.onBillReserve,
    required this.onAllocationRules,
    required this.onLinkExternalWallet,
    this.onCurrencyExchange,
    this.onAgentDesk,
    this.onMerchantDesk,
  });

  final VoidCallback onSend;
  final VoidCallback onTransfer;
  final VoidCallback onRequest;
  final VoidCallback onScanPay;
  final VoidCallback onPaySafe;
  final VoidCallback onSharedPot;
  final VoidCallback onSharedBudget;
  final VoidCallback onBillReserve;
  final VoidCallback onAllocationRules;
  final VoidCallback onLinkExternalWallet;
  final VoidCallback? onCurrencyExchange;
  final VoidCallback? onAgentDesk;
  final VoidCallback? onMerchantDesk;

  String _t(BuildContext context, String en, String sw) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'sw'
        ? sw
        : en;
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    final sections = <_HubSection>[
      _HubSection(
        title: _t(context, 'Payments', 'Malipo'),
        accent: const Color(0xFF16A34A),
        items: [
          _HubItem(
            icon: Icons.public_rounded,
            label: _t(context, 'Transfer', 'Transfer'),
            color: const Color(0xFF16A34A),
            onTap: onTransfer,
            assetPath: 'assets/icons/transfer.svg',
          ),
          _HubItem(
            icon: Icons.front_hand_rounded,
            label: _t(context, 'Request Funds', 'Omba fedha'),
            color: const Color(0xFF2D7FF9),
            onTap: onRequest,
            assetPath: 'assets/icons/request funds.svg',
          ),
          if (onCurrencyExchange != null)
            _HubItem(
              icon: Icons.currency_exchange_outlined,
              label: _t(context, 'FX Exchange', 'FX Exchange'),
              color: const Color(0xFFF59E0B),
              onTap: onCurrencyExchange!,
            ),
        ],
      ),
      _HubSection(
        title: _t(context, 'Protect', 'Ulinzi'),
        accent: const Color(0xFF8B5CF6),
        items: [
          _HubItem(
            icon: Icons.lock_clock_outlined,
            label: _t(context, 'PaySafe', 'PaySafe'),
            color: const Color(0xFF8B5CF6),
            onTap: onPaySafe,
            assetPath: 'assets/icons/paysafe.svg',
          ),
          _HubItem(
            icon: Icons.receipt_long_outlined,
            label: _t(context, 'Bill Reserve', 'Bill Reserve'),
            color: const Color(0xFFE85D75),
            onTap: onBillReserve,
            assetPath: 'assets/icons/bill reserve.svg',
          ),
        ],
      ),
      _HubSection(
        title: _t(context, 'Shared', 'Ushirika'),
        accent: const Color(0xFF2563EB),
        items: [
          _HubItem(
            icon: Icons.groups_2_outlined,
            label: _t(context, 'Shared Pot', 'Shared Pot'),
            color: const Color(0xFF0EA5A4),
            onTap: onSharedPot,
            assetPath: 'assets/icons/shared pot.svg',
          ),
          _HubItem(
            icon: Icons.account_tree_outlined,
            label: _t(context, 'Shared Budget', 'Shared Budget'),
            color: const Color(0xFF2563EB),
            onTap: onSharedBudget,
            assetPath: 'assets/icons/shared budget.svg',
          ),
        ],
      ),
      _HubSection(
        title: _t(context, 'Connect', 'Unganisha'),
        accent: const Color(0xFF14B8A6),
        items: [
          _HubItem(
            icon: Icons.rule_folder_outlined,
            label: _t(context, 'Money Rules', 'Kanuni za fedha'),
            color: const Color(0xFF7C3AED),
            onTap: onAllocationRules,
          ),
          _HubItem(
            icon: Icons.link_rounded,
            label: _t(context, 'Link Wallet', 'Link Wallet'),
            color: const Color(0xFF14B8A6),
            onTap: onLinkExternalWallet,
            assetPath: 'assets/icons/link wallet.svg',
          ),
          if (onAgentDesk != null)
            _HubItem(
              icon: Icons.storefront_outlined,
              label: _t(context, 'Agent Desk', 'Dawati la wakala'),
              color: const Color(0xFFF97316),
              onTap: onAgentDesk!,
            ),
          if (onMerchantDesk != null)
            _HubItem(
              icon: Icons.point_of_sale_outlined,
              label: _t(context, 'Merchant Desk', 'Dawati la merchant'),
              color: const Color(0xFFDC2626),
              onTap: onMerchantDesk!,
            ),
        ],
      ),
    ];

    return SafeArea(
      top: false,
      child: Material(
        color: ui.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ui.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _t(context, 'Premium Services', 'Huduma Zilizo Boreshwa'),
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        _SectionBlock(section: sections[i]),
                        if (i != sections.length - 1)
                          const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubSection {
  const _HubSection({
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<_HubItem> items;
  final Color accent;
}

class _HubItem {
  const _HubItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.assetPath,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? assetPath;
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final _HubSection section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 760
            ? 4
            : width >= 520
            ? 4
            : width >= 360
            ? 3
            : width >= 280
            ? 2
            : 1;
        const spacing = 8.0;
        final availableWidth =
            (width - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
        final itemWidth = availableWidth.clamp(78.0, 92.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: TextStyle(
                color: section.accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.25,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: spacing,
              runSpacing: 14,
              children: [
                for (final item in section.items)
                  SizedBox(
                    width: itemWidth,
                    child: _MenuGridTile(item: item),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MenuGridTile extends StatelessWidget {
  const _MenuGridTile({required this.item});

  final _HubItem item;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: item.color.withValues(alpha: 0.10),
        highlightColor: item.color.withValues(alpha: 0.05),
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.color.withValues(alpha: 0.16),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    item.color.withValues(alpha: 0.05),
                    ui.card.withValues(alpha: 0.60),
                  ),
                  Color.alphaBlend(
                    item.color.withValues(alpha: 0.025),
                    ui.cardMuted.withValues(alpha: 0.24),
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: item.assetPath == null
                      ? Icon(item.icon, color: item.color, size: 21)
                      : Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(
                            item.assetPath!,
                            colorFilter: ColorFilter.mode(
                              item.color,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
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
