import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_logo.dart';
import '../../../core/widgets/orbi_responsive.dart';

class AboutOrbiScreen extends StatelessWidget {
  const AboutOrbiScreen({super.key});

  bool _isSwahili(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  Widget build(BuildContext context) {
    final sw = _isSwahili(context);
    final ui = OrbiTheme.uiOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(sw ? 'Kuhusu ORBI' : 'About ORBI'),
        centerTitle: false,
      ),
      body: OrbiBackground(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: OrbiResponsiveContent(
            padding: OrbiResponsive.pagePadding(context, top: 14, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutHero(sw: sw),
                const SizedBox(height: 22),
                _SectionHeading(
                  eyebrow: sw ? 'JUKWAA MOJA' : 'ONE PLATFORM',
                  title: sw ? 'Huduma za ORBI' : 'What ORBI offers',
                  message: sw
                      ? 'Zana za kila siku za kusimamia fedha, kufanya malipo, kupanga malengo na kushirikiana kwa uwazi.'
                      : 'Everyday tools for managing money, making payments, planning goals, and collaborating with clarity.',
                ),
                const SizedBox(height: 14),
                _ServicesGrid(sw: sw),
                const SizedBox(height: 24),
                _SectionHeading(
                  eyebrow: sw ? 'MFUMO WA ORBI' : 'THE ORBI ECOSYSTEM',
                  title: sw ? 'Zaidi ya huduma za fedha' : 'More than finance',
                  message: sw
                      ? 'ORBI huunganisha huduma za fedha na bidhaa maalum zinazotatua changamoto halisi za biashara na maisha ya kila siku.'
                      : 'ORBI connects financial services with focused products that solve real commerce and everyday-life challenges.',
                ),
                const SizedBox(height: 14),
                _OrbiShopPanel(sw: sw),
                const SizedBox(height: 24),
                _TrustPanel(sw: sw),
                const SizedBox(height: 24),
                _SectionHeading(
                  eyebrow: sw ? 'IMEJENGWA KWA AJILI YAKO' : 'BUILT AROUND YOU',
                  title: sw
                      ? 'Fedha zinazoeleweka kwa urahisi'
                      : 'Finance that stays understandable',
                  message: sw
                      ? 'ORBI inaleta salio, mwenendo, mipango na hatua muhimu sehemu moja ili uweze kufanya maamuzi kwa ujasiri.'
                      : 'ORBI brings balances, trends, plans, and important actions together so you can make confident decisions.',
                ),
                const SizedBox(height: 14),
                _AudienceRail(sw: sw),
                const SizedBox(height: 24),
                _AvailabilityNote(sw: sw),
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      OrbiLogoV2(width: 108, color: ui.textPrimary),
                      const SizedBox(height: 8),
                      Text(
                        sw
                            ? 'Teknolojia ya fedha yenye udhibiti, uwazi na ukuaji.'
                            : 'Financial technology for control, clarity, and growth.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sw ? 'Toleo 1.0.0+1' : 'Version 1.0.0+1',
                        style: TextStyle(
                          color: ui.textSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.sw});

  final bool sw;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = OrbiTheme.uiOf(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 278),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF123A49), Color(0xFF0D2834), Color(0xFF081A24)]
              : const [Color(0xFF167DA0), Color(0xFF2596BE), Color(0xFF48B8CC)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: _AboutArtwork())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrbiLogoV2(width: 138, color: Colors.white),
              const SizedBox(height: 22),
              Text(
                sw
                    ? 'Mfumo wako wa fedha wa kila siku.'
                    : 'Your everyday financial operating system.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sw
                    ? 'ORBI imeundwa kukupa mwonekano wazi wa fedha zako, njia rahisi za kufanya miamala, na zana za kupanga maisha yako ya kifedha.'
                    : 'ORBI is designed to give you a clear view of your money, simple ways to transact, and practical tools for planning your financial life.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.visibility_outlined,
                    label: sw ? 'Uwazi' : 'Clarity',
                  ),
                  _HeroChip(
                    icon: Icons.shield_outlined,
                    label: sw ? 'Ulinzi' : 'Protection',
                  ),
                  _HeroChip(
                    icon: Icons.insights_outlined,
                    label: sw ? 'Ukuaji' : 'Growth',
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Icon(
              Icons.blur_circular_rounded,
              size: 84,
              color: ui.accent.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: ui.accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 22,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          style: TextStyle(
            color: ui.textMuted,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.sw});

  final bool sw;

  @override
  Widget build(BuildContext context) {
    final services = [
      _ServiceInfo(
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF168AA8),
        title: sw ? 'Wallet na utajiri' : 'Wallets and wealth',
        message: sw
            ? 'Ona salio, panga fedha, unganisha walleti na fuatilia mwenendo wako.'
            : 'See balances, organize funds, link wallets, and follow your financial direction.',
      ),
      _ServiceInfo(
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF2F79D0),
        title: sw ? 'Kutuma na kupokea' : 'Send and receive',
        message: sw
            ? 'Tuma, omba na hamisha fedha kwa hatua zilizo wazi kabla ya kuthibitisha.'
            : 'Send, request, and move money with clear steps before confirmation.',
      ),
      _ServiceInfo(
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF7357D9),
        title: sw ? 'Malipo' : 'Payments',
        message: sw
            ? 'Lipa huduma na wafanyabiashara kupitia njia zilizoidhinishwa zinazopatikana.'
            : 'Pay services and merchants through available approved payment routes.',
      ),
      _ServiceInfo(
        icon: Icons.flag_outlined,
        color: const Color(0xFFE57C3C),
        title: sw ? 'Malengo na bajeti' : 'Goals and budgets',
        message: sw
            ? 'Tengeneza malengo, bajeti na akiba ili kila kiasi kiwe na kusudi.'
            : 'Create goals, budgets, and reserves so every amount can have a purpose.',
      ),
      _ServiceInfo(
        icon: Icons.groups_2_outlined,
        color: const Color(0xFF0E9F8D),
        title: sw ? 'Fedha za pamoja' : 'Shared finance',
        message: sw
            ? 'Shirikiana kupitia shared pots na shared budgets zenye majukumu yaliyo wazi.'
            : 'Collaborate through shared pots and budgets with clear member roles.',
      ),
      _ServiceInfo(
        icon: Icons.lock_clock_outlined,
        color: const Color(0xFFD85C78),
        title: 'ORBI PaySafe',
        message: sw
            ? 'Tumia mtiririko wa malipo wenye ulinzi na hatua za uthibitishaji pale inapohitajika.'
            : 'Use protected payment flows with verification steps when required.',
      ),
      _ServiceInfo(
        icon: Icons.auto_awesome_outlined,
        color: const Color(0xFF3296BE),
        title: sw ? 'Maarifa ya fedha' : 'Financial insights',
        message: sw
            ? 'Pata mwenendo, arifa na muhtasari unaokusaidia kuelewa fedha zako.'
            : 'Get trends, alerts, and summaries that help you understand your money.',
      ),
      _ServiceInfo(
        icon: Icons.storefront_outlined,
        color: const Color(0xFFB66A2D),
        title: sw ? 'Merchant na agent' : 'Merchant and agent tools',
        message: sw
            ? 'Akaunti zilizoidhinishwa zinaweza kupata zana maalum za biashara na huduma.'
            : 'Approved accounts can access dedicated business and service tools.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: services
              .map(
                (service) => SizedBox(
                  width: width,
                  child: _ServiceCard(service: service),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final _ServiceInfo service;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 174),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? ui.cardStrong : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? Border.all(color: ui.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: service.color.withValues(alpha: isDark ? 0.16 : 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(service.icon, color: service.color, size: 22),
          ),
          const SizedBox(height: 13),
          Text(
            service.title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 14,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            service.message,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceInfo {
  const _ServiceInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.sw});

  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        Icons.fact_check_outlined,
        sw ? 'Hatua zilizo wazi' : 'Clear confirmations',
        sw
            ? 'Maelezo muhimu huonyeshwa kabla ya hatua za kifedha kukamilika.'
            : 'Important details are shown before financial actions are completed.',
      ),
      (
        Icons.shield_outlined,
        sw ? 'Ulinzi wa akaunti' : 'Account protection',
        sw
            ? 'Uthibitishaji, session lock na ufuatiliaji wa hatari hulinda matumizi ya akaunti.'
            : 'Verification, session locking, and risk checks help protect account access.',
      ),
      (
        Icons.receipt_long_outlined,
        sw ? 'Historia inayoeleweka' : 'Understandable history',
        sw
            ? 'Miamala na matukio muhimu yanawekwa kwa ufuatiliaji na usaidizi.'
            : 'Transactions and important events are recorded for review and support.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102A35) : const Color(0xFFF0F7FA),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ui.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_user_outlined, color: ui.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sw ? 'Imejengwa kwa uaminifu' : 'Built around trust',
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1, color: ui.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: ui.textMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

class _OrbiShopPanel extends StatelessWidget {
  const _OrbiShopPanel({required this.sw});

  final bool sw;

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF173542), Color(0xFF10242F)]
              : const [Color(0xFFFFF1E8), Color(0xFFFFFAF6)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE57C3C).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFFE57C3C),
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORBI Shop',
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      sw
                          ? 'Nunua kwa amani. Uza kwa ujasiri.'
                          : 'Buy with confidence. Sell with clarity.',
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE57C3C).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sw ? 'Biashara salama' : 'Safer commerce',
                  style: const TextStyle(
                    color: Color(0xFFB65825),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            sw
                ? 'ORBI Shop ni bidhaa ya ORBI inayolenga kuleta mazingira ya biashara mtandaoni yenye uwazi kwa wanunuzi na wauzaji. Malipo yanayostahili ulinzi yanapaswa kuanzishwa na kukamilishwa ndani ya mfumo ili kumbukumbu, uthibitishaji na mchakato wa utatuzi viweze kutumika.'
                : 'ORBI Shop is an ORBI product focused on clearer online commerce for buyers and sellers. Payments that require platform protection should be initiated and completed inside the system so records, verification, and resolution processes can apply.',
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _ShopFlowStep(
            number: '1',
            title: sw ? 'Chagua muuzaji' : 'Choose a seller',
            message: sw
                ? 'Kagua taarifa za muuzaji na alama ya uthibitishaji inapopatikana.'
                : 'Review seller information and verification status where available.',
          ),
          _ShopFlowStep(
            number: '2',
            title: sw ? 'Lipa ndani ya ORBI' : 'Pay inside ORBI',
            message: sw
                ? 'Tumia checkout rasmi; usitume fedha moja kwa moja kwenye namba binafsi.'
                : 'Use the official checkout; do not send money directly to personal numbers.',
          ),
          _ShopFlowStep(
            number: '3',
            title: sw ? 'Pokea na kagua' : 'Receive and review',
            message: sw
                ? 'Fuata hatua za oda na uthibitisho wa kupokea kabla ya mchakato kukamilika.'
                : 'Follow the order and receipt-confirmation steps before the process completes.',
            isLast: true,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SafetyColumn(
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF169B72),
                  title: sw ? 'Fanya' : 'Do',
                  message: sw
                      ? 'Lipa na zungumza ndani ya ORBI; ripoti ombi la malipo ya nje.'
                      : 'Pay and communicate inside ORBI; report requests for off-platform payment.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SafetyColumn(
                  icon: Icons.block_rounded,
                  color: const Color(0xFFD14C5A),
                  title: sw ? 'Epuka' : 'Avoid',
                  message: sw
                      ? 'Usilipe kwa namba binafsi wala kuhamisha mazungumzo kabla ya oda.'
                      : 'Avoid personal-number payments or moving conversations before an order.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ContactAction(
                icon: Icons.language_rounded,
                label: 'shop.orbifinancial.com',
                onTap: () => _open(Uri.parse('https://shop.orbifinancial.com')),
              ),
              _ContactAction(
                icon: Icons.email_outlined,
                label: 'shop@orbifinancial.com',
                onTap: () => _open(
                  Uri(scheme: 'mailto', path: 'shop@orbifinancial.com'),
                ),
              ),
              _ContactAction(
                icon: Icons.call_outlined,
                label: '+255 764 258 114',
                onTap: () => _open(Uri(scheme: 'tel', path: '+255764258114')),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 17, color: ui.textSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sw
                      ? 'Kariakoo, Alikoma na Magira Street, Dar es Salaam, Tanzania'
                      : 'Kariakoo, Alikoma and Magira Street, Dar es Salaam, Tanzania',
                  style: TextStyle(
                    color: ui.textSoft,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopFlowStep extends StatelessWidget {
  const _ShopFlowStep({
    required this.number,
    required this.title,
    required this.message,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String message;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE57C3C),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFFE57C3C).withValues(alpha: 0.20),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

class _SafetyColumn extends StatelessWidget {
  const _SafetyColumn({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 10.7,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: ui.card.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: ui.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: ui.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudienceRail extends StatelessWidget {
  const _AudienceRail({required this.sw});

  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final audiences = [
      (
        Icons.person_outline_rounded,
        sw ? 'Watu binafsi' : 'Individuals',
        sw ? 'Fedha za kila siku' : 'Everyday money',
      ),
      (
        Icons.family_restroom_rounded,
        sw ? 'Familia na timu' : 'Families and teams',
        sw ? 'Mipango ya pamoja' : 'Shared plans',
      ),
      (
        Icons.storefront_outlined,
        sw ? 'Wafanyabiashara' : 'Merchants',
        sw ? 'Zana za biashara' : 'Business tools',
      ),
      (
        Icons.support_agent_rounded,
        sw ? 'Mawakala' : 'Agents',
        sw ? 'Huduma zilizoidhinishwa' : 'Approved services',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: audiences
            .map(
              (item) => Container(
                width: 152,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ui.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$1, color: ui.accent, size: 24),
                    const SizedBox(height: 12),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: ui.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AvailabilityNote extends StatelessWidget {
  const _AvailabilityNote({required this.sw});

  final bool sw;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: ui.accent, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              sw
                  ? 'Baadhi ya huduma, njia za malipo na zana za merchant au agent huonekana kulingana na nchi, aina ya akaunti, uthibitishaji na watoa huduma waliowezeshwa.'
                  : 'Some services, payment routes, and merchant or agent tools appear based on country, account type, verification, and enabled providers.',
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutArtwork extends StatelessWidget {
  const _AboutArtwork();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AboutArtworkPainter());
  }
}

class _AboutArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final orbit = Rect.fromCircle(
      center: Offset(size.width * 0.88, size.height * 0.24),
      radius: size.width * 0.31,
    );
    canvas.drawArc(orbit, 2.2, 4.7, false, linePaint);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.73),
      size.width * 0.25,
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.90, size.height * 0.16),
      3.2,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.60),
      2.4,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
