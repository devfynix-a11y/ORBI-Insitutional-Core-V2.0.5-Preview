import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/state/app_settings_controller.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/widgets/orbi_background.dart';
import 'auth_flow_content.dart';

class AuthOnboardingScreen extends StatefulWidget {
  const AuthOnboardingScreen({super.key});

  @override
  State<AuthOnboardingScreen> createState() => _AuthOnboardingScreenState();
}

class _AuthOnboardingScreenState extends State<AuthOnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  bool get _isLastPage => _pageIndex == 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeFlowAndOpenSignup() async {
    await context.read<AppSettingsController>().completeWelcomeFlow();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _completeFlowAndOpenLogin() async {
    await context.read<AppSettingsController>().completeWelcomeFlow();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _goNext() {
    if (_isLastPage) {
      _completeFlowAndOpenSignup();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final surfaces = OrbiTheme.surfacesOf(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: OrbiBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SizedBox(
                  height:
                      MediaQuery.of(context).size.height.clamp(620.0, 860.0) -
                      70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ui.card.withValues(alpha: 0.96),
                          ui.cardMuted.withValues(alpha: 0.98),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: ui.border),
                      boxShadow: [
                        BoxShadow(
                          color: surfaces.overlay.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: ui.iconMuted.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.shield_rounded,
                                  color: ui.iconMuted,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.onboardingWelcomeTitle,
                                      style: GoogleFonts.michroma(
                                        fontSize: 18,
                                        color: ui.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.onboardingWelcomeSubtitle,
                                      style: TextStyle(
                                        color: ui.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Badge(
                                backgroundColor: ui.warningSoft,
                                label: Text(
                                  '${_pageIndex + 1}/2',
                                  style: TextStyle(
                                    color: ui.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (value) {
                                setState(() => _pageIndex = value);
                              },
                              children: const [_PromoPage(), _TermsPage()],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              2,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width: _pageIndex == index ? 26 : 8,
                                decoration: BoxDecoration(
                                  color: _pageIndex == index
                                      ? ui.iconMuted
                                      : ui.borderStrong,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pageIndex == 0
                                      ? _completeFlowAndOpenLogin
                                      : () {
                                          _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 260,
                                            ),
                                            curve: Curves.easeOutCubic,
                                          );
                                        },
                                  icon: Icon(
                                    _pageIndex == 0
                                        ? Icons.login_rounded
                                        : Icons.arrow_back_rounded,
                                  ),
                                  label: Text(
                                    _pageIndex == 0
                                        ? l10n.signupSignInButton
                                        : l10n.actionBack,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _goNext,
                                  icon: Icon(
                                    _isLastPage
                                        ? Icons.app_registration_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                                  label: Text(
                                    _isLastPage
                                        ? l10n.actionCreateAccount
                                        : l10n.actionNext,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoPage extends StatelessWidget {
  const _PromoPage();

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final promoCards = buildOrbiPromoCards(l10n);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ui.iconMuted.withValues(alpha: 0.12),
                  ui.cardStrong,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ui.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PromoBadge(
                      icon: Icons.bolt_rounded,
                      label: l10n.onboardingBadgeFast,
                    ),
                    _PromoBadge(
                      icon: Icons.public_rounded,
                      label: l10n.onboardingBadgeEveryday,
                    ),
                    _PromoBadge(
                      icon: Icons.verified_user_rounded,
                      label: l10n.onboardingBadgeSecure,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.onboardingHeroTitle,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.onboardingHeroSubtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...promoCards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ui.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: ui.iconMuted.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.stars_rounded, color: ui.iconMuted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Badge(
                            backgroundColor: ui.successSoft,
                            label: Text(
                              card['badge'] ?? '',
                              style: TextStyle(
                                color: ui.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            card['title'] ?? '',
                            style: TextStyle(
                              color: ui.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card['body'] ?? '',
                            style: TextStyle(
                              color: ui.textMuted,
                              fontSize: 13,
                              height: 1.45,
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
        ],
      ),
    );
  }
}

class _TermsPage extends StatelessWidget {
  const _TermsPage();

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final l10n = AppLocalizations.of(context)!;
    final termsHighlights = buildOrbiTermsHighlights(l10n);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ui.cardStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ui.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: ui.warningSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.gavel_rounded, color: ui.warning),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.onboardingTermsTitle,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.onboardingTermsSubtitle,
                        style: TextStyle(
                          color: ui.textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...termsHighlights.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ui.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ui.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: ui.iconMuted.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: ui.iconMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ui.successSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.fact_check_rounded, color: ui.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.onboardingTermsConfirm,
                    style: TextStyle(
                      color: ui.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
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

class _PromoBadge extends StatelessWidget {
  const _PromoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ui.iconMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
