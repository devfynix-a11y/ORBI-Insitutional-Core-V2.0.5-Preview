import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';
import 'package:orbi_mobileapp/l10n/wealth_localizations.dart';

import '../../../core/theme/orbi_theme.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import '../../../core/widgets/orbi_async_feedback.dart';
import '../../../core/widgets/orbi_background.dart';
import '../../../core/widgets/orbi_brand_hero_card.dart';
import '../../../core/widgets/orbi_section_card.dart';
import '../../../core/widgets/orbi_state_card.dart';
import '../../../core/widgets/orbi_activity_card.dart';
import '../data/wealth_service.dart';
import 'widgets/wealth_hero_card.dart';

const Color _billReserveAccent = Color(0xFFE85D75);

class BillReservesScreen extends StatefulWidget {
  const BillReservesScreen({super.key});

  @override
  State<BillReservesScreen> createState() => _BillReservesScreenState();
}

class _BillReservesScreenState extends State<BillReservesScreen> {
  final WealthService _service = WealthService();

  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  String? _error;
  List<Map<String, dynamic>> _reserves = const [];
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  List<Map<String, dynamic>> get _visibleReserves => _reserves.where((reserve) {
    final status = (reserve['status'] ?? 'ACTIVE').toString().toUpperCase();
    return status != 'ARCHIVED';
  }).toList();

  List<Map<String, dynamic>> get _archivedReserves =>
      _reserves.where((reserve) {
        final status = (reserve['status'] ?? 'ACTIVE').toString().toUpperCase();
        return status == 'ARCHIVED';
      }).toList();

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
      final items = await _service.listBillReserves();
      if (!mounted) return;
      setState(() => _reserves = items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapBackendStatusMessage(
          e.toString(),
          sw: _l10n.isSw,
          fallback: _l10n.pick(
            en: 'Unable to load bill reserves.',
            swText: 'Imeshindikana kupakia bill reserves.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _setStatus(String message, OrbiStatusTone tone) {
    setState(() {
      _statusMessage = message;
      _statusTone = tone;
    });
  }

  Future<void> _showArchivedBinSheet() async {
    final ui = OrbiTheme.uiOf(context);
    final archived = _archivedReserves;
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
                _l10n.pick(en: 'Reserve bin', swText: 'Bin ya reserves'),
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: ui.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _l10n.pick(
                  en: 'Archived reserves appear here.',
                  swText: 'Reserves zilizohifadhiwa mbali zitaonekana hapa.',
                ),
                style: TextStyle(color: ui.textMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              if (archived.isEmpty)
                OrbiStateCard(
                  icon: Icons.inventory_2_outlined,
                  title: _l10n.pick(en: 'Bin is empty', swText: 'Bin iko tupu'),
                  message: _l10n.pick(
                    en: 'No archived bill reserve yet.',
                    swText: 'Hakuna bill reserve iliyohifadhiwa mbali bado.',
                  ),
                  accentColor: ui.textMuted,
                  accentBackground: ui.cardMuted,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: archived.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final reserve = archived[index];
                      final amount = _money(
                        reserve['reserve_amount'] ?? reserve['locked_balance'],
                        reserve['currency']?.toString(),
                      );
                      return OrbiSectionCard(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: ui.warningSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: ui.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (reserve['provider_name'] ??
                                            reserve['provider'] ??
                                            'Provider')
                                        .toString(),
                                    style: TextStyle(
                                      color: ui.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (reserve['bill_type'] ?? 'Bill').toString(),
                                    style: TextStyle(color: ui.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  amount,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await _changeReserveState(
                                      reserve,
                                      'ACTIVE',
                                    );
                                  },
                                  child: Text(
                                    _l10n.pick(
                                      en: 'Restore',
                                      swText: 'Rudisha',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final navigator = Navigator.of(
                                      sheetContext,
                                    );
                                    final confirmed =
                                        await _confirmPermanentDelete(reserve);
                                    if (confirmed != true) return;
                                    if (!mounted) return;
                                    navigator.pop();
                                    await _deleteReservePermanently(reserve);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: ui.warning,
                                  ),
                                  child: Text(
                                    _l10n.pick(
                                      en: 'Delete',
                                      swText: 'Futa kabisa',
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

  Future<bool?> _confirmPermanentDelete(Map<String, dynamic> reserve) {
    final name = (reserve['provider_name'] ?? reserve['provider'] ?? 'Reserve')
        .toString();
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _l10n.pick(
              en: 'Delete reserve permanently?',
              swText: 'Futa kabisa reserve?',
            ),
          ),
          content: Text(
            _l10n.pick(
              en: '$name will be removed permanently from the bin.',
              swText: '$name itaondolewa kabisa kutoka kwenye bin.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_l10n.pick(en: 'Cancel', swText: 'Ghairi')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_l10n.pick(en: 'Delete', swText: 'Futa kabisa')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteReservePermanently(Map<String, dynamic> reserve) async {
    final reserveId = (reserve['id'] ?? '').toString();
    if (reserveId.isEmpty) return;
    try {
      await _runBusy(
        _l10n.pick(en: 'Deleting reserve...', swText: 'Inafuta reserve...'),
        () => _service.deleteBillReserve(reserveId),
      );
      await _load();
      if (!mounted) return;
      _setStatus(
        _l10n.pick(
          en: 'Reserve deleted permanently.',
          swText: 'Reserve imefutwa kabisa.',
        ),
        OrbiStatusTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      _setStatus(
        mapBackendStatusMessage(
          e.toString(),
          sw: _l10n.isSw,
          fallback: _l10n.pick(
            en: 'Unable to delete the reserve permanently.',
            swText: 'Imeshindikana kufuta reserve kabisa.',
          ),
        ),
        OrbiStatusTone.error,
      );
    }
  }

  Future<void> _showCreateReserveSheet() async {
    final sw = _l10n.isSw;
    final providerController = TextEditingController();
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    final dueDayController = TextEditingController();
    String duePattern = 'MONTHLY';
    String reserveMode = 'FIXED';
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
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: bottomInset + 20,
              ),
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
                      sw ? 'Bill reserve mpya' : 'New bill reserve',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ui.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sw
                          ? 'Weka fedha tayari kabla ya tarehe ya bili.'
                          : 'Keep money ready before the bill is due.',
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
                      controller: providerController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _l10n.pick(
                          en: 'Provider',
                          swText: 'Mtoa huduma',
                        ),
                        hintText: sw ? 'Mfano TANESCO' : 'Example TANESCO',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: typeController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: sw ? 'Aina ya bili' : 'Bill type',
                        hintText: sw
                            ? 'Umeme, maji, shule'
                            : 'Power, water, school',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OrbiAmountField(
                      controller: amountController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountInputFormatter()],
                      label: sw ? 'Kiasi cha reserve' : 'Reserve amount',
                      currency: 'TZS',
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackFields = constraints.maxWidth < 380;
                        final modeField = DropdownButtonFormField<String>(
                          initialValue: reserveMode,
                          items: const [
                            DropdownMenuItem(
                              value: 'FIXED',
                              child: Text('Fixed'),
                            ),
                            DropdownMenuItem(
                              value: 'PERCENT',
                              child: Text('Percent'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) => setSheetState(
                                  () => reserveMode = value ?? reserveMode,
                                ),
                          decoration: InputDecoration(
                            labelText: sw ? 'Mode' : 'Mode',
                            isDense: true,
                          ),
                        );
                        final patternField = DropdownButtonFormField<String>(
                          initialValue: duePattern,
                          items: const [
                            DropdownMenuItem(
                              value: 'WEEKLY',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'MONTHLY',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'CUSTOM',
                              child: Text('Custom'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) => setSheetState(
                                  () => duePattern = value ?? duePattern,
                                ),
                          decoration: InputDecoration(
                            labelText: sw ? 'Mzunguko' : 'Pattern',
                            isDense: true,
                          ),
                        );
                        if (stackFields) {
                          return Column(
                            children: [
                              modeField,
                              const SizedBox(height: 10),
                              patternField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: modeField),
                            const SizedBox(width: 10),
                            Expanded(child: patternField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dueDayController,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: sw ? 'Siku ya malipo' : 'Due day',
                        hintText: sw ? 'Mfano 25' : 'Example 25',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final provider = providerController.text.trim();
                                final billType = typeController.text.trim();
                                final amount = AmountInputFormatter.tryParse(
                                  amountController.text,
                                );
                                final dueDay = int.tryParse(
                                  dueDayController.text.trim(),
                                );
                                if (provider.isEmpty ||
                                    billType.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  setSheetState(() {
                                    formError = sw
                                        ? 'Jaza mtoa huduma, aina ya bili, na kiasi sahihi.'
                                        : 'Enter provider, bill type, and a valid amount.';
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  await _service.createBillReserve({
                                    'provider_name': provider,
                                    'bill_type': billType,
                                    'reserve_amount': amount,
                                    'reserve_mode': reserveMode,
                                    'due_pattern': duePattern,
                                    'due_day': dueDay,
                                  });
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: sw,
                                      fallback: sw
                                          ? 'Imeshindikana kuunda bill reserve.'
                                          : 'Unable to create the bill reserve.',
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
                                  Text(sw ? 'Inahifadhi...' : 'Saving...'),
                                ],
                              )
                            : Text(sw ? 'Hifadhi reserve' : 'Save reserve'),
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

    providerController.dispose();
    typeController.dispose();
    amountController.dispose();
    dueDayController.dispose();

    if (created == true) {
      await _load();
      if (!mounted) return;
      _setStatus(
        sw ? 'Bill reserve imeundwa.' : 'Bill reserve created.',
        OrbiStatusTone.success,
      );
    }
  }

  Future<void> _showEditReserveSheet(Map<String, dynamic> reserve) async {
    final sw = _l10n.isSw;
    final providerController = TextEditingController(
      text: (reserve['provider_name'] ?? '').toString(),
    );
    final typeController = TextEditingController(
      text: (reserve['bill_type'] ?? '').toString(),
    );
    final amountController = TextEditingController(
      text: AmountInputFormatter.format(
        '${reserve['reserve_amount'] ?? reserve['locked_balance'] ?? ''}',
      ),
    );
    final dueDayController = TextEditingController(
      text: reserve['due_day']?.toString() ?? '',
    );
    String duePattern = (reserve['due_pattern'] ?? 'MONTHLY').toString();
    String reserveMode = (reserve['reserve_mode'] ?? 'FIXED').toString();
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
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: bottomInset + 20,
              ),
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
                      sw ? 'Hariri bill reserve' : 'Edit bill reserve',
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
                      controller: providerController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: sw ? 'Mtoa huduma' : 'Provider',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: typeController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: sw ? 'Aina ya bili' : 'Bill type',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OrbiAmountField(
                      controller: amountController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AmountInputFormatter()],
                      label: sw ? 'Kiasi cha reserve' : 'Reserve amount',
                      currency: (reserve['currency'] ?? 'TZS').toString(),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackFields = constraints.maxWidth < 380;
                        final modeField = DropdownButtonFormField<String>(
                          initialValue: reserveMode,
                          items: const [
                            DropdownMenuItem(
                              value: 'FIXED',
                              child: Text('Fixed'),
                            ),
                            DropdownMenuItem(
                              value: 'PERCENT',
                              child: Text('Percent'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) => setSheetState(
                                  () => reserveMode = value ?? reserveMode,
                                ),
                          decoration: const InputDecoration(
                            labelText: 'Mode',
                            isDense: true,
                          ),
                        );
                        final patternField = DropdownButtonFormField<String>(
                          initialValue: duePattern,
                          items: const [
                            DropdownMenuItem(
                              value: 'WEEKLY',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'MONTHLY',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'CUSTOM',
                              child: Text('Custom'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) => setSheetState(
                                  () => duePattern = value ?? duePattern,
                                ),
                          decoration: const InputDecoration(
                            labelText: 'Pattern',
                            isDense: true,
                          ),
                        );
                        if (stackFields) {
                          return Column(
                            children: [
                              modeField,
                              const SizedBox(height: 10),
                              patternField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: modeField),
                            const SizedBox(width: 10),
                            Expanded(child: patternField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dueDayController,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: sw ? 'Siku ya malipo' : 'Due day',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final provider = providerController.text.trim();
                                final billType = typeController.text.trim();
                                final amount = AmountInputFormatter.tryParse(
                                  amountController.text,
                                );
                                final dueDay = int.tryParse(
                                  dueDayController.text.trim(),
                                );
                                if (provider.isEmpty ||
                                    billType.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  setSheetState(() {
                                    formError = sw
                                        ? 'Jaza mtoa huduma, aina ya bili, na kiasi sahihi.'
                                        : 'Enter provider, bill type, and a valid amount.';
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  submitting = true;
                                  formError = null;
                                });
                                try {
                                  await _service.updateBillReserve(
                                    (reserve['id'] ?? '').toString(),
                                    {
                                      'provider_name': provider,
                                      'bill_type': billType,
                                      'reserve_amount': amount,
                                      'reserve_mode': reserveMode,
                                      'due_pattern': duePattern,
                                      'due_day': dueDay,
                                    },
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop(true);
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    formError = mapBackendStatusMessage(
                                      e.toString(),
                                      sw: sw,
                                      fallback: sw
                                          ? 'Imeshindikana kusasisha reserve.'
                                          : 'Unable to update the reserve.',
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
                                  Text(sw ? 'Inahifadhi...' : 'Saving...'),
                                ],
                              )
                            : Text(sw ? 'Hifadhi mabadiliko' : 'Save changes'),
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

    providerController.dispose();
    typeController.dispose();
    amountController.dispose();
    dueDayController.dispose();

    if (updated == true) {
      await _load();
      if (!mounted) return;
      _setStatus(
        sw ? 'Bill reserve imesasishwa.' : 'Bill reserve updated.',
        OrbiStatusTone.success,
      );
    }
  }

  Future<void> _changeReserveState(
    Map<String, dynamic> reserve,
    String nextStatus,
  ) async {
    await _runBusy(
      _l10n.pick(en: 'Updating status...', swText: 'Inasasisha hali...'),
      () => _service.updateBillReserve((reserve['id'] ?? '').toString(), {
        'status': nextStatus,
        'is_active': nextStatus == 'ACTIVE',
      }),
    );
    await _load();
    if (!mounted) return;
    _setStatus(
      _l10n.pick(
        en: 'Reserve status updated.',
        swText: 'Hali ya reserve imesasishwa.',
      ),
      OrbiStatusTone.success,
    );
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

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: _billReserveAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _l10n.pick(en: 'Bill Reserves', swText: 'Bill Reserves'),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'bin') {
                _showArchivedBinSheet();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'bin',
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(_l10n.pick(en: 'Bin', swText: 'Bin')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateReserveSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text(_l10n.pick(en: 'New reserve', swText: 'Reserve mpya')),
        backgroundColor: _billReserveAccent,
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
                  icon: Icons.receipt_long_outlined,
                  title: _l10n.pick(
                    en: 'Bill Reserves',
                    swText: 'Bill Reserves',
                  ),
                  subtitle: _l10n.pick(
                    en: 'Track, review, and open reserve details when needed.',
                    swText:
                        'Fuatilia, hakiki, na fungua details za reserve ukihitaji.',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrbiHeroMetricChip(
                        icon: Icons.receipt_long_outlined,
                        label: _l10n.pick(
                          en: 'Visible',
                          swText: 'Zinazoonekana',
                        ),
                        value: '${_visibleReserves.length}',
                      ),
                      OrbiHeroMetricChip(
                        icon: Icons.inventory_2_outlined,
                        label: _l10n.pick(
                          en: 'Archived',
                          swText: 'Zilizohifadhiwa',
                        ),
                        value: '${_archivedReserves.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                    title: _l10n.pick(
                      en: 'Bill reserves could not be loaded',
                      swText: 'Bill reserves hazikupatikana',
                    ),
                    message: _error,
                    accentColor: ui.warning,
                    accentBackground: ui.warningSoft,
                    action: TextButton(
                      onPressed: _load,
                      child: Text(
                        _l10n.pick(en: 'Try again', swText: 'Jaribu tena'),
                      ),
                    ),
                  )
                else if (_visibleReserves.isEmpty)
                  OrbiStateCard(
                    icon: Icons.savings_outlined,
                    title: _l10n.pick(
                      en: 'No bill reserve yet',
                      swText: 'Hakuna bill reserve bado',
                    ),
                    message: _l10n.pick(
                      en: 'Start with your biggest or most frequent bill.',
                      swText: 'Anza na bili kubwa au ya kila mwezi.',
                    ),
                    accentColor: _billReserveAccent,
                    accentBackground: _billReserveAccent.withValues(
                      alpha: 0.12,
                    ),
                    action: TextButton(
                      onPressed: _showCreateReserveSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: _billReserveAccent,
                      ),
                      child: Text(
                        _l10n.pick(
                          en: 'Create reserve',
                          swText: 'Unda reserve',
                        ),
                      ),
                    ),
                  )
                else
                  ..._visibleReserves.map((reserve) {
                    final amount = _money(
                      reserve['reserve_amount'] ?? reserve['locked_balance'],
                      reserve['currency']?.toString(),
                    );
                    final locked = _money(
                      reserve['locked_balance'] ?? reserve['reserve_amount'],
                      reserve['currency']?.toString(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrbiActivityCard(
                        accent: _billReserveAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _billReserveAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    color: _billReserveAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (reserve['provider_name'] ??
                                                reserve['provider'] ??
                                                'Provider')
                                            .toString(),
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (reserve['bill_type'] ?? 'Bill')
                                            .toString(),
                                        style: TextStyle(color: ui.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  amount,
                                  style: TextStyle(
                                    color: ui.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditReserveSheet(reserve);
                                    } else if (value == 'pause') {
                                      _changeReserveState(reserve, 'PAUSED');
                                    } else if (value == 'activate') {
                                      _changeReserveState(reserve, 'ACTIVE');
                                    } else if (value == 'archive') {
                                      _changeReserveState(reserve, 'ARCHIVED');
                                    }
                                  },
                                  itemBuilder: (context) {
                                    final status =
                                        (reserve['status'] ?? 'ACTIVE')
                                            .toString()
                                            .toUpperCase();
                                    return [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                          _l10n.pick(
                                            en: 'Edit',
                                            swText: 'Hariri',
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: status == 'ACTIVE'
                                            ? 'pause'
                                            : 'activate',
                                        child: Text(
                                          status == 'ACTIVE'
                                              ? (_l10n.pick(
                                                  en: 'Pause',
                                                  swText: 'Sitisha',
                                                ))
                                              : (_l10n.pick(
                                                  en: 'Activate',
                                                  swText: 'Washa tena',
                                                )),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text(
                                          _l10n.pick(
                                            en: 'Archive',
                                            swText: 'Hifadhi mbali',
                                          ),
                                        ),
                                      ),
                                    ];
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metaChip(
                                  context,
                                  _l10n.pick(
                                    en: 'Locked $locked',
                                    swText: 'Imefungwa $locked',
                                  ),
                                ),
                                _metaChip(
                                  context,
                                  _l10n.isSw
                                      ? 'Kila ${(reserve['due_pattern'] ?? 'MONTHLY').toString().toLowerCase()}'
                                      : 'Every ${(reserve['due_pattern'] ?? 'MONTHLY').toString().toLowerCase()}',
                                ),
                                if (reserve['due_day'] != null)
                                  _metaChip(
                                    context,
                                    _l10n.isSw
                                        ? 'Siku ${reserve['due_day']}'
                                        : 'Day ${reserve['due_day']}',
                                  ),
                                _metaChip(
                                  context,
                                  (reserve['status'] ?? 'ACTIVE').toString(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
