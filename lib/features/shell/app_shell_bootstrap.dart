part of 'app_shell.dart';

class _BootstrapLanding extends StatefulWidget {
  const _BootstrapLanding();

  @override
  State<_BootstrapLanding> createState() => _BootstrapLandingState();
}

class _BootstrapLandingState extends State<_BootstrapLanding> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sw =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';
    return OrbiLoadingLanding(
      subtitle: l10n.shellBootstrapSubtitle,
      status: sw ? 'Inafungua huduma zako' : 'Opening your services',
      detail: sw
          ? 'Tunaunganisha akaunti, arifa, na sehemu muhimu za programu.'
          : 'Connecting accounts, notifications, and essential app services.',
    );
  }
}
