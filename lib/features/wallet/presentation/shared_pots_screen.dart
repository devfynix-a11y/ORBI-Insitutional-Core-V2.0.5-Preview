import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:orbi_mobileapp/l10n/wealth_localizations.dart';

import '../../../core/reports/orbi_resource_report_printer.dart';
import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_activity_card.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_brand_hero_card.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../data/wealth_service.dart';
import 'widgets/invitee_lookup_card.dart';
import 'widgets/wealth_hero_card.dart';

const Color _sharedPotAccent = Color(0xFF0EA5A4);

class SharedPotsScreen extends StatefulWidget {
  const SharedPotsScreen({super.key});

  @override
  State<SharedPotsScreen> createState() => _SharedPotsScreenState();
}

class _SharedPotsScreenState extends State<SharedPotsScreen> {
  final WealthService _service = WealthService();

  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  String? _error;
  List<Map<String, dynamic>> _pots = const [];
  List<Map<String, dynamic>> _invitations = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.listSharedPots(),
        _service.listMySharedPotInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _pots = results[0];
        _invitations = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = mapBackendStatusMessage(
          e.toString(),
          sw: l10n.isSw,
          fallback: l10n.wealthSharedPotsLoadError,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _accessModelHelp(AppLocalizations l10n, String accessModel) {
    switch (accessModel.toUpperCase()) {
      case 'PRIVATE':
        return l10n.pick(
          en: 'Private Fungu is controlled by the owner only. Invites are disabled and withdrawals are owner-only.',
          swText:
              'Fungu binafsi hudhibitiwa na mmiliki pekee. Mialiko imefungwa na kutoa fedha ni kwa mmiliki tu.',
        );
      case 'ORG':
        return l10n.pick(
          en: 'Organisation Fungu is linked to your organisation and uses stricter approval governance.',
          swText:
              'Fungu la taasisi huunganishwa na taasisi yako na hutumia idhini kali zaidi kabla ya kutoa fedha.',
        );
      default:
        return l10n.pick(
          en: 'Invite-only Fungu is ideal for weddings, trips, projects, and group contributions. Owners or managers can withdraw; contributors can add money.',
          swText:
              'Fungu la mwaliko linafaa kwa harusi, safari, miradi na michango ya pamoja. Mmiliki au meneja anaweza kutoa; wachangiaji huongeza fedha.',
        );
    }
  }

  Future<void> _showInbox() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(
              title: l10n.pick(en: 'Fungu inbox', swText: 'Inbox ya Fungu'),
            ),
            const SizedBox(height: 16),
            if (_invitations.isEmpty)
              _InlineEmpty(
                message: l10n.pick(
                  en: 'No invitations right now.',
                  swText: 'Hakuna mialiko kwa sasa.',
                ),
              )
            else
              ..._invitations.map((invite) {
                final pot = invite['shared_pots'] is Map
                    ? Map<String, dynamic>.from(invite['shared_pots'] as Map)
                    : const <String, dynamic>{};
                final pending =
                    (invite['status'] ?? '').toString().toUpperCase() ==
                    'PENDING';
                return _InviteRow(
                  title:
                      (pot['name'] ?? l10n.pick(en: 'Fungu', swText: 'Fungu'))
                          .toString(),
                  subtitle:
                      '${(invite['role'] ?? 'CONTRIBUTOR').toString()} • ${(invite['status'] ?? 'PENDING').toString()}',
                  pending: pending,
                  onAccept: () async {
                    Navigator.of(context).pop();
                    await _respondToInvitation(
                      invite['id'].toString(),
                      'ACCEPT',
                    );
                  },
                  onReject: () async {
                    Navigator.of(context).pop();
                    await _respondToInvitation(
                      invite['id'].toString(),
                      'REJECT',
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToInvitation(String id, String action) async {
    await _runBusy(
      AppLocalizations.of(
        context,
      )!.pick(en: 'Saving response...', swText: 'Inahifadhi jibu...'),
      () async {
        await _service.respondToSharedPotInvitation(id, {'action': action});
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _statusMessage = l10n.pick(
            en: action == 'ACCEPT'
                ? 'Invitation accepted.'
                : 'Invitation rejected.',
            swText: action == 'ACCEPT'
                ? 'Mwaliko umekubaliwa.'
                : 'Mwaliko umekataliwa.',
          );
          _statusTone = OrbiStatusTone.success;
        });
        await _load();
      },
    );
  }

  Future<bool> _runBusy(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
      _statusMessage = null;
    });
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _statusMessage = mapBackendStatusMessage(
            error.toString(),
            sw: l10n.isSw,
            fallback: l10n.wealthSharedPotsLoadError,
          );
          _statusTone = OrbiStatusTone.error;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<T?> _loadBusyData<T>(
    String message,
    Future<T> Function() loader,
  ) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
      _statusMessage = null;
    });
    try {
      return await loader();
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _statusMessage = mapBackendStatusMessage(
            error.toString(),
            sw: l10n.isSw,
            fallback: l10n.wealthSharedPotsLoadError,
          );
          _statusTone = OrbiStatusTone.error;
        });
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _showCreatePotSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final purposeController = TextEditingController();
    final targetController = TextEditingController();
    String accessModel = 'INVITE';
    String? formError;
    bool submitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ui.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pick(en: 'Create Fungu', swText: 'Unda Fungu'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.pick(
                        en: 'Keep this shared fund simple, clear, and easy to manage.',
                        swText:
                            'Hifadhi fungu hili liwe rahisi, wazi, na rahisi kusimamia.',
                      ),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: TextStyle(
                          color: ui.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          en: 'Fungu name',
                          swText: 'Jina la Fungu',
                        ),
                        hintText: l10n.pick(
                          en: 'Example school fees',
                          swText: 'Mfano ada ya shule',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purposeController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.wealthPurpose,
                        hintText: l10n.pick(
                          en: 'Family, team, business',
                          swText: 'Familia, timu, biashara',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OrbiAmountField(
                      controller: targetController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountInputFormatter()],
                      label: l10n.wealthTargetAmount,
                      currency: 'TZS',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: accessModel,
                      items: [
                        DropdownMenuItem(
                          value: 'INVITE',
                          child: Text(
                            l10n.pick(
                              en: 'Invite only',
                              swText: 'Mwaliko pekee',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text(
                            l10n.pick(en: 'Private', swText: 'Binafsi'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ORG',
                          child: Text(
                            l10n.pick(en: 'Organisation', swText: 'Taasisi'),
                          ),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) => setSheetState(
                              () => accessModel = value ?? accessModel,
                            ),
                      decoration: InputDecoration(
                        labelText: l10n.wealthAccessModel,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accessModelHelp(l10n, accessModel),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final target = AmountInputFormatter.tryParse(
                                  targetController.text,
                                );
                                if (name.isEmpty) {
                                  setSheetState(() {
                                    formError = l10n.wealthEnterPotNameFirst;
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  await _service.createSharedPot({
                                    'name': name,
                                    'purpose': purposeController.text.trim(),
                                    'target_amount': target,
                                    'access_model': accessModel,
                                  });
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: l10n.isSw,
                                      fallback: l10n.wealthCreateSharedPotError,
                                    );
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(l10n.wealthSaving),
                                ],
                              )
                            : Text(
                                l10n.pick(
                                  en: 'Save Fungu',
                                  swText: 'Hifadhi Fungu',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    purposeController.dispose();
    targetController.dispose();

    if (created == true) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.wealthSharedPotCreated;
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  Future<void> _showEditPotSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(
      text: (pot['name'] ?? '').toString(),
    );
    final purposeController = TextEditingController(
      text: (pot['purpose'] ?? '').toString(),
    );
    final targetController = TextEditingController(
      text: AmountInputFormatter.format('${pot['target_amount'] ?? ''}'),
    );
    String accessModel = (pot['access_model'] ?? 'INVITE').toString();
    String? formError;
    bool submitting = false;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ui.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pick(en: 'Edit Fungu', swText: 'Hariri Fungu'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: TextStyle(
                          color: ui.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          en: 'Fungu name',
                          swText: 'Jina la Fungu',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purposeController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.wealthPurpose,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OrbiAmountField(
                      controller: targetController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountInputFormatter()],
                      label: l10n.wealthTargetAmount,
                      currency: (pot['currency'] ?? 'TZS').toString(),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: accessModel,
                      items: [
                        DropdownMenuItem(
                          value: 'INVITE',
                          child: Text(
                            l10n.pick(
                              en: 'Invite only',
                              swText: 'Mwaliko pekee',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text(
                            l10n.pick(en: 'Private', swText: 'Binafsi'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ORG',
                          child: Text(
                            l10n.pick(en: 'Organisation', swText: 'Taasisi'),
                          ),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) => setSheetState(
                              () => accessModel = value ?? accessModel,
                            ),
                      decoration: InputDecoration(
                        labelText: l10n.wealthAccessModel,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accessModelHelp(l10n, accessModel),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final target = AmountInputFormatter.tryParse(
                                  targetController.text,
                                );
                                if (name.isEmpty) {
                                  setSheetState(() {
                                    formError = l10n.wealthEnterPotNameFirst;
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  await _service.updateSharedPot(
                                    (pot['id'] ?? '').toString(),
                                    {
                                      'name': name,
                                      'purpose': purposeController.text.trim(),
                                      'target_amount': target,
                                      'access_model': accessModel,
                                    },
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: l10n.isSw,
                                      fallback: l10n.wealthUpdateSharedPotError,
                                    );
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(l10n.wealthSaving),
                                ],
                              )
                            : Text(
                                l10n.pick(
                                  en: 'Save Fungu changes',
                                  swText: 'Hifadhi mabadiliko ya Fungu',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    purposeController.dispose();
    targetController.dispose();

    if (updated == true) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.wealthSharedPotUpdated;
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  Future<void> _showContributeSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    String? formError;
    bool submitting = false;
    final contributed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ui.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pick(
                        en: 'Contribute to Fungu',
                        swText: 'Changia Fungu',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.pick(
                        en: 'Add money into this shared fund.',
                        swText: 'Ongeza fedha kwenye fungu hili.',
                      ),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: TextStyle(
                          color: ui.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OrbiAmountField(
                      controller: amountController,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [AmountInputFormatter()],
                      label: l10n.wealthAmount,
                      currency: (pot['currency'] ?? 'TZS').toString(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final amount = AmountInputFormatter.tryParse(
                                  amountController.text,
                                );
                                if (amount == null || amount <= 0) {
                                  setSheetState(() {
                                    formError = l10n.isSw
                                        ? 'Weka kiasi sahihi cha mchango.'
                                        : 'Enter a valid contribution amount.';
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  await _service.contributeToSharedPot(
                                    (pot['id'] ?? '').toString(),
                                    {'amount': amount},
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: l10n.isSw,
                                      fallback: l10n.wealthContributeError,
                                    );
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(l10n.wealthSaving),
                                ],
                              )
                            : Text(
                                l10n.pick(
                                  en: 'Contribute now',
                                  swText: 'Changia sasa',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();

    if (contributed == true) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.wealthContributionAdded;
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  Future<void> _showWithdrawSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String? formError;
    bool submitting = false;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ui.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pick(
                        en: 'Withdraw from Fungu',
                        swText: 'Toa kutoka Fungu',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.pick(
                        en: 'Take money out of this shared fund.',
                        swText: 'Toa fedha kutoka kwenye fungu hili.',
                      ),
                      style: TextStyle(color: ui.textMuted, height: 1.35),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: TextStyle(
                          color: ui.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OrbiAmountField(
                      controller: amountController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountInputFormatter()],
                      label: l10n.wealthAmount,
                      currency: (pot['currency'] ?? 'TZS').toString(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          en: 'Reason for withdrawal',
                          swText: 'Sababu ya kutoa fedha',
                        ),
                        hintText: l10n.pick(
                          en: 'Example: pay supplier, emergency support...',
                          swText: 'Mfano: kulipa huduma, dharura...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final amount = AmountInputFormatter.tryParse(
                                  amountController.text,
                                );
                                if (amount == null || amount <= 0) {
                                  setSheetState(() {
                                    formError = l10n.isSw
                                        ? 'Weka kiasi sahihi cha kutoa.'
                                        : 'Enter a valid withdrawal amount.';
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  final response = await _service
                                      .withdrawFromSharedPot(
                                        (pot['id'] ?? '').toString(),
                                        {
                                          'amount': amount,
                                          'reason': reasonController.text
                                              .trim(),
                                        },
                                      );
                                  if (!sheetContext.mounted) return;
                                  final requiresApproval =
                                      response['requires_approval'] == true ||
                                      response['request'] != null;
                                  Navigator.of(sheetContext).pop(
                                    requiresApproval ? 'approval' : 'withdrawn',
                                  );
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: l10n.isSw,
                                      fallback: l10n.wealthWithdrawError,
                                    );
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(l10n.wealthSaving),
                                ],
                              )
                            : Text(
                                l10n.pick(
                                  en: 'Withdraw now',
                                  swText: 'Toa sasa',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
    reasonController.dispose();

    if (result != null) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = result == 'approval'
            ? l10n.pick(
                en: 'Withdrawal request sent for approval.',
                swText: 'Ombi la kutoa fedha limetumwa kwa idhini.',
              )
            : l10n.wealthFundsWithdrawn;
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  Future<void> _showInviteMemberSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final identifierController = TextEditingController();
    Timer? lookupDebounce;
    var lookupGeneration = 0;
    var lookupLoading = false;
    String? lookupError;
    Map<String, dynamic>? lookupPreview;
    String role = 'CONTRIBUTOR';
    String? formError;
    bool submitting = false;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ui = OrbiTheme.uiOf(sheetContext);
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void clearLookup() {
              lookupGeneration++;
              lookupDebounce?.cancel();
              setSheetState(() {
                lookupLoading = false;
                lookupError = null;
                lookupPreview = null;
              });
            }

            void lookupInvitee(String value) {
              lookupDebounce?.cancel();
              final query = value.trim();
              if (query.isEmpty) {
                clearLookup();
                return;
              }
              if (query.length < 3) {
                lookupGeneration++;
                setSheetState(() {
                  lookupLoading = false;
                  lookupPreview = null;
                  lookupError = l10n.isSw
                      ? 'Weka angalau herufi/tarakimu 3.'
                      : 'Enter at least 3 characters.';
                });
                return;
              }
              final generation = ++lookupGeneration;
              setSheetState(() {
                lookupLoading = true;
                lookupError = null;
                lookupPreview = null;
              });
              lookupDebounce = Timer(
                const Duration(milliseconds: 360),
                () async {
                  try {
                    final data = await _service.lookupInvitee(query);
                    if (!sheetContext.mounted ||
                        generation != lookupGeneration) {
                      return;
                    }
                    setSheetState(() {
                      lookupLoading = false;
                      lookupPreview = data;
                      lookupError = data == null
                          ? (l10n.isSw
                                ? 'Hatujampata mtumiaji huyo wa ORBI.'
                                : 'We could not find that ORBI user.')
                          : null;
                    });
                  } catch (error) {
                    if (!sheetContext.mounted ||
                        generation != lookupGeneration) {
                      return;
                    }
                    setSheetState(() {
                      lookupLoading = false;
                      lookupPreview = null;
                      lookupError = mapBackendStatusMessage(
                        error.toString(),
                        sw: l10n.isSw,
                        fallback: l10n.isSw
                            ? 'Uhakiki wa mtumiaji haupatikani kwa sasa.'
                            : 'User lookup is unavailable right now.',
                      );
                    });
                  }
                },
              );
            }

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ui.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.wealthInviteMember,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ui.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.wealthInviteMemberHelp,
                        style: TextStyle(color: ui.textMuted, height: 1.35),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          formError!,
                          style: TextStyle(
                            color: ui.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: identifierController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.isSw
                              ? 'Simu, barua pepe, au ORBI ID'
                              : 'Phone, email, or ORBI ID',
                          suffixIcon: lookupLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(13),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : lookupPreview == null
                              ? null
                              : const Icon(Icons.verified_rounded),
                        ),
                        onChanged: lookupInvitee,
                      ),
                      if (lookupError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          lookupError!,
                          style: TextStyle(
                            color: ui.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (lookupPreview != null) ...[
                        const SizedBox(height: 10),
                        InviteeLookupCard(
                          data: lookupPreview!,
                          accent: _sharedPotAccent,
                          isSw: l10n.isSw,
                        ),
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        items: [
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text(
                              l10n.pick(en: 'Manager', swText: 'Meneja'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CONTRIBUTOR',
                            child: Text(
                              l10n.pick(
                                en: 'Contributor',
                                swText: 'Mchangiaji',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'VIEWER',
                            child: Text(
                              l10n.pick(en: 'Viewer', swText: 'Mtazamaji'),
                            ),
                          ),
                        ],
                        onChanged: submitting
                            ? null
                            : (value) =>
                                  setSheetState(() => role = value ?? role),
                        decoration: InputDecoration(
                          labelText: l10n.wealthRole,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              submitting ||
                                  lookupLoading ||
                                  lookupPreview == null
                              ? null
                              : () async {
                                  final identifier = _service
                                      .resolveInviteeIdentifier(
                                        lookupPreview,
                                        fallback: identifierController.text,
                                      );
                                  if (identifier.isEmpty) {
                                    setSheetState(() {
                                      formError =
                                          l10n.wealthEnterPhoneOrEmailFirst;
                                    });
                                    return;
                                  }
                                  if (lookupPreview == null) {
                                    setSheetState(() {
                                      formError = l10n.isSw
                                          ? 'Hakiki kwanza mtumiaji wa ORBI kabla ya kutuma mwaliko.'
                                          : 'Confirm the ORBI user before sending the invitation.';
                                    });
                                    return;
                                  }
                                  setSheetState(() {
                                    submitting = true;
                                    formError = null;
                                  });
                                  try {
                                    final payload = _service.buildInvitePayload(
                                      invitee: lookupPreview,
                                      fallback: identifierController.text,
                                      role: role,
                                    );
                                    await _service.addSharedPotMember(
                                      (pot['id'] ?? '').toString(),
                                      payload,
                                    );
                                    if (!sheetContext.mounted) return;
                                    Navigator.of(sheetContext).pop(true);
                                  } catch (e) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {
                                      formError = mapBackendStatusMessage(
                                        e.toString(),
                                        sw: l10n.isSw,
                                        fallback: l10n.wealthInviteError,
                                      );
                                      submitting = false;
                                    });
                                  }
                                },
                          child: submitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(l10n.wealthSaving),
                                  ],
                                )
                              : Text(l10n.wealthSendInvite),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    lookupDebounce?.cancel();
    identifierController.dispose();

    if (added == true) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _statusMessage = l10n.wealthInviteSent;
        _statusTone = OrbiStatusTone.success;
      });
    }
  }

  Future<void> _showMembersSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    final members = await _loadBusyData(
      l10n.wealthLoadingMembers,
      () => _service.listSharedPotMembers((pot['id'] ?? '').toString()),
    );
    if (!mounted || members == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(en: 'Fungu members', swText: 'Wanachama wa Fungu'),
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.pick(
                  en: 'Everyone with access to this Fungu.',
                  swText: 'Wote wenye ruhusa kwenye Fungu hili.',
                ),
                style: TextStyle(color: ui.textMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                OrbiStateCard(
                  icon: Icons.group_off_rounded,
                  title: l10n.pick(
                    en: 'No members yet',
                    swText: 'Hakuna wanachama bado',
                  ),
                  message: l10n.pick(
                    en: 'Send the first invite to grow this Fungu.',
                    swText: 'Tuma mwaliko wa kwanza kuongeza Fungu hili.',
                  ),
                  accentColor: ui.textMuted,
                  accentBackground: ui.cardMuted,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final user = (member['users'] is Map)
                          ? Map<String, dynamic>.from(member['users'] as Map)
                          : ((member['user'] is Map)
                                ? Map<String, dynamic>.from(
                                    member['user'] as Map,
                                  )
                                : const <String, dynamic>{});
                      final title =
                          (user['full_name'] ??
                                  user['email'] ??
                                  user['phone'] ??
                                  'Member')
                              .toString();
                      final subtitle = (user['email'] ?? user['phone'] ?? '')
                          .toString();
                      final role = (member['role'] ?? 'CONTRIBUTOR').toString();
                      final contributed = _money(
                        member['contributed_amount'],
                        pot['currency']?.toString(),
                      );
                      final contributionTarget =
                          member['contribution_target'] == null
                          ? null
                          : _money(
                              member['contribution_target'],
                              pot['currency']?.toString(),
                            );
                      return OrbiActivityCard(
                        accent: _sharedPotAccent,
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _sharedPotAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: _sharedPotAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(color: ui.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    contributionTarget == null
                                        ? l10n.wealthContributedLabel(
                                            contributed,
                                          )
                                        : l10n.wealthContributedTargetLabel(
                                            contributed,
                                            contributionTarget,
                                          ),
                                    style: TextStyle(
                                      color: ui.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _metaChip(context, role),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportSheet(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final potId = (pot['id'] ?? '').toString();
    if (potId.isEmpty) return;
    await OrbiResourceReportPrinter.openReportSheet(
      context,
      title: l10n.pick(en: 'Fungu report', swText: 'Ripoti ya Fungu'),
      subtitle: (pot['name'] ?? 'Fungu').toString(),
      filePrefix: 'orbi_fungu_report',
      loadReport: (range) => _service.getSharedPotReport(potId, range: range),
    );
  }

  Future<void> _requestArchivePot(Map<String, dynamic> pot) async {
    final l10n = AppLocalizations.of(context)!;
    final potId = (pot['id'] ?? '').toString();
    if (potId.isEmpty) return;

    if (_asDouble(pot['current_amount']) >= 1) {
      setState(() {
        _statusMessage = l10n.pick(
          en: 'This Fungu must have a zero balance before it can be archived.',
          swText:
              'Fungu hili lazima liwe na salio sifuri kabla ya kuhifadhiwa.',
        );
        _statusTone = OrbiStatusTone.error;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pick(en: 'Archive Fungu?', swText: 'Hifadhi Fungu?')),
        content: Text(
          l10n.pick(
            en: 'For safety, archiving requires OTP and 3 approvals. Once approved, it waits 24 hours before leaving the main list, and can still be cancelled during that time.',
            swText:
                'Kwa usalama, kuhifadhi kunahitaji OTP na idhini 3. Baada ya kuidhinishwa, husubiri saa 24 kabla ya kutoka kwenye orodha kuu, na bado kuna nafasi ya kughairi ndani ya muda huo.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.pick(en: 'Cancel', swText: 'Ghairi')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.pick(en: 'Continue', swText: 'Endelea')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    Future<Map<String, dynamic>> submit({
      String? otpRequestId,
      String? otpCode,
    }) {
      final payload = <String, dynamic>{};
      if (otpRequestId != null) payload['otp_request_id'] = otpRequestId;
      if (otpCode != null) payload['otp_code'] = otpCode;
      return _service.requestSharedPotArchive(potId, payload);
    }

    final first = await _loadBusyData<Map<String, dynamic>>(
      l10n.pick(
        en: 'Preparing archive request...',
        swText: 'Tunaandaa ombi la kuhifadhi...',
      ),
      submit,
    );
    if (!mounted || first == null) return;

    var result = first;
    if (first['error']?.toString().toUpperCase() == 'SECURITY_CHALLENGE') {
      final challenge = first['challenge'] is Map
          ? Map<String, dynamic>.from(first['challenge'] as Map)
          : const <String, dynamic>{};
      final otpRequestId =
          (challenge['otp_request_id'] ?? challenge['id'] ?? '').toString();
      final contact = (challenge['delivery_contact'] ?? '').toString();
      final otpCode = await _promptArchiveOtp(contact: contact);
      if (!mounted || otpCode == null || otpCode.trim().isEmpty) return;
      final verifiedResult = await _loadBusyData<Map<String, dynamic>>(
        l10n.pick(en: 'Verifying OTP...', swText: 'Tunathibitisha OTP...'),
        () => submit(otpRequestId: otpRequestId, otpCode: otpCode.trim()),
      );
      if (!mounted || verifiedResult == null) return;
      result = verifiedResult;
    }

    await _load();
    if (!mounted) return;
    final request = result['request'] is Map
        ? Map<String, dynamic>.from(result['request'] as Map)
        : const <String, dynamic>{};
    final status = (request['status'] ?? '').toString().toUpperCase();
    setState(() {
      _statusMessage = status == 'SCHEDULED'
          ? l10n.pick(
              en: 'Archive approved and scheduled. It can be cancelled within 24 hours.',
              swText:
                  'Ombi limeidhinishwa na kupangwa. Linaweza kughairiwa ndani ya saa 24.',
            )
          : l10n.pick(
              en: 'Archive request sent. It now needs 3 approvals.',
              swText: 'Ombi la kuhifadhi limetumwa. Sasa linahitaji idhini 3.',
            );
      _statusTone = OrbiStatusTone.success;
    });
  }

  Future<String?> _promptArchiveOtp({required String contact}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pick(en: 'Confirm OTP', swText: 'Thibitisha OTP')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.isEmpty
                  ? l10n.pick(
                      en: 'Enter the OTP sent to your verified contact.',
                      swText:
                          'Weka OTP iliyotumwa kwenye mawasiliano yako yaliyothibitishwa.',
                    )
                  : l10n.pick(
                      en: 'Enter the OTP sent to $contact.',
                      swText: 'Weka OTP iliyotumwa kwenda $contact.',
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.pick(en: 'OTP code', swText: 'Msimbo wa OTP'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.pick(en: 'Cancel', swText: 'Ghairi')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.pick(en: 'Verify', swText: 'Thibitisha')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _changePotState(
    Map<String, dynamic> pot,
    String nextStatus,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final updated = await _runBusy(
      l10n.wealthUpdatingStatus,
      () => _service.updateSharedPot((pot['id'] ?? '').toString(), {
        'status': nextStatus,
      }),
    );
    if (!updated) return;
    await _load();
    if (!mounted) return;
    setState(() {
      _statusMessage = l10n.wealthPotStatusUpdated;
      _statusTone = OrbiStatusTone.success;
    });
  }

  String _money(dynamic amount, String? currency) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    final numeric = amount is num
        ? amount.toDouble()
        : double.tryParse('${amount ?? 0}'.replaceAll(',', '')) ?? 0;
    return formatAppBalanceAmount(
      numeric,
      (currency ?? 'TZS').toUpperCase(),
      locale: localeTag,
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '').trim()) ?? 0;
  }

  bool _isArchivedOrPendingArchive(Map<String, dynamic> pot) {
    final status = (pot['status'] ?? 'ACTIVE').toString().toUpperCase();
    final metadata = pot['metadata'] is Map
        ? Map<String, dynamic>.from(pot['metadata'] as Map)
        : const <String, dynamic>{};
    return status == 'ARCHIVED' || metadata['pending_archive'] == true;
  }

  Future<void> _showArchivedPotsSheet(
    List<Map<String, dynamic>> archived,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(
              title: l10n.pick(
                en: 'Archived Fungu',
                swText: 'Fungu zilizohifadhiwa',
              ),
            ),
            const SizedBox(height: 12),
            if (archived.isEmpty)
              _InlineEmpty(
                message: l10n.pick(
                  en: 'No archived Fungu yet.',
                  swText: 'Hakuna Fungu zilizohifadhiwa bado.',
                ),
              )
            else
              ...archived.map((pot) {
                final metadata = pot['metadata'] is Map
                    ? Map<String, dynamic>.from(pot['metadata'] as Map)
                    : const <String, dynamic>{};
                final pending = metadata['pending_archive'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    pending ? Icons.schedule_rounded : Icons.archive_outlined,
                    color: _sharedPotAccent,
                  ),
                  title: Text((pot['name'] ?? 'Fungu').toString()),
                  subtitle: Text(
                    pending
                        ? l10n.pick(
                            en: 'Archive pending. It can still be cancelled.',
                            swText:
                                'Inasubiri kuhifadhiwa. Bado inaweza kughairiwa.',
                          )
                        : l10n.pick(
                            en: 'Archived and hidden from the main list.',
                            swText:
                                'Imehifadhiwa na imefichwa kwenye orodha kuu.',
                          ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    final pendingInvites = _invitations
        .where(
          (invite) =>
              (invite['status'] ?? '').toString().toUpperCase() == 'PENDING',
        )
        .length;
    final activePots = _pots
        .where((pot) => !_isArchivedOrPendingArchive(pot))
        .toList(growable: false);
    final archivedPots = _pots
        .where(_isArchivedOrPendingArchive)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, color: _sharedPotAccent, size: 18),
            const SizedBox(width: 8),
            const Flexible(child: Text('Fungu')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.pick(en: 'Inbox', swText: 'Inbox'),
            onPressed: _showInbox,
            icon: Badge.count(
              isLabelVisible: pendingInvites > 0,
              count: pendingInvites,
              child: const Icon(Icons.mail_outline_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePotSheet,
        icon: const Icon(Icons.group_add_rounded),
        label: Text(l10n.pick(en: 'Create Fungu', swText: 'Unda Fungu')),
        backgroundColor: _sharedPotAccent,
        foregroundColor: Colors.white,
      ),
      body: OrbiLoadingOverlay(
        loading: _busy,
        message: _busyMessage,
        statusMessage: _statusMessage,
        statusTone: _statusMessage == null ? null : _statusTone,
        onDismissStatus: () => setState(() => _statusMessage = null),
        child: OrbiBackground(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WealthHeroCard(
                  icon: Icons.groups_2_rounded,
                  title: 'Fungu',
                  subtitle: l10n.pick(
                    en: 'Track and review this shared fund when needed.',
                    swText: 'Fuatilia na hakiki fungu hili ukihitaji.',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrbiHeroMetricChip(
                        icon: Icons.groups_2_rounded,
                        label: l10n.pick(en: 'Total pots', swText: 'Vifungu'),
                        value: '${activePots.length}',
                      ),
                      OrbiHeroMetricChip(
                        icon: Icons.people_alt_outlined,
                        label: l10n.pick(en: 'Members', swText: 'Members'),
                        value: '${activePots.length}',
                      ),
                      OrbiHeroMetricChip(
                        icon: Icons.mail_outline_rounded,
                        label: l10n.pick(en: 'Inbox', swText: 'Inbox'),
                        value: '$pendingInvites',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.archive_outlined, size: 16),
                        label: Text(
                          l10n.pick(
                            en: 'Archived ${archivedPots.length}',
                            swText: 'Zilizohifadhiwa ${archivedPots.length}',
                          ),
                        ),
                        onPressed: () => _showArchivedPotsSheet(archivedPots),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  OrbiStateCard(
                    icon: Icons.sync_problem_rounded,
                    title: l10n.wealthSharedPotsLoadTitle,
                    message: _error,
                    accentColor: ui.warning,
                    accentBackground: ui.warningSoft,
                    action: TextButton(
                      onPressed: _load,
                      style: TextButton.styleFrom(
                        foregroundColor: _sharedPotAccent,
                      ),
                      child: Text(l10n.commonTryAgain),
                    ),
                  )
                else if (activePots.isEmpty)
                  OrbiStateCard(
                    icon: Icons.people_outline_rounded,
                    title: l10n.wealthNoSharedPotYet,
                    message: l10n.wealthNoSharedPotMessage,
                    accentColor: _sharedPotAccent,
                    accentBackground: _sharedPotAccent.withValues(alpha: 0.14),
                    action: TextButton(
                      onPressed: _showCreatePotSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: _sharedPotAccent,
                      ),
                      child: Text(l10n.wealthCreatePot),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fungu',
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _metaChip(
                        context,
                        '${activePots.length} ${activePots.length == 1 ? l10n.pick(en: 'Fungu', swText: 'Fungu') : l10n.pick(en: 'Vifungu', swText: 'Vifungu')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...activePots.map((pot) {
                    final role = (pot['my_role'] ?? 'OWNER').toString();
                    final canWithdraw = role == 'OWNER' || role == 'MANAGER';
                    final canInvite = role == 'OWNER' || role == 'MANAGER';
                    final currentAmount = _asDouble(pot['current_amount']);
                    final targetAmount = pot['target_amount'] == null
                        ? null
                        : _asDouble(pot['target_amount']);
                    final progress = targetAmount == null || targetAmount <= 0
                        ? null
                        : (currentAmount / targetAmount).clamp(0.0, 1.0);
                    final current = _money(
                      pot['current_amount'],
                      pot['currency']?.toString(),
                    );
                    final target = pot['target_amount'] == null
                        ? null
                        : _money(
                            pot['target_amount'],
                            pot['currency']?.toString(),
                          );
                    final status = (pot['status'] ?? 'ACTIVE')
                        .toString()
                        .toUpperCase();
                    final accessModel = (pot['access_model'] ?? 'INVITE')
                        .toString()
                        .toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrbiActivityCard(
                        accent: _sharedPotAccent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _sharedPotAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    status == 'ACTIVE'
                                        ? Icons.savings_outlined
                                        : Icons.pause_circle_outline_rounded,
                                    color: _sharedPotAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (pot['name'] ?? 'Fungu').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (pot['purpose'] ?? 'Uwekaji wa Fungu')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: ui.textMuted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      current,
                                      style: TextStyle(
                                        color: ui.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (target != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'of $target',
                                        style: TextStyle(
                                          color: ui.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'contribute') {
                                      _showContributeSheet(pot);
                                    } else if (value == 'withdraw') {
                                      _showWithdrawSheet(pot);
                                    } else if (value == 'members') {
                                      _showMembersSheet(pot);
                                    } else if (value == 'report') {
                                      _showReportSheet(pot);
                                    } else if (value == 'share') {
                                      _showInviteMemberSheet(pot);
                                    } else if (value == 'edit') {
                                      _showEditPotSheet(pot);
                                    } else if (value == 'pause') {
                                      _changePotState(pot, 'PAUSED');
                                    } else if (value == 'activate') {
                                      _changePotState(pot, 'ACTIVE');
                                    } else if (value == 'archive') {
                                      _requestArchivePot(pot);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'contribute',
                                      child: Text(l10n.wealthContribute),
                                    ),
                                    PopupMenuItem(
                                      value: 'members',
                                      child: Text(l10n.wealthMembers),
                                    ),
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text(
                                        l10n.pick(
                                          en: 'Report',
                                          swText: 'Ripoti',
                                        ),
                                      ),
                                    ),
                                    if (canInvite)
                                      PopupMenuItem(
                                        value: 'share',
                                        child: Text(l10n.wealthInviteMember),
                                      ),
                                    if (canWithdraw)
                                      PopupMenuItem(
                                        value: 'withdraw',
                                        child: Text(l10n.wealthWithdraw),
                                      ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(l10n.commonEdit),
                                    ),
                                    PopupMenuItem(
                                      value: status == 'ACTIVE'
                                          ? 'pause'
                                          : 'activate',
                                      child: Text(
                                        status == 'ACTIVE'
                                            ? l10n.commonPause
                                            : l10n.commonActivate,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(l10n.commonArchive),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 7,
                                  color: _sharedPotAccent,
                                  backgroundColor: ui.cardMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metaChip(context, role),
                                _metaChip(context, accessModel),
                                _metaChip(context, status),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showMembersSheet(pot),
                                    icon: const Icon(
                                      Icons.group_outlined,
                                      size: 17,
                                    ),
                                    label: Text(l10n.wealthMembers),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: status == 'ACTIVE'
                                        ? () => _showContributeSheet(pot)
                                        : null,
                                    icon: const Icon(
                                      Icons.add_card_rounded,
                                      size: 17,
                                    ),
                                    label: Text(l10n.wealthContribute),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _sharedPotAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(BuildContext context, String label) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ui.cardMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ui.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: ui.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: ui.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ui.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: TextStyle(
            color: ui.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.title,
    required this.subtitle,
    required this.pending,
    this.onAccept,
    this.onReject,
  });

  final String title;
  final String subtitle;
  final bool pending;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: ui.textMuted, fontSize: 12, height: 1.35),
          ),
          if (pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: Text(sw ? 'Kataa' : 'Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: Text(sw ? 'Kubali' : 'Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Text(message, style: TextStyle(color: ui.textMuted, height: 1.45)),
    );
  }
}
