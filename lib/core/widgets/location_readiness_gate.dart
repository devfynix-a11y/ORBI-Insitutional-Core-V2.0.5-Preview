import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/orbi_theme.dart';

class LocationReadinessGate extends StatefulWidget {
  const LocationReadinessGate({super.key, required this.child});

  final Widget child;

  @override
  State<LocationReadinessGate> createState() => _LocationReadinessGateState();
}

class _LocationReadinessGateState extends State<LocationReadinessGate>
    with WidgetsBindingObserver {
  bool _dialogOpen = false;
  bool _promptedThisLaunch = false;
  Timer? _initialCheckTimer;

  bool get _isSw =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'sw';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialCheckTimer = Timer(const Duration(milliseconds: 900), () {
        _checkLocationReady();
      });
    });
  }

  @override
  void dispose() {
    _initialCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationReady(showOnce: false);
    }
  }

  Future<void> _checkLocationReady({bool showOnce = true}) async {
    if (!mounted || _dialogOpen) return;
    if (showOnce && _promptedThisLaunch) return;

    final issue = await _resolveLocationIssue();
    if (!mounted || issue == null) return;

    _promptedThisLaunch = true;
    _dialogOpen = true;
    final ui = OrbiTheme.uiOf(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ui.sheet,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ui.accent.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_rounded, color: ui.accent),
          ),
          title: Text(
            _titleFor(issue),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ui.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            _messageFor(issue),
            textAlign: TextAlign.center,
            style: TextStyle(color: ui.textMuted, height: 1.35),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_isSw ? 'Baadaye' : 'Later'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openSettingsFor(issue);
              },
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(_actionFor(issue)),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<_LocationIssue?> _resolveLocationIssue() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _LocationIssue.serviceOff;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return _LocationIssue.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return _LocationIssue.permissionDeniedForever;
    }
    return null;
  }

  String _titleFor(_LocationIssue issue) {
    switch (issue) {
      case _LocationIssue.serviceOff:
        return _isSw ? 'Washa Location' : 'Turn on Location';
      case _LocationIssue.permissionDenied:
      case _LocationIssue.permissionDeniedForever:
        return _isSw ? 'Ruhusu Location' : 'Allow Location';
    }
  }

  String _messageFor(_LocationIssue issue) {
    switch (issue) {
      case _LocationIssue.serviceOff:
        return _isSw
            ? 'ORBI hutumia location kulinda miamala yako. Unaweza kuona quote kwa network location, lakini baadhi ya miamala itahitaji Location iwashwe.'
            : 'ORBI uses location to protect your transactions. You can preview with network location, but some transfers require Location to be turned on.';
      case _LocationIssue.permissionDenied:
        return _isSw
            ? 'Location permission haijaruhusiwa. ORBI inaweza kutumia network location kwa baadhi ya hatua, lakini miamala muhimu itahitaji ruhusa hii.'
            : 'Location permission is not allowed. ORBI can use network location for some steps, but important transfers require this permission.';
      case _LocationIssue.permissionDeniedForever:
        return _isSw
            ? 'Location permission imezimwa kwenye settings. Fungua settings ili uruhusu ORBI kulinda miamala yako.'
            : 'Location permission is disabled in settings. Open settings to allow ORBI to protect your transactions.';
    }
  }

  String _actionFor(_LocationIssue issue) {
    switch (issue) {
      case _LocationIssue.serviceOff:
        return _isSw ? 'Washa Location' : 'Turn on';
      case _LocationIssue.permissionDenied:
        return _isSw ? 'Ruhusu' : 'Allow';
      case _LocationIssue.permissionDeniedForever:
        return _isSw ? 'Fungua Settings' : 'Open settings';
    }
  }

  Future<void> _openSettingsFor(_LocationIssue issue) async {
    switch (issue) {
      case _LocationIssue.serviceOff:
        await Geolocator.openLocationSettings();
        break;
      case _LocationIssue.permissionDenied:
        final next = await Geolocator.requestPermission();
        if (next == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        break;
      case _LocationIssue.permissionDeniedForever:
        await Geolocator.openAppSettings();
        break;
    }
  }
}

enum _LocationIssue { serviceOff, permissionDenied, permissionDeniedForever }
