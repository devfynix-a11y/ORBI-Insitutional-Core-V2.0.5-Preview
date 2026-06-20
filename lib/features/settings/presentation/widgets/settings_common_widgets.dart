import 'package:flutter/material.dart';

import '../../../../core/theme/orbi_card_styles.dart';
import '../../../../core/theme/orbi_theme.dart';
import '../../../../core/widgets/orbi_section_card.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.ui, required this.child});

  final OrbiUiTokens ui;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OrbiSectionCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      accentColor: ui.accent,
      branded: true,
      child: child,
    );
  }
}

class SettingsInfoField extends StatelessWidget {
  const SettingsInfoField({
    super.key,
    required this.ui,
    required this.label,
    required this.controller,
    this.type,
    this.enabled = true,
  });

  final OrbiUiTokens ui;
  final String label;
  final TextEditingController controller;
  final TextInputType? type;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: type,
        style: TextStyle(color: ui.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ui.textMuted),
          filled: true,
          fillColor: ui.cardMuted.withValues(alpha: 0.72),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ui.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ui.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ui.iconMuted, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({
    super.key,
    required this.ui,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.titleColor,
    this.subtitleColor,
  });

  final OrbiUiTokens ui;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: OrbiCardStyles.iconBadgeDecoration(
            context,
            accent: ui.iconMuted,
            radius: 12,
          ),
          child: Icon(icon, size: 18, color: ui.iconMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor ?? ui.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor ?? ui.textMuted,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.ui,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
  });

  final OrbiUiTokens ui;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: OrbiCardStyles.iconBadgeDecoration(
          context,
          accent: iconColor ?? ui.iconMuted,
          radius: 12,
        ),
        child: Icon(icon, color: iconColor ?? ui.iconMuted, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: ui.textMuted, fontSize: 12.5),
            ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded, color: ui.iconMuted)
              : null),
      onTap: onTap,
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.ui,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.iconColor,
  });

  final OrbiUiTokens ui;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        width: 38,
        height: 38,
        decoration: OrbiCardStyles.iconBadgeDecoration(
          context,
          accent: iconColor ?? ui.iconMuted,
          radius: 12,
        ),
        child: Icon(icon, color: iconColor ?? ui.iconMuted, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: ui.textPrimary, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: ui.textMuted, fontSize: 12.5),
            ),
      activeThumbColor: ui.iconMuted,
      value: value,
      onChanged: onChanged,
    );
  }
}
