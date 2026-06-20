import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/utils/backend_status_message.dart';
import '../../../../core/widgets/orbi_orbit_loader.dart';
import '../../data/advanced_services_service.dart';
import 'agent_screen.dart';
import 'merchant_screen.dart';

class ServiceAccessScreen extends StatefulWidget {
  const ServiceAccessScreen({super.key});

  @override
  State<ServiceAccessScreen> createState() => _ServiceAccessScreenState();
}

class _ServiceAccessScreenState extends State<ServiceAccessScreen> {
  final AdvancedServicesService _service = AdvancedServicesService();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    setState(() {
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      final requests = await _service.listServiceAccessRequests().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _requests = const [];
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _requestAccess(String role) async {
    final draft = await showModalBottomSheet<_AccessDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccessRequestSheet(role: role, isSw: _isSw),
    );
    if (draft == null) return;

    setState(() => _busy = true);
    try {
      await _service
          .submitServiceAccessRequest(
            requestedRole: role,
            businessName: draft.businessName,
            phone: draft.phone,
            note: draft.note,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      _showSnack(_t('Request sent.', 'Ombi limetumwa.'));
      await _load(quiet: true);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDesk(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _friendlyError(Object error) {
    String raw = error.toString();
    if (error is TimeoutException) {
      raw = _t(
        'Service access is taking longer than expected. Please try again.',
        'Ruhusa za huduma zinachukua muda kuliko kawaida. Tafadhali jaribu tena.',
      );
    } else if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        raw = (data['message'] ?? data['error'] ?? data).toString();
      } else {
        raw = error.message ?? raw;
      }
    }
    return mapBackendStatusMessage(
      raw,
      sw: _isSw,
      fallback: _t(
        'Service access is temporarily unavailable.',
        'Ruhusa za huduma hazipatikani kwa muda.',
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    final ui = OrbiTheme.uiOf(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? ui.danger : ui.success,
          content: Text(message),
        ),
      );
  }

  String _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('Service Access', 'Ruhusa za Huduma')),
        actions: [
          IconButton(
            tooltip: _t('Refresh', 'Sasisha'),
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _AccessHero(
                  title: _t(
                    'Open business tools safely',
                    'Fungua zana za biashara kwa usalama',
                  ),
                  subtitle: _t(
                    'Request merchant or agent access only when you need those tools.',
                    'Omba ruhusa ya merchant au agent pale unapohitaji zana hizo.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AccessActionCard(
                        icon: Icons.storefront_outlined,
                        title: _t('Agent', 'Wakala'),
                        message: _t(
                          'Serve deposits, withdrawals, and customer support.',
                          'Hudumia deposits, withdrawals, na wateja.',
                        ),
                        color: const Color(0xFFF97316),
                        actionLabel: _t('Request', 'Omba'),
                        onAction: _busy ? null : () => _requestAccess('AGENT'),
                        secondaryLabel: _t('Desk', 'Dawati'),
                        onSecondary: () => _openDesk(const AgentScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AccessActionCard(
                        icon: Icons.point_of_sale_outlined,
                        title: _t('Merchant', 'Merchant'),
                        message: _t(
                          'Accept customer payments and manage settlement.',
                          'Pokea malipo na simamia settlement.',
                        ),
                        color: const Color(0xFFDC2626),
                        actionLabel: _t('Request', 'Omba'),
                        onAction: _busy
                            ? null
                            : () => _requestAccess('MERCHANT'),
                        secondaryLabel: _t('Desk', 'Dawati'),
                        onSecondary: () => _openDesk(const MerchantScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _t('Requests', 'Maombi'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  OrbiOrbitLoadingPane(
                    label: _t(
                      'Loading service access',
                      'Inapakia ruhusa za huduma',
                    ),
                    centerIcon: Icons.verified_user_outlined,
                  )
                else if (_error != null)
                  _AccessStateCard(
                    icon: Icons.wifi_off_rounded,
                    title: _t('Could not load', 'Haikuweza kupakia'),
                    message: _error!,
                    actionLabel: _t('Try again', 'Jaribu tena'),
                    onAction: () => _load(),
                  )
                else if (_requests.isEmpty)
                  _AccessStateCard(
                    icon: Icons.verified_user_outlined,
                    title: _t('No requests yet', 'Hakuna maombi bado'),
                    message: _t(
                      'Your merchant and agent access requests will appear here.',
                      'Maombi yako ya merchant na agent yataonekana hapa.',
                    ),
                  )
                else
                  for (final request in _requests) ...[
                    _RequestTile(
                      role: _pickString([
                        request['requested_role'],
                        request['role'],
                        request['type'],
                      ]),
                      status: _pickString([
                        request['status'],
                        request['state'],
                        'PENDING',
                      ]),
                      note: _pickString([
                        request['note'],
                        request['business_name'],
                        request['phone'],
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          if (_busy)
            OrbiOrbitBlockingOverlay(
              label: _t('Please wait', 'Tafadhali subiri'),
            ),
        ],
      ),
    );
  }
}

class _AccessDraft {
  const _AccessDraft({
    required this.businessName,
    required this.phone,
    required this.note,
  });

  final String businessName;
  final String phone;
  final String note;
}

class _AccessRequestSheet extends StatefulWidget {
  const _AccessRequestSheet({required this.role, required this.isSw});

  final String role;
  final bool isSw;

  @override
  State<_AccessRequestSheet> createState() => _AccessRequestSheetState();
}

class _AccessRequestSheetState extends State<_AccessRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _businessController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _t(String en, String sw) => widget.isSw ? sw : en;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final roleLabel = widget.role == 'AGENT'
        ? _t('Agent', 'Wakala')
        : _t('Merchant', 'Merchant');
    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      minChildSize: 0.46,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ui.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: ui.border),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                const SizedBox(height: 20),
                Text(
                  _t('Request $roleLabel access', 'Omba ruhusa ya $roleLabel'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _t('Business name', 'Jina la biashara'),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _t('Enter business name', 'Weka jina la biashara');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _t('Contact phone', 'Simu ya mawasiliano'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _t('Short note', 'Maelezo mafupi'),
                    hintText: _t(
                      'Tell ORBI why you need this access.',
                      'Eleza kwa nini unahitaji ruhusa hii.',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    Navigator.of(context).pop(
                      _AccessDraft(
                        businessName: _businessController.text.trim(),
                        phone: _phoneController.text.trim(),
                        note: _noteController.text.trim(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(_t('Submit request', 'Tuma ombi')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccessHero extends StatelessWidget {
  const _AccessHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [ui.accent, const Color(0xFF06343B)]),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.security_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.3,
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

class _AccessActionCard extends StatelessWidget {
  const _AccessActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.actionLabel,
    required this.onAction,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String actionLabel;
  final VoidCallback? onAction;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: ui.textMuted, height: 1.25)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(actionLabel),
          ),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
        ],
      ),
    );
  }
}

class _AccessStateCard extends StatelessWidget {
  const _AccessStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: ui.accent, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: ui.textMuted, height: 1.3),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.role,
    required this.status,
    required this.note,
  });

  final String role;
  final String status;
  final String note;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ui.accentSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.assignment_turned_in_outlined, color: ui.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.isEmpty ? 'Service access' : role,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ui.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status.isEmpty ? 'PENDING' : status,
            style: TextStyle(
              color: ui.accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
