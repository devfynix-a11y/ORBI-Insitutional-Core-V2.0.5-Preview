import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/backend_status_message.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/orbi_amount_field.dart';
import 'goals_composer_widgets.dart';

class GoalFormData {
  const GoalFormData({
    required this.name,
    required this.target,
    required this.fundingStrategy,
    required this.autoAllocationEnabled,
    required this.linkedIncomePercentage,
    required this.monthlyTarget,
    required this.deadline,
  });

  final String name;
  final double? target;
  final String fundingStrategy;
  final bool autoAllocationEnabled;
  final double? linkedIncomePercentage;
  final double? monthlyTarget;
  final DateTime? deadline;
}

class BudgetFormData {
  const BudgetFormData({
    required this.name,
    required this.budget,
    required this.interval,
    required this.period,
  });

  final String name;
  final double? budget;
  final int interval;
  final String period;
}

class TaskFormData {
  const TaskFormData({
    required this.text,
    required this.linkedGoalId,
    required this.bounty,
    required this.dueDate,
    required this.completed,
  });

  final String text;
  final String? linkedGoalId;
  final double? bounty;
  final DateTime? dueDate;
  final bool completed;
}

class GoalComposerSheet extends StatefulWidget {
  const GoalComposerSheet({
    super.key,
    required this.initialData,
    required this.currencyCode,
    required this.languageCode,
    required this.isEditing,
    required this.isSwahili,
    required this.onSubmit,
  });

  final GoalFormData initialData;
  final String currencyCode;
  final String languageCode;
  final bool isEditing;
  final bool isSwahili;
  final Future<void> Function(GoalFormData data) onSubmit;

  @override
  State<GoalComposerSheet> createState() => _GoalComposerSheetState();
}

class _GoalComposerSheetState extends State<GoalComposerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _incomePercentageController;
  late final TextEditingController _monthlyTargetController;
  late String _fundingStrategy;
  late bool _autoAllocationEnabled;
  DateTime? _deadline;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.name);
    _targetController = TextEditingController(
      text: AmountInputFormatter.format(
        widget.initialData.target?.toString() ?? '',
      ),
    );
    _incomePercentageController = TextEditingController(
      text: AmountInputFormatter.format(
        widget.initialData.linkedIncomePercentage?.toString() ?? '',
      ),
    );
    _monthlyTargetController = TextEditingController(
      text: AmountInputFormatter.format(
        widget.initialData.monthlyTarget?.toString() ?? '',
      ),
    );
    _fundingStrategy = widget.initialData.fundingStrategy;
    _autoAllocationEnabled = widget.initialData.autoAllocationEnabled;
    _deadline = widget.initialData.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _incomePercentageController.dispose();
    _monthlyTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GoalsComposerSheetScaffold(
      title: widget.isEditing
          ? l10n.goalsEditGoalTitle
          : l10n.goalsCreateGoalTitle,
      errorText: _formError,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.goalsGoalNameLabel),
          ),
          const SizedBox(height: 10),
          OrbiAmountField(
            controller: _targetController,
            textInputAction: TextInputAction.next,
            inputFormatters: [AmountInputFormatter()],
            label: l10n.goalsTargetAmountLabel,
            currency: resolveCurrencyDisplaySymbol(widget.currencyCode),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _fundingStrategy,
            decoration: InputDecoration(
              labelText: l10n.goalsFundingStrategyLabel,
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: 'manual',
                child: Text(l10n.goalsFundingManual),
              ),
              DropdownMenuItem(
                value: 'percentage',
                child: Text(l10n.goalsFundingPercentage),
              ),
              DropdownMenuItem(
                value: 'fixed',
                child: Text(l10n.goalsFundingFixed),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _fundingStrategy = value;
                if (value == 'manual') {
                  _autoAllocationEnabled = false;
                }
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.goalsAutoAllocationLabel),
            subtitle: Text(l10n.goalsAutoAllocationHint),
            value: _autoAllocationEnabled,
            onChanged: _fundingStrategy == 'manual'
                ? null
                : (value) {
                    setState(() => _autoAllocationEnabled = value);
                  },
          ),
          if (_fundingStrategy == 'percentage') ...[
            const SizedBox(height: 8),
            OrbiAmountField(
              controller: _incomePercentageController,
              textInputAction: TextInputAction.next,
              inputFormatters: [AmountInputFormatter()],
              label: l10n.goalsIncomePercentageLabel,
              helperText: l10n.goalsIncomePercentageHint,
              currency: '%',
            ),
          ],
          if (_fundingStrategy == 'fixed') ...[
            const SizedBox(height: 8),
            OrbiAmountField(
              controller: _monthlyTargetController,
              textInputAction: TextInputAction.next,
              inputFormatters: [AmountInputFormatter()],
              label: l10n.goalsMonthlyTargetLabel,
              helperText: l10n.goalsMonthlyTargetHint,
              currency: resolveCurrencyDisplaySymbol(widget.currencyCode),
            ),
          ],
          const SizedBox(height: 12),
          GoalsComposerDateTile(
            title: l10n.goalsDeadlineLabel,
            subtitle: _deadline == null
                ? l10n.goalsOptional
                : DateFormat(
                    'dd MMM yyyy',
                    widget.languageCode,
                  ).format(_deadline!),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: _deadline ?? DateTime.now(),
              );
              if (picked != null) {
                setState(() => _deadline = picked);
              }
            },
          ),
          const SizedBox(height: 14),
          GoalsComposerSubmitButton(
            submitting: _submitting,
            submittingLabel: widget.isSwahili ? 'Inahifadhi...' : 'Saving...',
            label: widget.isEditing
                ? l10n.goalsUpdateGoalButton
                : l10n.goalsSaveGoalButton,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final target = AmountInputFormatter.tryParse(_targetController.text);
    final linkedIncomePercentage = AmountInputFormatter.tryParse(
      _incomePercentageController.text,
    );
    final monthlyTarget = AmountInputFormatter.tryParse(
      _monthlyTargetController.text,
    );
    if (name.isEmpty || target == null || target <= 0) {
      setState(() => _formError = l10n.goalsGoalValidationMessage);
      return;
    }
    if (_fundingStrategy == 'percentage' &&
        _autoAllocationEnabled &&
        (linkedIncomePercentage == null || linkedIncomePercentage <= 0)) {
      setState(() => _formError = l10n.goalsIncomePercentageValidation);
      return;
    }
    if (_fundingStrategy == 'fixed' &&
        _autoAllocationEnabled &&
        (monthlyTarget == null || monthlyTarget <= 0)) {
      setState(() => _formError = l10n.goalsMonthlyTargetValidation);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await widget.onSubmit(
        GoalFormData(
          name: name,
          target: target,
          fundingStrategy: _fundingStrategy,
          autoAllocationEnabled: _fundingStrategy == 'manual'
              ? false
              : _autoAllocationEnabled,
          linkedIncomePercentage: linkedIncomePercentage,
          monthlyTarget: monthlyTarget,
          deadline: _deadline,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = mapBackendStatusMessage(
          error.toString(),
          sw: widget.isSwahili,
          fallback: widget.isSwahili
              ? 'Lengo halikuweza kuhifadhiwa. Tafadhali jaribu tena.'
              : 'Goal could not be saved. Please try again.',
        );
        _submitting = false;
      });
    }
  }
}

class BudgetComposerSheet extends StatefulWidget {
  const BudgetComposerSheet({
    super.key,
    required this.initialData,
    required this.currencyCode,
    required this.isEditing,
    required this.isSwahili,
    required this.onSubmit,
  });

  final BudgetFormData initialData;
  final String currencyCode;
  final bool isEditing;
  final bool isSwahili;
  final Future<void> Function(BudgetFormData data) onSubmit;

  @override
  State<BudgetComposerSheet> createState() => _BudgetComposerSheetState();
}

class _BudgetComposerSheetState extends State<BudgetComposerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late final TextEditingController _intervalController;
  late String _selectedPeriod;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.name);
    _budgetController = TextEditingController(
      text: AmountInputFormatter.format(
        widget.initialData.budget?.toString() ?? '',
      ),
    );
    _intervalController = TextEditingController(
      text: widget.initialData.interval.toString(),
    );
    _selectedPeriod = widget.initialData.period;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GoalsComposerSheetScaffold(
      title: widget.isEditing
          ? l10n.goalsEditBudgetTitle
          : l10n.goalsCreateBudgetTitle,
      errorText: _formError,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.goalsCategoryNameLabel),
          ),
          const SizedBox(height: 10),
          OrbiAmountField(
            controller: _budgetController,
            textInputAction: TextInputAction.next,
            inputFormatters: [AmountInputFormatter()],
            label: l10n.goalsBudgetAmountLabel,
            currency: resolveCurrencyDisplaySymbol(widget.currencyCode),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackFields = constraints.maxWidth < 380;
              final intervalField = TextField(
                controller: _intervalController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.isSwahili ? 'Rudia kila' : 'Repeat every',
                ),
              );
              final periodField = DropdownButtonFormField<String>(
                initialValue: _selectedPeriod,
                decoration: InputDecoration(
                  labelText: widget.isSwahili ? 'Muda' : 'Period',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('Day')),
                  DropdownMenuItem(value: 'week', child: Text('Week')),
                  DropdownMenuItem(value: 'month', child: Text('Month')),
                  DropdownMenuItem(value: 'year', child: Text('Year')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedPeriod = value);
                },
              );
              if (stackFields) {
                return Column(
                  children: [
                    intervalField,
                    const SizedBox(height: 10),
                    periodField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: intervalField),
                  const SizedBox(width: 10),
                  Expanded(child: periodField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          GoalsComposerSubmitButton(
            submitting: _submitting,
            submittingLabel: widget.isSwahili ? 'Inahifadhi...' : 'Saving...',
            label: widget.isEditing
                ? l10n.goalsUpdateBudgetButton
                : l10n.goalsSaveBudgetButton,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final budget = AmountInputFormatter.tryParse(_budgetController.text);
    final interval = int.tryParse(_intervalController.text.trim()) ?? 0;
    if (name.isEmpty || budget == null || budget <= 0 || interval <= 0) {
      setState(() => _formError = l10n.goalsBudgetValidationMessage);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await widget.onSubmit(
        BudgetFormData(
          name: name,
          budget: budget,
          interval: interval,
          period: _selectedPeriod,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = mapBackendStatusMessage(
          error.toString(),
          sw: widget.isSwahili,
          fallback: widget.isSwahili
              ? 'Budget haikuweza kuhifadhiwa. Tafadhali jaribu tena.'
              : 'Budget could not be saved. Please try again.',
        );
        _submitting = false;
      });
    }
  }
}

class TaskComposerSheet extends StatefulWidget {
  const TaskComposerSheet({
    super.key,
    required this.initialData,
    required this.availableGoals,
    required this.currencyCode,
    required this.languageCode,
    required this.isEditing,
    required this.isSwahili,
    required this.onSubmit,
  });

  final TaskFormData initialData;
  final List<Map<String, dynamic>> availableGoals;
  final String currencyCode;
  final String languageCode;
  final bool isEditing;
  final bool isSwahili;
  final Future<void> Function(TaskFormData data) onSubmit;

  @override
  State<TaskComposerSheet> createState() => _TaskComposerSheetState();
}

class _TaskComposerSheetState extends State<TaskComposerSheet> {
  late final TextEditingController _textController;
  late final TextEditingController _bountyController;
  String? _selectedGoalId;
  DateTime? _dueDate;
  late bool _completed;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialData.text);
    _bountyController = TextEditingController(
      text: AmountInputFormatter.format(
        widget.initialData.bounty?.toString() ?? '',
      ),
    );
    _selectedGoalId = widget.initialData.linkedGoalId;
    _dueDate = widget.initialData.dueDate;
    _completed = widget.initialData.completed;
  }

  @override
  void dispose() {
    _textController.dispose();
    _bountyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GoalsComposerSheetScaffold(
      title: widget.isEditing
          ? l10n.goalsEditTaskTitle
          : l10n.goalsCreateTaskTitle,
      errorText: _formError,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.goalsTaskTextLabel),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedGoalId?.isEmpty == true
                ? ''
                : _selectedGoalId,
            decoration: InputDecoration(
              labelText: l10n.goalsTaskLinkedGoalLabel,
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(l10n.goalsTaskNoLinkedGoal),
              ),
              ...widget.availableGoals.map((goal) {
                final id = goal['id']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(goal['name']?.toString() ?? ''),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGoalId = value == null || value.isEmpty ? null : value;
              });
            },
          ),
          const SizedBox(height: 10),
          OrbiAmountField(
            controller: _bountyController,
            textInputAction: TextInputAction.next,
            inputFormatters: [AmountInputFormatter()],
            label: l10n.goalsTaskBountyLabel,
            currency: resolveCurrencyDisplaySymbol(widget.currencyCode),
          ),
          const SizedBox(height: 12),
          GoalsComposerDateTile(
            title: l10n.goalsTaskDuePickerLabel,
            subtitle: _dueDate == null
                ? l10n.goalsOptional
                : DateFormat(
                    'dd MMM yyyy',
                    widget.languageCode,
                  ).format(_dueDate!),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: _dueDate ?? DateTime.now(),
              );
              if (picked != null) {
                setState(() => _dueDate = picked);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.goalsTaskCompletedToggle),
            value: _completed,
            onChanged: (value) {
              setState(() => _completed = value);
            },
          ),
          const SizedBox(height: 14),
          GoalsComposerSubmitButton(
            submitting: _submitting,
            submittingLabel: widget.isSwahili ? 'Inahifadhi...' : 'Saving...',
            label: widget.isEditing
                ? l10n.goalsUpdateTaskButton
                : l10n.goalsSaveTaskButton,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _textController.text.trim();
    final bounty = AmountInputFormatter.tryParse(_bountyController.text);
    if (text.isEmpty) {
      setState(() => _formError = l10n.goalsTaskValidationMessage);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await widget.onSubmit(
        TaskFormData(
          text: text,
          linkedGoalId: _selectedGoalId,
          bounty: bounty,
          dueDate: _dueDate,
          completed: _completed,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = mapBackendStatusMessage(
          error.toString(),
          sw: widget.isSwahili,
          fallback: widget.isSwahili
              ? 'Task haikuweza kuhifadhiwa. Tafadhali jaribu tena.'
              : 'Task could not be saved. Please try again.',
        );
        _submitting = false;
      });
    }
  }
}
