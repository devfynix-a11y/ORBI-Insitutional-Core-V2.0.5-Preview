import 'dart:async';

import 'package:flutter/material.dart';

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
import '../../../core/widgets/orbi_empty_state.dart';
import '../data/wealth_service.dart';
import 'widgets/invitee_lookup_card.dart';
import 'widgets/wealth_hero_card.dart';

const Color _sharedBudgetAccent = Color(0xFF2563EB);

class SharedBudgetsScreen extends StatefulWidget {
  const SharedBudgetsScreen({super.key});

  @override
  State<SharedBudgetsScreen> createState() => _SharedBudgetsScreenState();
}

class _SharedBudgetsScreenState extends State<SharedBudgetsScreen> {
  final WealthService _service = WealthService();

  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;
  String? _statusMessage;
  OrbiStatusTone _statusTone = OrbiStatusTone.info;
  List<Map<String, dynamic>> _budgets = const [];
  List<Map<String, dynamic>> _invitations = const [];

  bool get _sw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  String _text(String en, String sw) => _sw ? sw : en;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait([
        _service.listSharedBudgets(),
        _service.listMySharedBudgetInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _budgets = results[0];
        _invitations = results[1];
      });
    } catch (error) {
      _showStatus(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showStatus(String raw, {required bool error}) {
    if (!mounted) return;
    final fallback = error
        ? _text(
            'This shared budget request could not be completed. Please refresh and try again.',
            'Ombi la shared budget halikukamilika. Tafadhali pakia upya kisha jaribu tena.',
          )
        : raw;
    setState(() {
      _statusMessage = mapBackendStatusMessage(
        raw,
        sw: _sw,
        fallback: fallback,
      );
      _statusTone = error ? OrbiStatusTone.error : OrbiStatusTone.success;
    });
  }

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _busyMessage = message;
        _statusMessage = null;
      });
    }
    try {
      await action();
    } catch (error) {
      _showStatus(error.toString(), error: true);
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
    if (mounted) {
      setState(() {
        _busy = true;
        _busyMessage = message;
        _statusMessage = null;
      });
    }
    try {
      return await loader();
    } catch (error) {
      _showStatus(error.toString(), error: true);
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

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
  }

  String _money(dynamic amount, String currency) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return formatAppBalanceAmount(
      _asDouble(amount),
      currency,
      locale: localeTag,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Map<String, dynamic> _userFrom(
    Map<String, dynamic> row, {
    List<String> keys = const ['users', 'user', 'invitee', 'inviter'],
  }) {
    for (final key in keys) {
      final value = _asMap(row[key]);
      if (value.isNotEmpty) return value;
    }
    return const {};
  }

  String _personLabel(
    Map<String, dynamic> row, {
    String? fallback,
    List<String> userKeys = const ['users', 'user', 'invitee', 'inviter'],
  }) {
    final user = _userFrom(row, keys: userKeys);
    final values = [
      user['full_name'],
      user['display_name'],
      user['email'],
      user['phone'],
      row['full_name'],
      row['display_name'],
      row['email'],
      row['phone'],
      row['invitee_identifier'],
      row['identifier'],
      fallback,
    ];
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return _text('Unknown member', 'Mwanachama hajulikani');
  }

  String _roleLabel(String value) {
    switch (value.toUpperCase()) {
      case 'OWNER':
        return _text('Owner', 'Mmiliki');
      case 'MANAGER':
        return _text('Manager', 'Meneja');
      case 'VIEWER':
        return _text('Viewer', 'Mtazamaji');
      default:
        return _text('Spender', 'Mtumiaji');
    }
  }

  String _approvalLabel(String value) {
    return value.toUpperCase() == 'REVIEW'
        ? _text('Needs approval', 'Inahitaji idhini')
        : _text('Auto spend', 'Matumizi ya moja kwa moja');
  }

  String _periodLabel(String value) {
    switch (value.toUpperCase()) {
      case 'WEEKLY':
        return _text('Weekly', 'Kila wiki');
      case 'CUSTOM':
        return _text('Custom', 'Maalum');
      default:
        return _text('Monthly', 'Kila mwezi');
    }
  }

  String _formatDate(dynamic raw) {
    final date = DateTime.tryParse('${raw ?? ''}');
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openBudgetForm({Map<String, dynamic>? budget}) async {
    final isEdit = budget != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: budget?['name']?.toString() ?? '',
    );
    final purposeController = TextEditingController(
      text: budget?['purpose']?.toString() ?? '',
    );
    final limitController = TextEditingController(
      text: budget == null
          ? ''
          : AmountInputFormatter.format('${_asDouble(budget['budget_limit'])}'),
    );
    var period = (budget?['period_type'] ?? 'MONTHLY').toString().toUpperCase();
    var approvalMode = (budget?['approval_mode'] ?? 'AUTO')
        .toString()
        .toUpperCase();
    var status = (budget?['status'] ?? 'ACTIVE').toString().toUpperCase();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false) || submitting) {
                return;
              }
              setSheetState(() => submitting = true);
              try {
                final payload = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'purpose': purposeController.text.trim().isEmpty
                      ? null
                      : purposeController.text.trim(),
                  'budget_limit': AmountInputFormatter.tryParse(
                    limitController.text,
                  )!,
                  'period_type': period,
                  'approval_mode': approvalMode,
                  if (isEdit) 'status': status,
                };
                if (isEdit) {
                  await _service.updateSharedBudget(
                    budget['id'].toString(),
                    payload,
                  );
                } else {
                  await _service.createSharedBudget(payload);
                }
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                _showStatus(
                  _text(
                    isEdit
                        ? 'Shared budget updated.'
                        : 'Shared budget created.',
                    isEdit
                        ? 'Shared budget imesasishwa.'
                        : 'Shared budget imeundwa.',
                  ),
                  error: false,
                );
                await _refresh();
              } catch (error) {
                _showStatus(error.toString(), error: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => submitting = false);
                }
              }
            }

            return _BottomSheetFrame(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetTitle(
                      title: _text(
                        isEdit ? 'Edit shared budget' : 'New shared budget',
                        isEdit ? 'Hariri shared budget' : 'Shared budget mpya',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: _text('Budget name', 'Jina la budget'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? _text(
                              'Enter a budget name.',
                              'Weka jina la budget.',
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: purposeController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _text('Purpose', 'Lengo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrbiAmountField(
                      controller: limitController,
                      inputFormatters: [AmountInputFormatter()],
                      label: _text('Budget limit', 'Kikomo cha budget'),
                      currency: (budget?['currency'] ?? 'TZS').toString(),
                      validator: (value) =>
                          (AmountInputFormatter.tryParse(value ?? '') ?? 0) <= 0
                          ? _text('Enter a valid amount.', 'Weka kiasi sahihi.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: period,
                      decoration: InputDecoration(
                        labelText: _text('Period', 'Muda'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'WEEKLY',
                          child: Text(_periodLabel('WEEKLY')),
                        ),
                        DropdownMenuItem(
                          value: 'MONTHLY',
                          child: Text(_periodLabel('MONTHLY')),
                        ),
                        DropdownMenuItem(
                          value: 'CUSTOM',
                          child: Text(_periodLabel('CUSTOM')),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => period = value ?? 'MONTHLY'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: approvalMode,
                      decoration: InputDecoration(
                        labelText: _text('Spend mode', 'Namna ya matumizi'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'AUTO',
                          child: Text(_approvalLabel('AUTO')),
                        ),
                        DropdownMenuItem(
                          value: 'REVIEW',
                          child: Text(_approvalLabel('REVIEW')),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => approvalMode = value ?? 'AUTO'),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _text('Status', 'Hali'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'ACTIVE',
                            child: Text(_text('Active', 'Hai')),
                          ),
                          DropdownMenuItem(
                            value: 'PAUSED',
                            child: Text(_text('Paused', 'Imesimama')),
                          ),
                          DropdownMenuItem(
                            value: 'ARCHIVED',
                            child: Text(_text('Archived', 'Imehifadhiwa')),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => status = value ?? 'ACTIVE'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting ? null : save,
                        child: Text(
                          submitting
                              ? _text('Saving...', 'Inahifadhi...')
                              : _text('Save budget', 'Hifadhi budget'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInviteSheet(Map<String, dynamic> budget) async {
    final formKey = GlobalKey<FormState>();
    final identifierController = TextEditingController();
    final messageController = TextEditingController();
    final memberLimitController = TextEditingController();
    Timer? lookupDebounce;
    var lookupGeneration = 0;
    var lookupLoading = false;
    String? lookupError;
    Map<String, dynamic>? lookupPreview;
    var role = 'SPENDER';
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                  lookupError = _text(
                    'Enter at least 3 characters.',
                    'Weka angalau herufi/tarakimu 3.',
                  );
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
                          ? _text(
                              'We could not find that ORBI user.',
                              'Hatujampata mtumiaji huyo wa ORBI.',
                            )
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
                        sw: _sw,
                        fallback: _text(
                          'User lookup is unavailable right now.',
                          'Uhakiki wa mtumiaji haupatikani kwa sasa.',
                        ),
                      );
                    });
                  }
                },
              );
            }

            Future<void> sendInvite() async {
              if (!(formKey.currentState?.validate() ?? false) || submitting) {
                return;
              }
              if (lookupPreview == null) {
                setSheetState(() {
                  lookupError = _text(
                    'Confirm the ORBI user before sending the invitation.',
                    'Hakiki kwanza mtumiaji wa ORBI kabla ya kutuma mwaliko.',
                  );
                });
                return;
              }
              setSheetState(() => submitting = true);
              try {
                final identifier = _service.resolveInviteeIdentifier(
                  lookupPreview,
                  fallback: identifierController.text,
                );
                final payload = _service.buildInvitePayload(
                  invitee: lookupPreview,
                  fallback: identifier,
                  role: role,
                  extra: {
                    if ((AmountInputFormatter.tryParse(
                              memberLimitController.text,
                            ) ??
                            0) >
                        0)
                      'member_limit': AmountInputFormatter.tryParse(
                        memberLimitController.text,
                      ),
                    if (messageController.text.trim().isNotEmpty)
                      'message': messageController.text.trim(),
                  },
                );
                await _service.addSharedBudgetInvitation(
                  budget['id'].toString(),
                  payload,
                );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                _showStatus(
                  _text('Invitation sent.', 'Mwaliko umetumwa.'),
                  error: false,
                );
                await _refresh();
              } catch (error) {
                _showStatus(error.toString(), error: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => submitting = false);
                }
              }
            }

            return _BottomSheetFrame(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetTitle(
                      title: _text('Invite member', 'Alika mwanachama'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: identifierController,
                      decoration: InputDecoration(
                        labelText: _text(
                          'Phone, email, or ORBI ID',
                          'Simu, barua pepe, au ORBI ID',
                        ),
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
                      validator: (value) =>
                          value == null || value.trim().length < 3
                          ? _text(
                              'Enter a valid phone, email, or ORBI ID.',
                              'Weka simu, barua pepe, au ORBI ID sahihi.',
                            )
                          : null,
                    ),
                    if (lookupError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        lookupError!,
                        style: TextStyle(
                          color: OrbiTheme.uiOf(context).warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (lookupPreview != null) ...[
                      const SizedBox(height: 10),
                      InviteeLookupCard(
                        data: lookupPreview!,
                        accent: _sharedBudgetAccent,
                        isSw: _sw,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(
                        labelText: _text('Role', 'Role'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'MANAGER',
                          child: Text(_roleLabel('MANAGER')),
                        ),
                        DropdownMenuItem(
                          value: 'SPENDER',
                          child: Text(_roleLabel('SPENDER')),
                        ),
                        DropdownMenuItem(
                          value: 'VIEWER',
                          child: Text(_roleLabel('VIEWER')),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => role = value ?? 'SPENDER'),
                    ),
                    const SizedBox(height: 12),
                    OrbiAmountField(
                      controller: memberLimitController,
                      inputFormatters: [AmountInputFormatter()],
                      label: _text(
                        'Member spend limit',
                        'Kikomo cha matumizi ya mwanachama',
                      ),
                      currency: (budget['currency'] ?? 'TZS').toString(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _text('Message', 'Ujumbe'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            submitting || lookupLoading || lookupPreview == null
                            ? null
                            : sendInvite,
                        child: Text(
                          submitting
                              ? _text('Sending...', 'Inatuma...')
                              : _text('Send invitation', 'Tuma mwaliko'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    lookupDebounce?.cancel();
  }

  Future<void> _openSpendSheet(Map<String, dynamic> budget) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final providerController = TextEditingController();
    final categoryController = TextEditingController();
    final referenceController = TextEditingController();
    final descriptionController = TextEditingController();
    var spendType = 'MERCHANT_PAYMENT';
    var busy = false;
    Map<String, dynamic>? preview;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Map<String, dynamic> payload() => {
              'amount': AmountInputFormatter.tryParse(amountController.text)!,
              'provider': providerController.text.trim(),
              'type': spendType,
              if (categoryController.text.trim().isNotEmpty)
                'bill_category': categoryController.text.trim(),
              if (referenceController.text.trim().isNotEmpty)
                'reference': referenceController.text.trim(),
              if (descriptionController.text.trim().isNotEmpty)
                'description': descriptionController.text.trim(),
            };

            Future<void> previewSpend() async {
              if (!(formKey.currentState?.validate() ?? false) || busy) return;
              setSheetState(() => busy = true);
              try {
                final result = await _service.previewSharedBudgetSpend(
                  budget['id'].toString(),
                  payload(),
                );
                if (sheetContext.mounted) {
                  setSheetState(() => preview = result);
                }
              } catch (error) {
                _showStatus(error.toString(), error: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => busy = false);
                }
              }
            }

            Future<void> settleSpend() async {
              if (!(formKey.currentState?.validate() ?? false) || busy) return;
              setSheetState(() => busy = true);
              try {
                final result = await _service.settleSharedBudgetSpend(
                  budget['id'].toString(),
                  payload(),
                );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (result['requires_approval'] == true ||
                    result['approval'] != null) {
                  _showStatus(
                    _text(
                      'Spend request sent for approval.',
                      'Ombi la matumizi limetumwa kwa idhini.',
                    ),
                    error: false,
                  );
                } else {
                  _showStatus(
                    _text(
                      'Budget spend completed.',
                      'Matumizi ya budget yamekamilika.',
                    ),
                    error: false,
                  );
                }
                await _refresh();
              } catch (error) {
                _showStatus(error.toString(), error: true);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => busy = false);
                }
              }
            }

            final previewBudget = preview?['budget'] is Map<String, dynamic>
                ? preview!['budget'] as Map<String, dynamic>
                : (preview?['budget'] is Map
                      ? Map<String, dynamic>.from(preview!['budget'] as Map)
                      : null);
            final currency = (budget['currency'] ?? 'TZS').toString();

            return _BottomSheetFrame(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetTitle(
                      title: _text(
                        'Spend from shared budget',
                        'Tumia kutoka shared budget',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: spendType,
                      decoration: InputDecoration(
                        labelText: _text('Spend type', 'Aina ya matumizi'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'MERCHANT_PAYMENT',
                          child: Text(
                            _text('Merchant payment', 'Malipo ya merchant'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'BILL_PAYMENT',
                          child: Text(_text('Bill payment', 'Malipo ya bili')),
                        ),
                        DropdownMenuItem(
                          value: 'EXTERNAL_PAYMENT',
                          child: Text(
                            _text('External payment', 'Malipo ya nje'),
                          ),
                        ),
                      ],
                      onChanged: (value) => setSheetState(
                        () => spendType = value ?? 'MERCHANT_PAYMENT',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrbiAmountField(
                      controller: amountController,
                      inputFormatters: [AmountInputFormatter()],
                      label: _text('Amount', 'Kiasi'),
                      currency: (budget['currency'] ?? 'TZS').toString(),
                      validator: (value) =>
                          (AmountInputFormatter.tryParse(value ?? '') ?? 0) <= 0
                          ? _text('Enter a valid amount.', 'Weka kiasi sahihi.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: providerController,
                      decoration: InputDecoration(
                        labelText: _text(
                          'Provider or merchant',
                          'Provider au merchant',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? _text(
                              'Enter provider or merchant.',
                              'Weka provider au merchant.',
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: _text('Category', 'Kundi'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText: _text('Reference', 'Rejea'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _text('Description', 'Maelezo'),
                      ),
                    ),
                    if (previewBudget != null) ...[
                      const SizedBox(height: 16),
                      _PreviewBox(
                        title: _text('Spend preview', 'Muhtasari wa matumizi'),
                        lines: [
                          '${_text('Remaining after spend', 'Kitakachobaki baada ya matumizi')}: ${_money(previewBudget['remaining_amount'], currency)}',
                          if (preview?['member'] is Map &&
                              (preview!['member']
                                      as Map)['remaining_member_limit'] !=
                                  null)
                            '${_text('Member limit remaining', 'Kikomo cha mwanachama kitakachobaki')}: ${_money((preview!['member'] as Map)['remaining_member_limit'], currency)}',
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : previewSpend,
                            child: Text(_text('Preview', 'Hakiki')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : settleSpend,
                            child: Text(
                              _text('Confirm spend', 'Thibitisha matumizi'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showMembers(Map<String, dynamic> budget) async {
    final members = await _loadBusyData(
      _text('Loading members...', 'Inapakua wanachama...'),
      () => _service.listSharedBudgetMembers(budget['id'].toString()),
    );
    if (!mounted || members == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title: _text('Members', 'Wanachama')),
            const SizedBox(height: 16),
            if (members.isEmpty)
              _InlineEmpty(
                message: _text('No members yet.', 'Hakuna wanachama bado.'),
              )
            else
              ...members.map((member) {
                final label = _personLabel(member);
                return _InfoRow(
                  title: label,
                  subtitle:
                      '${_roleLabel((member['role'] ?? 'SPENDER').toString())} • ${_text('Spent', 'Ametumia')}: ${_money(member['spent_amount'], (budget['currency'] ?? 'TZS').toString())}',
                  trailing: member['member_limit'] == null
                      ? null
                      : _money(
                          member['member_limit'],
                          (budget['currency'] ?? 'TZS').toString(),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showReport(Map<String, dynamic> budget) async {
    final budgetId = (budget['id'] ?? '').toString();
    if (budgetId.isEmpty) return;
    await OrbiResourceReportPrinter.openReportSheet(
      context,
      title: _text('Mezani report', 'Ripoti ya Mezani'),
      subtitle: (budget['name'] ?? 'Mezani').toString(),
      filePrefix: 'orbi_mezani_report',
      loadReport: (range) =>
          _service.getSharedBudgetReport(budgetId, range: range),
    );
  }

  Future<void> _showActivity(Map<String, dynamic> budget) async {
    final rows = await _loadBusyData(
      _text('Loading activity...', 'Inapakua shughuli...'),
      () => _service.listSharedBudgetTransactions(budget['id'].toString()),
    );
    if (!mounted || rows == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title: _text('Activity', 'Shughuli')),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              _InlineEmpty(
                message: _text(
                  'No spending activity yet.',
                  'Hakuna shughuli za matumizi bado.',
                ),
              )
            else
              ...rows.map((row) {
                final spender = _personLabel(row);
                final provider =
                    (row['provider'] ??
                            row['merchant_name'] ??
                            _text('Unknown provider', 'Provider hajulikani'))
                        .toString();
                return _InfoRow(
                  title:
                      '${_money(row['amount'], (row['currency'] ?? budget['currency'] ?? 'TZS').toString())} • $provider',
                  subtitle:
                      '$spender • ${(row['category'] ?? 'SPEND').toString()}',
                  trailing: _formatDate(row['created_at']),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetInvites(Map<String, dynamic> budget) async {
    final rows = await _loadBusyData(
      _text('Loading invitations...', 'Inapakua mialiko...'),
      () => _service.listSharedBudgetInvitations(budget['id'].toString()),
    );
    if (!mounted || rows == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title: _text('Invitations', 'Mialiko')),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              _InlineEmpty(
                message: _text('No invitations yet.', 'Hakuna mialiko bado.'),
              )
            else
              ...rows.map((row) {
                final invitee = _personLabel(row);
                return _InfoRow(
                  title: invitee,
                  subtitle:
                      '${_roleLabel((row['role'] ?? 'SPENDER').toString())} • ${(row['status'] ?? 'PENDING').toString()}',
                  trailing: _formatDate(row['created_at']),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetApprovals(Map<String, dynamic> budget) async {
    final rows = await _loadBusyData(
      _text('Loading approvals...', 'Inapakua approvals...'),
      () => _service.listSharedBudgetApprovals(budget['id'].toString()),
    );
    if (!mounted || rows == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title: _text('Approval requests', 'Maombi ya idhini')),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              _InlineEmpty(
                message: _text(
                  'No approval requests right now.',
                  'Hakuna maombi ya idhini kwa sasa.',
                ),
              )
            else
              ...rows.map((row) {
                final requesterLabel = _personLabel(row);
                final reviewer = _asMap(row['reviewer']);
                final status = (row['status'] ?? 'PENDING')
                    .toString()
                    .toUpperCase();
                final pending = status == 'PENDING';
                final currency =
                    (row['currency'] ?? budget['currency'] ?? 'TZS').toString();
                final detailBits = <String>[
                  _money(row['amount'], currency),
                  if ((row['provider'] ?? '').toString().isNotEmpty)
                    row['provider'].toString(),
                  if ((row['bill_category'] ?? '').toString().isNotEmpty)
                    row['bill_category'].toString(),
                  if ((row['reference'] ?? '').toString().isNotEmpty)
                    'Ref: ${row['reference']}',
                ];
                final subtitleBits = <String>[
                  requesterLabel,
                  detailBits.join(' • '),
                  if ((row['note'] ?? '').toString().isNotEmpty)
                    row['note'].toString(),
                  if (!pending && reviewer.isNotEmpty)
                    '${_text('Reviewed by', 'Imekaguliwa na')} ${(reviewer['full_name'] ?? reviewer['email'] ?? reviewer['phone'] ?? '').toString()}',
                ];
                return _ApprovalRow(
                  title: _text(
                    pending
                        ? 'Pending approval'
                        : 'Approval ${status.toLowerCase()}',
                    pending
                        ? 'Idhini inasubiri'
                        : 'Idhini ${status.toLowerCase()}',
                  ),
                  subtitle: subtitleBits
                      .where((item) => item.trim().isNotEmpty)
                      .join('\n'),
                  trailing: _formatDate(row['created_at']),
                  pending: pending,
                  onApprove: () async {
                    Navigator.of(context).pop();
                    await _respondToApproval(row['id'].toString(), 'APPROVE');
                  },
                  onReject: () async {
                    Navigator.of(context).pop();
                    await _respondToApproval(row['id'].toString(), 'REJECT');
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showInbox() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(
              title: _text('Shared budget inbox', 'Inbox ya shared budget'),
            ),
            const SizedBox(height: 16),
            if (_invitations.isEmpty)
              _InlineEmpty(
                message: _text(
                  'No invitations right now.',
                  'Hakuna mialiko kwa sasa.',
                ),
              )
            else
              ..._invitations.map((invite) {
                final budget = invite['shared_budgets'] is Map
                    ? Map<String, dynamic>.from(invite['shared_budgets'] as Map)
                    : const <String, dynamic>{};
                final pending =
                    (invite['status'] ?? '').toString().toUpperCase() ==
                    'PENDING';
                return _InviteRow(
                  title:
                      (budget['name'] ??
                              _text('Shared budget', 'Shared budget'))
                          .toString(),
                  subtitle:
                      '${_roleLabel((invite['role'] ?? 'SPENDER').toString())} • ${(invite['status'] ?? 'PENDING').toString()}',
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
    await _runBusy(_text('Saving response...', 'Inahifadhi jibu...'), () async {
      await _service.respondToSharedBudgetInvitation(id, {'action': action});
      _showStatus(
        _text(
          action == 'ACCEPT' ? 'Invitation accepted.' : 'Invitation rejected.',
          action == 'ACCEPT' ? 'Mwaliko umekubaliwa.' : 'Mwaliko umekataliwa.',
        ),
        error: false,
      );
      await _refresh();
    });
  }

  Future<void> _respondToApproval(String id, String action) async {
    await _runBusy(
      _text('Saving approval...', 'Inahifadhi idhini...'),
      () async {
        await _service.respondToSharedBudgetApproval(id, {'action': action});
        _showStatus(
          _text(
            action == 'APPROVE'
                ? 'Spend request approved.'
                : 'Spend request rejected.',
            action == 'APPROVE'
                ? 'Ombi la matumizi limekubaliwa.'
                : 'Ombi la matumizi limekataliwa.',
          ),
          error: false,
        );
        await _refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    final pendingInvites = _invitations
        .where(
          (item) =>
              (item['status'] ?? '').toString().toUpperCase() == 'PENDING',
        )
        .length;
    return OrbiLoadingOverlay(
      loading: _busy,
      message: _busyMessage,
      statusMessage: _statusMessage,
      statusTone: _statusMessage == null ? null : _statusTone,
      onDismissStatus: () => setState(() => _statusMessage = null),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: _sharedBudgetAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Flexible(child: Text('Mezani')),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _text('Inbox', 'Inbox'),
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
          onPressed: _openBudgetForm,
          icon: const Icon(Icons.add_rounded),
          label: Text(_text('Create a shared budget (Mezani)', 'Unda Mezani')),
          backgroundColor: _sharedBudgetAccent,
          foregroundColor: Colors.white,
        ),
        body: OrbiBackground(
          padding: EdgeInsets.zero,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: _sharedBudgetAccent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                WealthHeroCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Mezani',
                  subtitle: _text(
                    'Track, review, and open budget controls when needed.',
                    'Fuatilia, hakiki, na fungua controls za budget ukihitaji.',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrbiHeroMetricChip(
                        icon: Icons.account_balance_wallet_outlined,
                        label: _text('Total budgets', 'Jumla ya Bajeti'),
                        value: '${_budgets.length}',
                      ),
                      OrbiHeroMetricChip(
                        icon: Icons.people_alt_outlined,
                        label: _text('Members', 'Members'),
                        value: '${_budgets.length}',
                      ),
                      OrbiHeroMetricChip(
                        icon: Icons.mail_outline_rounded,
                        label: _text('Inbox', 'Inbox'),
                        value: '$pendingInvites',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_budgets.isEmpty)
                  OrbiEmptyStateCard(
                    icon: Icons.groups_3_outlined,
                    title: _text(
                      'No shared budget yet',
                      'Bado hakuna shared budget',
                    ),
                    subtitle: _text(
                      'Create one budget for family, team, or enterprise spending.',
                      'Unda budget moja kwa matumizi ya familia, timu, au taasisi.',
                    ),
                    actionLabel: _text(
                      'Create a shared budget (Mezani)',
                      'Unda Mezani',
                    ),
                    onAction: _openBudgetForm,
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _text(
                            'Active budget controls',
                            'Budget zinazoendelea',
                          ),
                          style: TextStyle(
                            color: ui.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _Pill(
                        text:
                            '${_budgets.length} ${_budgets.length == 1 ? _text('budget', 'bajeti') : _text('budgets', 'bajeti')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._budgets.map((budget) {
                    final currency = (budget['currency'] ?? 'TZS').toString();
                    final spent = _asDouble(budget['spent_amount']);
                    final limit = _asDouble(budget['budget_limit']);
                    final remaining = _asDouble(
                      budget['remaining_amount'] ?? (limit - spent),
                    );
                    final progress = limit <= 0
                        ? 0.0
                        : (spent / limit).clamp(0, 1).toDouble();
                    final role = (budget['my_role'] ?? 'SPENDER').toString();
                    final canApprove =
                        role.toUpperCase() == 'OWNER' ||
                        role.toUpperCase() == 'MANAGER';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrbiActivityCard(
                        accent: _sharedBudgetAccent,
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
                                    color: _sharedBudgetAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: _sharedBudgetAccent,
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
                                        (budget['name'] ??
                                                _text(
                                                  'Shared budget',
                                                  'Shared budget',
                                                ))
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: ui.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (budget['purpose'] ??
                                                _text(
                                                  'No purpose added yet.',
                                                  'Hakuna lengo lililowekwa bado.',
                                                ))
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
                                      _money(remaining, currency),
                                      style: TextStyle(
                                        color: ui.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _text('left', 'baki'),
                                      style: TextStyle(
                                        color: ui.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openBudgetForm(budget: budget);
                                    } else if (value == 'invites') {
                                      _showBudgetInvites(budget);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(_text('Edit', 'Hariri')),
                                    ),
                                    PopupMenuItem(
                                      value: 'invites',
                                      child: Text(
                                        _text('Invitations', 'Mialiko'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                color: _sharedBudgetAccent,
                                backgroundColor: ui.cardMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: _text('Spent', 'Imetumika'),
                                    value: _money(spent, currency),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: _text('Remaining', 'Kilichobaki'),
                                    value: _money(remaining, currency),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Pill(text: _roleLabel(role)),
                                _Pill(
                                  text: _periodLabel(
                                    (budget['period_type'] ?? 'MONTHLY')
                                        .toString(),
                                  ),
                                ),
                                _Pill(
                                  text: _approvalLabel(
                                    (budget['approval_mode'] ?? 'AUTO')
                                        .toString(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ActionButton(
                                  label: _text('Spend', 'Tumia'),
                                  icon: Icons.payments_outlined,
                                  onTap: () => _openSpendSheet(budget),
                                ),
                                _ActionButton(
                                  label: _text('Invite', 'Alika'),
                                  icon: Icons.person_add_alt_1_rounded,
                                  onTap: () => _openInviteSheet(budget),
                                ),
                                _ActionButton(
                                  label: _text('Members', 'Wanachama'),
                                  icon: Icons.groups_2_outlined,
                                  onTap: () => _showMembers(budget),
                                ),
                                if (canApprove)
                                  _ActionButton(
                                    label: _text('Approvals', 'Idhini'),
                                    icon: Icons.fact_check_outlined,
                                    onTap: () => _showBudgetApprovals(budget),
                                  ),
                                _ActionButton(
                                  label: _text('Activity', 'Shughuli'),
                                  icon: Icons.receipt_long_outlined,
                                  onTap: () => _showActivity(budget),
                                ),
                                _ActionButton(
                                  label: _text('Report', 'Ripoti'),
                                  icon: Icons.summarize_outlined,
                                  onTap: () => _showReport(budget),
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
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: ui.card,
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: child,
            ),
          ),
        ),
      ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
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
            label,
            style: TextStyle(
              color: ui.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: ui.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ui.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ui.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _sharedBudgetAccent),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _sharedBudgetAccent,
        side: BorderSide(color: _sharedBudgetAccent.withValues(alpha: 0.28)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ui.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        children: [
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Text(
              trailing!,
              style: TextStyle(
                color: ui.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
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

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.title,
    required this.subtitle,
    required this.pending,
    this.trailing,
    this.onApprove,
    this.onReject,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final bool pending;
  final VoidCallback? onApprove;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ui.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: ui.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: ui.textMuted, fontSize: 12, height: 1.4),
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
                    onPressed: onApprove,
                    child: Text(sw ? 'Kubali' : 'Approve'),
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

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sharedBudgetAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _sharedBudgetAccent.withValues(alpha: 0.20)),
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
          const SizedBox(height: 8),
          for (final line in lines) ...[
            Text(
              line,
              style: TextStyle(color: ui.textMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
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
