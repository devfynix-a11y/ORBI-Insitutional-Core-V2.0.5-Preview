import 'package:flutter/material.dart';

import '../../../core/theme/orbi_theme.dart';

class GoalsComposerSheetScaffold extends StatelessWidget {
  const GoalsComposerSheetScaffold({
    super.key,
    required this.title,
    this.errorText,
    required this.child,
  });

  final String title;
  final String? errorText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: GoalsComposerHandle()),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  GoalsComposerErrorText(errorText!),
                ],
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoalsComposerHandle extends StatelessWidget {
  const GoalsComposerHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: OrbiTheme.uiOf(context).border,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class GoalsComposerErrorText extends StatelessWidget {
  const GoalsComposerErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: OrbiTheme.uiOf(context).warning,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class GoalsComposerDateTile extends StatelessWidget {
  const GoalsComposerDateTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }
}

class GoalsComposerSubmitButton extends StatelessWidget {
  const GoalsComposerSubmitButton({
    super.key,
    required this.submitting,
    required this.label,
    required this.submittingLabel,
    required this.onPressed,
  });

  final bool submitting;
  final String label;
  final String submittingLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: submitting ? null : onPressed,
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
                  Text(submittingLabel),
                ],
              )
            : Text(label),
      ),
    );
  }
}
