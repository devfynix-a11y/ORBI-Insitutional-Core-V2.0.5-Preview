// ignore: file_names
import 'package:flutter/material.dart';
import 'package:orbi_mobileapp/core/theme/orbi_theme.dart';
import 'package:orbi_mobileapp/core/widgets/mini_analytics_widget.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import 'goals_shared_widgets.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.title,
    required this.accent,
    required this.glow,
    required this.visualToken,
    required this.completed,
    required this.dueLabel,
    required this.summary,
    required this.analyticsValues,
    required this.analyticsLabels,
    this.analyticsColors,
    this.analyticsValueFormatter,
    required this.statusBadge,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMenuSelected,
    required this.l10n,
    this.linkedGoalName,
    this.bountyLabel,
  });

  final String title;
  final Color accent;
  final Color glow;
  final int visualToken;
  final bool completed;
  final String dueLabel;
  final String? linkedGoalName;
  final String? bountyLabel;
  final String summary;
  final List<double> analyticsValues;
  final List<String> analyticsLabels;
  final List<Color>? analyticsColors;
  final String Function(double value)? analyticsValueFormatter;
  final StatusBadgeData statusBadge;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onMenuSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ui = OrbiTheme.uiOf(context);
    return GoalsPremiumCardShell(
      accent: accent,
      glow: glow,
      visualToken: visualToken,
      artAlignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: completed, onChanged: (_) => onToggle()),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ui.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(data: statusBadge),
                        GoalsCompactMetaChip(
                          color: ui.textMuted,
                          icon: Icons.event_note_outlined,
                          label: dueLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GoalsCardMenuButton(onSelected: onMenuSelected),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ui.cardMuted.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    completed ? Icons.task_alt_rounded : Icons.bolt_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ui.textMuted,
                      fontSize: 10.5,
                      height: 1.32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if ((linkedGoalName != null && linkedGoalName!.isNotEmpty) ||
              bountyLabel != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (linkedGoalName != null && linkedGoalName!.isNotEmpty)
                  GoalsCompactMetaChip(
                    color: ui.accent,
                    icon: Icons.link_rounded,
                    label: linkedGoalName!,
                  ),
                if (bountyLabel != null)
                  GoalsCompactMetaChip(
                    color: accent,
                    icon: Icons.workspace_premium_outlined,
                    label: bountyLabel!,
                  ),
              ],
            ),
          if ((linkedGoalName != null && linkedGoalName!.isNotEmpty) ||
              bountyLabel != null)
            const SizedBox(height: 6),
          MiniAnalyticsWidget(
            accent: accent,
            values: analyticsValues,
            labels: analyticsLabels,
            title: completed ? 'Execution signal' : 'Task traction',
            subtitle: completed
                ? 'Completed and recorded.'
                : 'Compact operational analytics.',
            barColors: analyticsColors,
            tooltipValueFormatter: analyticsValueFormatter,
            topValueFormatter: analyticsValueFormatter,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GoalsActionPillButton(
                  label: l10n.goalsEditButton,
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                  color: ui.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GoalsActionPillButton(
                  label: l10n.goalsDeleteButton,
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                  color: ui.danger,
                  destructive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
