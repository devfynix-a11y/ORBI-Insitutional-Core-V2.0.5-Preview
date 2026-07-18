import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/widgets/orbi_orbit_loader.dart';
import '../../auth/state/auth_controller.dart';
import '../data/enterprise_service.dart';
import 'enterprise_dashboard_screen.dart';

class OrganizationSetupScreen extends StatefulWidget {
  const OrganizationSetupScreen({super.key});

  @override
  State<OrganizationSetupScreen> createState() =>
      _OrganizationSetupScreenState();
}

class _OrganizationSetupScreenState extends State<OrganizationSetupScreen> {
  final EnterpriseService _service = EnterpriseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _taxController = TextEditingController();
  final _purposeController = TextEditingController();

  String _currency = 'TZS';
  String _country = 'TZ';
  bool _busy = false;
  String? _error;

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _t(String en, String sw) => _isSw ? sw : en;

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _taxController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      final token = await auth.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('SESSION_EXPIRED');
      }
      await _service.createOrganization(token, {
        'name': _nameController.text.trim(),
        'base_currency': _currency,
        'country': _country,
        'owner_type': 'ORGANIZATION',
        'owner_label': _nameController.text.trim(),
        if (_registrationController.text.trim().isNotEmpty)
          'registration_number': _registrationController.text.trim(),
        if (_taxController.text.trim().isNotEmpty)
          'tax_id': _taxController.text.trim(),
        'metadata': {
          'setup_channel': 'mobile_organization_portal',
          if (_purposeController.text.trim().isNotEmpty)
            'purpose': _purposeController.text.trim(),
        },
      });
      await auth.refreshCurrentProfile();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EnterpriseDashboardScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = mapBackendStatusMessage(
          error.toString(),
          sw: _isSw,
          fallback: _t(
            'Unable to create the organization right now.',
            'Imeshindikana kuunda organization kwa sasa.',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Organization', 'Organization')),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF12343B),
                      const Color(0xFF0EA5A4).withValues(alpha: 0.82),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5A4).withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _t(
                        'Create an ORBI Organization',
                        'Unda Organization ya ORBI',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'For groups, companies, committees, approvals, shared funds, and audited team finance.',
                        'Kwa vikundi, kampuni, kamati, idhini, fedha za pamoja, na audit ya matumizi ya timu.',
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(
                    color: ui.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _t(
                          'Organization name',
                          'Jina la organization',
                        ),
                        prefixIcon: const Icon(Icons.apartment_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 2) {
                          return _t(
                            'Enter a valid organization name.',
                            'Weka jina sahihi la organization.',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _country,
                            decoration: InputDecoration(
                              labelText: _t('Country', 'Nchi'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'TZ',
                                child: Text('Tanzania'),
                              ),
                              DropdownMenuItem(
                                value: 'KE',
                                child: Text('Kenya'),
                              ),
                              DropdownMenuItem(
                                value: 'UG',
                                child: Text('Uganda'),
                              ),
                              DropdownMenuItem(
                                value: 'ZA',
                                child: Text('South Africa'),
                              ),
                              DropdownMenuItem(
                                value: 'US',
                                child: Text('United States'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _country = value ?? 'TZ';
                                    _currency = _country == 'TZ'
                                        ? 'TZS'
                                        : _currency;
                                  }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: InputDecoration(
                              labelText: _t('Currency', 'Sarafu'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'TZS',
                                child: Text('TZS'),
                              ),
                              DropdownMenuItem(
                                value: 'KES',
                                child: Text('KES'),
                              ),
                              DropdownMenuItem(
                                value: 'UGX',
                                child: Text('UGX'),
                              ),
                              DropdownMenuItem(
                                value: 'ZAR',
                                child: Text('ZAR'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('USD'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(
                                    () => _currency = value ?? 'TZS',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _registrationController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _t(
                          'Registration number (optional)',
                          'Namba ya usajili (si lazima)',
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _t(
                          'Tax ID / TIN (optional)',
                          'TIN / Kodi (si lazima)',
                        ),
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _purposeController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _t(
                          'Purpose (optional)',
                          'Matumizi ya organization (si lazima)',
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t('What becomes available', 'Vinavyofunguka'),
                style: TextStyle(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              _CapabilityTile(
                icon: Icons.groups_2_outlined,
                title: _t('Roles and members', 'Roles na wanachama'),
                message: _t(
                  'Admin, manager, accountant, signatory, and member governance.',
                  'Admin, meneja, mhasibu, msaini, na member governance.',
                ),
              ),
              _CapabilityTile(
                icon: Icons.savings_outlined,
                title: _t('Organization Fungu', 'Fungu la organization'),
                message: _t(
                  'Funds owned by the organization, not one person.',
                  'Fedha zinamilikiwa na organization, si mtu mmoja.',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _createOrganization,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_t('Create Organization', 'Unda Organization')),
              ),
            ],
          ),
          if (_busy)
            OrbiOrbitBlockingOverlay(
              label: _t('Creating organization', 'Inaunda organization'),
            ),
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0EA5A4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: ui.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
