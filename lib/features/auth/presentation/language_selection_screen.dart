import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbi_mobileapp/l10n/app_localizations.dart';

import '../../../core/widgets/orbi_logo.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final Function(String) onLanguageSelected;

  const LanguageSelectionScreen({super.key, required this.onLanguageSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: const OrbiLogoV2(width: 152),
              ),
              Text(
                l10n.signupSelectLanguageTitle,
                style: GoogleFonts.michroma(
                  fontSize: 24,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _LanguageCard(
                language: l10n.languageEnglish,
                flag: '🇬🇧',
                onTap: () => onLanguageSelected('en'),
              ),
              const SizedBox(height: 16),
              _LanguageCard(
                language: l10n.languageSwahili,
                flag: '🇰🇪',
                onTap: () => onLanguageSelected('sw'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String language;
  final String flag;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.flag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 18),
              Text(
                language,
                style: GoogleFonts.michroma(
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
