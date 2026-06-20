import '../../../core/utils/user_facing_error.dart';

String localizeWalletFetchError(Object error, {required String languageCode}) {
  final lower = _rawError(error);
  final sw = languageCode.toLowerCase() == 'sw';

  if (_containsAny(lower, const [
    'failed host lookup',
    'no address associated with hostname',
    'name or service not known',
    'socketexception',
    'network is unreachable',
    'no route to host',
    'connection refused',
    'connection reset',
    'timed out',
    'timeout',
    'dns',
  ])) {
    return sw
        ? 'Imeshindikana kufikia huduma ya wallet. Angalia intaneti yako kisha ujaribu tena.'
        : 'We could not reach the wallet service. Check your internet connection and try again.';
  }

  if (_containsAny(lower, const ['401', 'unauthorized', 'token expired'])) {
    return sw
        ? 'Kikao chako kimeisha. Tafadhali ingia tena ili kuona wallet zako.'
        : 'Your session expired. Please log in again to load your wallets.';
  }

  if (_containsAny(lower, const ['403', 'forbidden', 'access_denied'])) {
    return sw
        ? 'Huna ruhusa ya kuona wallet hizi kwa sasa.'
        : 'You do not have permission to view these wallets right now.';
  }

  if (_containsAny(lower, const [
    '500',
    '502',
    '503',
    '504',
    'internal server error',
    'server error',
    'decrypt',
    'decryption',
    'kms',
    'cipher',
  ])) {
    return sw
        ? 'Wallet zako hazikuweza kupakiwa kwa sasa. Tafadhali vuta chini kujaribu tena baada ya muda mfupi.'
        : 'Your wallets could not load right now. Pull to refresh and try again in a moment.';
  }

  if (_containsAny(lower, const [
    'typeerror',
    'formatexception',
    'null check operator',
    'nosuchmethoderror',
    'unexpected',
    'invalid format',
    'invalid type',
    'json',
  ])) {
    return sw
        ? 'Tumepata tatizo la kusoma taarifa za wallet zako. Tafadhali jaribu tena.'
        : 'We hit a problem reading your wallet details. Please try again.';
  }

  return UserFacingError.from(
    error,
    fallback: sw
        ? 'Imeshindikana kupakia wallet zako kwa sasa. Tafadhali vuta chini ujaribu tena.'
        : 'Unable to load your wallets right now. Pull to refresh and try again.',
  );
}

String localizeWalletTransactionError(
  Object error, {
  required String languageCode,
}) {
  final lower = _rawError(error);
  final sw = languageCode.toLowerCase() == 'sw';

  if (_containsAny(lower, const [
    'failed host lookup',
    'socketexception',
    'network is unreachable',
    'connection refused',
    'timeout',
  ])) {
    return sw
        ? 'Imeshindikana kupata miamala ya wallet kwa sasa. Angalia intaneti yako kisha ujaribu tena.'
        : 'We could not load wallet transactions right now. Check your internet connection and try again.';
  }

  return UserFacingError.from(
    error,
    fallback: sw
        ? 'Imeshindikana kupakia miamala ya wallet kwa sasa.'
        : 'Unable to load wallet transactions right now.',
  );
}

String _rawError(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim().toLowerCase();
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
}
