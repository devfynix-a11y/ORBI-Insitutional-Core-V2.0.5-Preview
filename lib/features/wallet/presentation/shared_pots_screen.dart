import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:orbi_mobileapp/l10n/wealth_localizations.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_activity_card.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../data/wealth_service.dart';
import 'widgets/invitee_lookup_card.dart';

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
      final items = await _service.listSharedPots();
      if (!mounted) return;
      setState(() => _pots = items);
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
                      l10n.wealthNewSharedPot,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.wealthSharedGoalShort,
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
                        labelText: l10n.wealthPotName,
                        hintText: l10n.wealthPotNameHint,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purposeController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.wealthPurpose,
                        hintText: l10n.wealthPurposeHint,
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
                      items: const [
                        DropdownMenuItem(
                          value: 'INVITE',
                          child: Text('Invite only'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text('Private'),
                        ),
                        DropdownMenuItem(
                          value: 'ORG',
                          child: Text('Organisation'),
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
                            : Text(l10n.wealthSavePot),
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
                      l10n.wealthEditSharedPot,
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
                        labelText: l10n.wealthPotName,
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
                      items: const [
                        DropdownMenuItem(
                          value: 'INVITE',
                          child: Text('Invite only'),
                        ),
                        DropdownMenuItem(
                          value: 'PRIVATE',
                          child: Text('Private'),
                        ),
                        DropdownMenuItem(
                          value: 'ORG',
                          child: Text('Organisation'),
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
                            : Text(l10n.wealthSaveChanges),
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
                      l10n.wealthContributeToSharedPot,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.wealthContributeToPotHelp,
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
                            : Text(l10n.wealthContributeNow),
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
    String? formError;
    bool submitting = false;
    final withdrawn = await showModalBottomSheet<bool>(
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
                      l10n.wealthWithdrawFromSharedPot,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.wealthWithdrawFromPotHelp,
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
                                  await _service.withdrawFromSharedPot(
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
                            : Text(l10n.wealthWithdrawNow),
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

    if (withdrawn == true) {
      await _load();
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.wealthFundsWithdrawn;
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
                        items: const [
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'CONTRIBUTOR',
                            child: Text('Contributor'),
                          ),
                          DropdownMenuItem(
                            value: 'VIEWER',
                            child: Text('Viewer'),
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
                                    await _service.addSharedPotMember(
                                      (pot['id'] ?? '').toString(),
                                      {'identifier': identifier, 'role': role},
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
                l10n.wealthPotMembers,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.wealthPotMembersHelp,
                style: TextStyle(color: ui.textMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                OrbiStateCard(
                  icon: Icons.group_off_rounded,
                  title: l10n.wealthNoMembersYet,
                  message: l10n.wealthSendFirstInvite,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, color: _sharedPotAccent, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(l10n.wealthSharedPotsTitle)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePotSheet,
        icon: const Icon(Icons.group_add_rounded),
        label: Text(l10n.wealthNewPot),
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
                OrbiActivityCard(
                  accent: _sharedPotAccent,
                  hero: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _sharedPotAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.groups_2_rounded,
                              color: _sharedPotAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.wealthSharedMoneyOrganized,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: ui.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.wealthSharedMoneyHelp,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ui.textMuted,
                                    fontSize: 12.5,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                else if (_pots.isEmpty)
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
                          l10n.wealthSharedPotsTitle,
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _metaChip(
                        context,
                        '${_pots.length} ${_pots.length == 1 ? 'pot' : 'pots'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._pots.map((pot) {
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
                                        (pot['name'] ?? 'Shared Pot')
                                            .toString(),
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
                                        (pot['purpose'] ?? 'Shared pot saving')
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
                                    } else if (value == 'share') {
                                      _showInviteMemberSheet(pot);
                                    } else if (value == 'edit') {
                                      _showEditPotSheet(pot);
                                    } else if (value == 'pause') {
                                      _changePotState(pot, 'PAUSED');
                                    } else if (value == 'activate') {
                                      _changePotState(pot, 'ACTIVE');
                                    } else if (value == 'archive') {
                                      _changePotState(pot, 'ARCHIVED');
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
