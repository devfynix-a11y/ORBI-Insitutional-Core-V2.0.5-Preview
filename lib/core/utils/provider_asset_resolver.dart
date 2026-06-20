import '../../features/auth/state/auth_controller.dart';

class ProviderAssetResolver {
  const ProviderAssetResolver._();

  static String resolveCountry(AuthController auth) {
    final raw = auth.currentSession?.user.rawData ?? const <String, dynamic>{};
    final candidates = [
      raw['country'],
      raw['country_name'],
      raw['countryName'],
      raw['country_code'],
      raw['countryCode'],
      raw['market'],
      raw['market_name'],
      raw['marketName'],
      raw['nationality'],
    ];
    for (final value in candidates) {
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized.isEmpty) continue;
      if (normalized == 'tz' ||
          normalized == 'tza' ||
          normalized.contains('tanzania')) {
        return 'Tanzania';
      }
    }
    return 'Tanzania';
  }

  static String normalizeProviderName(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return normalized;
    if (normalized.contains('e-government') ||
        normalized.contains('e government') ||
        normalized.contains('egov')) {
      return 'egovernment';
    }
    if (normalized.contains('nhif')) return 'nhif';
    if (normalized.contains('nida')) return 'nida';
    if (normalized.contains('tra')) return 'tra';
    if (normalized.contains('dawasco')) return 'dawasco';
    if (normalized.contains('dawasa')) return 'dawasa';
    if (normalized.contains('ruwasa')) return 'ruwasa';
    if (normalized.contains('tanesco') || normalized.contains('luku')) {
      return 'tanesco';
    }
    if (normalized.contains('oryx')) return 'oryx_gas';
    if (normalized.contains('azam')) return 'azam_tv';
    if (normalized.contains('star times') || normalized.contains('startimes')) {
      return 'startimes';
    }
    if (normalized.contains('dstv')) return 'dstv';
    if (normalized.contains('mix') ||
        normalized.contains('yas') ||
        normalized.contains('tigo')) {
      return 'mix_by_yas';
    }
    if (normalized.contains('mpesa') || normalized.contains('m-pesa')) {
      return 'vodacom';
    }
    if (normalized.contains('ttcl')) {
      return normalized.contains('voice') ? 'ttcl_voice' : 'ttcl';
    }
    if (normalized.contains('diamond')) {
      return 'diamond_trust_bank';
    }
    if (normalized.contains('equity')) {
      return 'equity_bank';
    }
    if (normalized.contains('crdb')) {
      return 'crdb_bank';
    }
    if (normalized.contains('absa')) {
      return 'absa_bank';
    }
    if (normalized == 'nbc' ||
        normalized.contains('national bank of commerce')) {
      return 'nbc';
    }
    if (normalized.contains('nmb')) {
      return 'nmb_bank';
    }
    if (normalized.contains('airtel')) return 'airtel';
    if (normalized.contains('halopesa') ||
        normalized.contains('halo pesa') ||
        normalized.contains('halotel')) {
      return 'halotel';
    }
    if (normalized.contains('vodacom')) return 'vodacom';
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static List<String> providerBaseNames(String raw) {
    final normalized = normalizeProviderName(raw);
    if (normalized.isEmpty) return const [];

    final names = <String>{
      normalized,
      '${normalized}_logo',
      normalized.replaceAll('_', ' '),
      '${normalized.replaceAll('_', ' ')}_logo',
      normalized.replaceAll('_', '-'),
      '${normalized.replaceAll('_', '-')}-logo',
    };

    switch (normalized) {
      case 'mix_by_yas':
        names.addAll({'tigo', 'mix by yas', 'mix by yas_logo', 'tigo_pesa'});
      case 'oryx_gas':
        names.addAll({'oryx gas', 'oryx-energies-logo', 'oryx_energies'});
      case 'azam_tv':
        names.addAll({'azam tv', 'Azam TV_Logo'});
      case 'dstv':
        names.addAll({'dstv_logo'});
      case 'startimes':
        names.addAll({'startimes_logo', 'star times'});
      case 'dawasa':
        names.addAll({'dawasa_logo'});
      case 'dawasco':
        names.addAll({'dawasco_logo'});
      case 'ruwasa':
        names.addAll({'ruwasa_ogo'});
      case 'tanesco':
        names.addAll({'tanesco_logo', 'luku'});
      case 'airtel':
        names.addAll({'airtel_logo'});
      case 'halotel':
        names.addAll({'halotel_logo'});
      case 'vodacom':
        names.addAll({'mpesa', 'm_pesa'});
      case 'egovernment':
        names.addAll({'e government', 'e-government'});
    }

    return names.where((value) => value.trim().isNotEmpty).toList(growable: false);
  }

  static List<String> assetCandidates({
    required String country,
    required String folder,
    required String providerName,
  }) {
    final bases = providerBaseNames(providerName);
    if (bases.isEmpty) return const [];
    const extensions = ['png', 'jpg', 'jpeg', 'webp'];
    return [
      for (final base in bases)
        for (final ext in extensions)
          'assets/providers/$country/$folder/$base.$ext',
    ];
  }

  static List<String> movementAssetCandidates({
    required String country,
    required String flow,
    required String category,
    required String providerName,
  }) {
    return assetCandidates(
      country: country,
      folder: '$flow/$category',
      providerName: providerName,
    );
  }

  static List<String> billAssetCandidates({
    required String country,
    required String category,
    required String providerName,
  }) {
    return [
      ...assetCandidates(
        country: country,
        folder: category,
        providerName: providerName,
      ),
      ...assetCandidates(
        country: country,
        folder: 'Logos',
        providerName: providerName,
      ),
    ];
  }
}
