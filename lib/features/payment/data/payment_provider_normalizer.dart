class PaymentProviderNormalizer {
  const PaymentProviderNormalizer._();

  static String normalize(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return normalized;
    if (normalized.contains('e-government') ||
        normalized.contains('e government') ||
        normalized.contains('egov')) {
      return 'egovernment';
    }
    if (normalized.contains('nhif')) {
      return 'nhif';
    }
    if (normalized.contains('nida')) {
      return 'nida';
    }
    if (normalized.contains('tra')) {
      return 'tra';
    }
    if (normalized.contains('mix') ||
        normalized.contains('yas') ||
        normalized.contains('tigo')) {
      return 'mix by yas';
    }
    if (normalized.contains('oryx')) {
      return 'oryx gas';
    }
    if (normalized.contains('azam')) {
      return 'azam tv';
    }
    if (normalized.contains('star times')) {
      return 'startimes';
    }
    if (normalized.contains('ttcl voice')) {
      return 'ttcl voice';
    }
    if (normalized.contains('liquid telecom')) {
      return 'liquid telecom';
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}
