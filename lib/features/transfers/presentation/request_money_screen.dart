import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_feature_card.dart';
import '../../../core/widgets/service_asset_icon.dart';
import '../../auth/state/auth_controller.dart';

class RequestMoneyScreen extends StatefulWidget {
  const RequestMoneyScreen({super.key});

  @override
  State<RequestMoneyScreen> createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends State<RequestMoneyScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String get _currencyCode {
    final raw = context.read<AuthController>().session;
    return resolveCurrencyCode([
      raw['currency'],
      raw['currency_code'],
      raw['user']?['currency'],
      raw['user']?['currency_code'],
      raw['user']?['preferred_currency'],
      'TZS',
    ]);
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  Color get _accent => const Color(0xFF0E8C8F);

  @override
  void dispose() {
    _fromController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _createRequest() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSw
              ? 'Ombi bado halijaunganishwa moja kwa moja na backend.'
              : 'Request flow is not live on the backend yet.',
        ),
      ),
    );
  }

  Widget _stepHeader(String step, String title) {
    final ui = OrbiTheme.uiOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withValues(alpha: 0.18)),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: TextStyle(
                color: _accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.requestMoneyTitle),
      ),
      body: OrbiBackground(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(_accent, ui.card, 0.94) ?? ui.card,
                        ui.cardStrong,
                        ui.card,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _accent.withValues(alpha: 0.16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ServiceAssetIcon(
                        assetPath: 'assets/icons/request funds.svg',
                        color: _accent,
                        size: 20,
                        background: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context)!.requestMoneyTitle,
                        style: TextStyle(
                          color: ui.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSw
                            ? 'Omba fedha kwa hatua chache.'
                            : 'Request money in a few steps.',
                        style: TextStyle(color: ui.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ui.cardStrong.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ui.borderStrong.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: ui.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isSw ? 'Inakuja.' : 'Coming soon.',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OrbiFeatureCard(
                  title: _isSw ? 'Muombaji' : 'Requester',
                  subtitle: _isSw ? 'Mlipaji' : 'Payer',
                  icon: Icons.person_search_outlined,
                  accentColor: _accent,
                  child: Column(
                    children: [
                      _stepHeader('1', _isSw ? 'Toka kwa nani' : 'From who'),
                      TextFormField(
                        controller: _fromController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.requestMoneyFromLabel,
                          hintText: AppLocalizations.of(
                            context,
                          )!.requestMoneyFromHint,
                          prefixIcon: const Icon(Icons.person_search_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(
                              context,
                            )!.requestMoneyValidatorFrom;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OrbiFeatureCard(
                  title: _isSw ? 'Kiasi' : 'Amount',
                  subtitle: _isSw ? 'Unachoomba' : 'Requested',
                  icon: Icons.request_quote_outlined,
                  accentColor: _accent,
                  child: Column(
                    children: [
                      _stepHeader('2', _isSw ? 'Kiasi' : 'Amount'),
                      OrbiAmountField(
                        controller: _amountController,
                        inputFormatters: [AmountInputFormatter()],
                        label: AppLocalizations.of(
                          context,
                        )!.requestMoneyAmountLabel,
                        hint: AppLocalizations.of(
                          context,
                        )!.requestMoneyAmountHint,
                        currency: resolveCurrencyDisplaySymbol(_currencyCode),
                        validator: (value) {
                          final parsed = AmountInputFormatter.tryParse(
                            value ?? '',
                          );
                          if (parsed == null || parsed <= 0) {
                            return AppLocalizations.of(
                              context,
                            )!.requestMoneyValidatorAmount;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OrbiFeatureCard(
                  title: _isSw ? 'Sababu' : 'Reason',
                  subtitle: _isSw ? 'Hiari' : 'Optional',
                  icon: Icons.notes_outlined,
                  accentColor: _accent,
                  child: Column(
                    children: [
                      _stepHeader('3', _isSw ? 'Sababu' : 'Reason'),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.requestMoneyReasonLabel,
                          hintText: AppLocalizations.of(
                            context,
                          )!.requestMoneyReasonHint,
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 48),
                            child: Icon(Icons.description_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _createRequest,
                    icon: const Icon(Icons.request_page_outlined),
                    label: Text(
                      AppLocalizations.of(context)!.actionCreateRequest,
                    ),
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
