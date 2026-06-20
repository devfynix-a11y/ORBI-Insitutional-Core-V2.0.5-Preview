String mapBackendStatusMessage(
  String raw, {
  bool sw = false,
  String? fallback,
}) {
  final normalized = raw.trim().replaceFirst(
    RegExp(r'^(Exception|Error):\s*', caseSensitive: false),
    '',
  );
  final upper = normalized.toUpperCase();

  String pick(String en, String swText) => sw ? swText : en;
  String safeFallback() =>
      fallback ??
      pick(
        'This request could not be completed right now. Please refresh and try again.',
        'Ombi hili halikuweza kukamilika kwa sasa. Tafadhali pakia upya kisha jaribu tena.',
      );

  bool containsAny(List<String> needles) {
    for (final needle in needles) {
      if (upper.contains(needle)) return true;
    }
    return false;
  }

  if (upper.contains('NO_OPERATING_WALLET') ||
      upper.contains('OPERATING_WALLET_REQUIRED')) {
    return pick(
      'Your operating wallet is still being prepared. Please refresh and try again in a moment.',
      'Walleti yako ya uendeshaji bado inaandaliwa. Tafadhali sasisha kisha ujaribu tena baada ya muda mfupi.',
    );
  }
  if (upper.contains('INTERNAL_BALANCE_MISMATCH')) {
    return pick(
      'Internal balance error. Please contact support if this keeps happening.',
      'Hitilafu ya ndani ya salio. Tafadhali wasiliana na huduma kwa wateja ikiwa hali hii itaendelea.',
    );
  }
  if (upper.contains('SOURCE_WALLET_LOCKED')) {
    return pick(
      'This goal is tied to its original operating wallet, so funds must return there.',
      'Lengo hili limefungwa kwa walleti yake ya awali ya uendeshaji, hivyo fedha lazima zirudi huko.',
    );
  }
  if (upper.contains('IDENTITY_REQUIRED') || upper.contains('AUTH_REQUIRED')) {
    return pick(
      'Your session needs to be refreshed. Please sign in again.',
      'Kikao chako kinahitaji kusasishwa. Tafadhali ingia tena.',
    );
  }
  if (upper.contains('NODE_ORIGIN_MISMATCH') ||
      upper.contains('ROLE_HEADER_REQUIRED') ||
      upper.contains('ROLE_HEADER_MISMATCH')) {
    return pick(
      'This request could not be completed from the current app context.',
      'Ombi hili halikuweza kukamilishwa kutoka mazingira ya sasa ya programu.',
    );
  }
  if (upper.contains('WALLET_LOCKED')) {
    return pick(
      'This wallet is locked. Unlock it first to continue.',
      'Walleti hii imefungwa. Ifungue kwanza ili kuendelea.',
    );
  }
  if (upper.contains('LOCKED') && upper.contains('TRANSACTION')) {
    return pick(
      'This transaction is currently locked for review.',
      'Muamala huu umefungwa kwa ukaguzi kwa sasa.',
    );
  }
  if (upper.contains('PIN_LOCKED_USE_BIOMETRIC')) {
    return pick(
      'Too many wrong PIN attempts. Use fingerprint to continue on this phone.',
      'Umejaribu PIN mara nyingi isivyofaa. Tumia alama ya kidole kuendelea kwenye simu hii.',
    );
  }
  if (upper.contains('DEVICE_NOT_TRUSTED')) {
    return pick(
      'This phone is not trusted for PIN sign in yet. Use fingerprint first.',
      'Simu hii bado haijaaminika kwa kuingia kwa PIN. Tumia alama ya kidole kwanza.',
    );
  }
  if (upper.contains('DEVICE_BINDING_REQUIRED')) {
    return pick(
      'Use fingerprint first to link PIN with this phone.',
      'Tumia alama ya kidole kwanza kuunganisha PIN na simu hii.',
    );
  }
  if (upper.contains('PIN_NOT_ENROLLED')) {
    return pick(
      'PIN is not ready on this phone yet. Finish fingerprint setup first.',
      'PIN bado haijaandaliwa kwenye simu hii. Kamilisha kwanza usanidi wa alama ya kidole.',
    );
  }
  if (upper.contains('IDENTITY_MISMATCH')) {
    return pick(
      'Use the same phone number or email linked to this fingerprint.',
      'Tumia namba ya simu au barua pepe ile ile iliyounganishwa na alama hii ya kidole.',
    );
  }
  if (upper.contains('BIOMETRIC_PARENT_REQUIRED')) {
    return pick(
      'Register fingerprint first before setting or using PIN.',
      'Sajili kwanza alama ya kidole kabla ya kuweka au kutumia PIN.',
    );
  }
  if (upper.contains('BIOMETRIC_PARENT_EXPIRED')) {
    return pick(
      'Fingerprint confirmation expired. Verify fingerprint again, then continue.',
      'Uthibitisho wa alama ya kidole umeisha muda. Thibitisha tena kisha endelea.',
    );
  }
  if (upper.contains('SHARED_POT_ACCESS_DENIED')) {
    return pick(
      'You do not have access to this shared pot.',
      'Huna ruhusa ya kutumia shared pot hii.',
    );
  }
  if (upper.contains('SHARED_POT_CONTRIBUTION_DENIED')) {
    return pick(
      'Your role cannot contribute to this shared pot.',
      'Role yako hairuhusu kuchangia kwenye shared pot hii.',
    );
  }
  if (upper.contains('SHARED_POT_WITHDRAW_DENIED')) {
    return pick(
      'Only the pot owner or manager can withdraw from this shared pot.',
      'Mmiliki au meneja wa pot pekee ndiye anaweza kutoa fedha kwenye shared pot hii.',
    );
  }
  if (upper.contains('INSUFFICIENT_POT_FUNDS')) {
    return pick(
      'This shared pot does not have enough money for that withdrawal.',
      'Shared pot hii haina fedha za kutosha kwa kutoa kiasi hicho.',
    );
  }
  if (upper.contains('USER_NOT_FOUND')) {
    return pick(
      'We could not find that ORBI user. Use their registered phone or email.',
      'Hatujampata mtumiaji huyo wa ORBI. Tumia simu au barua pepe yake iliyosajiliwa.',
    );
  }
  if (upper.contains('OWNER_ALREADY_MEMBER')) {
    return pick(
      'That person already owns this shared pot.',
      'Mtu huyo tayari ni mmiliki wa shared pot hii.',
    );
  }
  if (upper.contains('SHARED_POT_MEMBER_ALREADY_EXISTS')) {
    return pick(
      'That user is already a member of this shared pot.',
      'Mtumiaji huyo tayari ni mwanachama wa shared pot hii.',
    );
  }
  if (upper.contains('SHARED_POT_INVITE_ALREADY_PENDING')) {
    return pick(
      'An invitation for this user is already pending.',
      'Mwaliko wa mtumiaji huyu tayari unasubiri jibu.',
    );
  }
  if (upper.contains('SHARED_POT_INVITE_NOT_FOUND')) {
    return pick(
      'This invitation could not be found.',
      'Mwaliko huu haujapatikana.',
    );
  }
  if (upper.contains('SHARED_POT_INVITE_ACCESS_DENIED')) {
    return pick(
      'You cannot act on this invitation.',
      'Huwezi kuchukua hatua kwenye mwaliko huu.',
    );
  }
  if (upper.contains('SHARED_POT_INVITE_NOT_PENDING')) {
    return pick(
      'This invitation is no longer waiting for a response.',
      'Mwaliko huu hausubiri jibu tena.',
    );
  }
  if (upper.contains('SHARED_POT') &&
      containsAny([
        'SCHEMA CACHE',
        'RELATIONSHIP',
        'COLUMN',
        'RELATION',
        'TABLE',
        'ENDPOINT',
        'PGRST',
      ])) {
    return pick(
      'Shared pot details could not be loaded right now. Please refresh and try again.',
      'Taarifa za shared pot hazikuweza kupakiwa sasa. Tafadhali pakia upya kisha jaribu tena.',
    );
  }

  if (upper.contains('SHARED_BUDGET_ACCESS_DENIED')) {
    return pick(
      'You do not have access to this shared budget.',
      'Huna ruhusa ya kutumia shared budget hii.',
    );
  }
  if (upper.contains('SHARED_BUDGET_SPEND_DENIED')) {
    return pick(
      'Your role cannot spend from this shared budget.',
      'Role yako hairuhusu kutumia fedha za shared budget hii.',
    );
  }
  if (upper.contains('SHARED_BUDGET_LIMIT_EXCEEDED')) {
    return pick(
      'This shared budget does not have enough remaining amount for that spend.',
      'Shared budget hii haina kiasi kilichobaki cha kutosha kwa matumizi hayo.',
    );
  }
  if (upper.contains('SHARED_BUDGET_MEMBER_LIMIT_EXCEEDED')) {
    return pick(
      'That spend is above this member\'s allowed limit.',
      'Matumizi hayo yamezidi kikomo cha mwanachama huyu.',
    );
  }
  if (upper.contains('SHARED_BUDGET_MEMBER_ALREADY_EXISTS')) {
    return pick(
      'That user is already a member of this shared budget.',
      'Mtumiaji huyo tayari ni mwanachama wa shared budget hii.',
    );
  }
  if (upper.contains('SHARED_BUDGET_INVITE_ALREADY_PENDING')) {
    return pick(
      'An invitation for this user is already pending.',
      'Mwaliko wa mtumiaji huyu tayari unasubiri jibu.',
    );
  }
  if (upper.contains('SHARED_BUDGET_INVITE_NOT_FOUND')) {
    return pick(
      'This shared budget invitation could not be found.',
      'Mwaliko huu wa shared budget haujapatikana.',
    );
  }
  if (upper.contains('SHARED_BUDGET_INVITE_ACCESS_DENIED')) {
    return pick(
      'You cannot act on this shared budget invitation.',
      'Huwezi kuchukua hatua kwenye mwaliko huu wa shared budget.',
    );
  }
  if (upper.contains('SHARED_BUDGET_INVITE_NOT_PENDING')) {
    return pick(
      'This shared budget invitation is no longer waiting for a response.',
      'Mwaliko huu wa shared budget hausubiri jibu tena.',
    );
  }
  if (upper.contains('SHARED_BUDGET') &&
      containsAny([
        'SCHEMA CACHE',
        'RELATIONSHIP',
        'COLUMN',
        'RELATION',
        'TABLE',
        'ENDPOINT',
        'PGRST',
      ])) {
    return pick(
      'Shared budget details could not be loaded right now. Please refresh and try again.',
      'Taarifa za shared budget hazikuweza kupakiwa sasa. Tafadhali pakia upya kisha jaribu tena.',
    );
  }
  if (upper.contains('42501') ||
      upper.contains('ROW-LEVEL SECURITY') ||
      upper.contains('VIOLATES ROW-LEVEL SECURITY POLICY')) {
    return pick(
      'This action is blocked by account permissions right now. Please refresh your session or contact support if it continues.',
      'Hatua hii imezuiwa na ruhusa za akaunti kwa sasa. Tafadhali sasisha kikao chako au wasiliana na huduma kwa wateja ikiwa itaendelea.',
    );
  }
  if (upper.contains('SHARED_BUDGET_APPROVAL_NOT_FOUND')) {
    return pick(
      'That shared budget approval request could not be found.',
      'Ombi hilo la approval ya shared budget halijapatikana.',
    );
  }
  if (upper.contains('SHARED_BUDGET_APPROVAL_NOT_PENDING')) {
    return pick(
      'That shared budget approval request is no longer waiting for review.',
      'Ombi hilo la approval ya shared budget halisubiri ukaguzi tena.',
    );
  }
  if (upper.contains('GOAL_FUNDS_BILL_PAYMENT_NOT_ALLOWED')) {
    return pick(
      'Goal money is protected and cannot be used for bill payments.',
      'Fedha za goal zinalindwa na haziwezi kutumika kulipia bili.',
    );
  }
  if (upper.contains('BILL_RESERVE_NOT_FOUND')) {
    return pick(
      'That bill reserve could not be found anymore. Refresh and try again.',
      'Bill reserve hiyo haikupatikana tena. Sasisha kisha ujaribu tena.',
    );
  }
  if (upper.contains('BILL_RESERVE_INACTIVE')) {
    return pick(
      'This bill reserve is paused or no longer active.',
      'Bill reserve hii imesitishwa au haipo active tena.',
    );
  }
  if (upper.contains('BILL_RESERVE_INSUFFICIENT_BALANCE')) {
    return pick(
      'This bill reserve does not have enough protected balance for that payment.',
      'Bill reserve hii haina salio la kutosha kulipia kiasi hicho.',
    );
  }
  if (upper.contains('BILL_RESERVE_PROVIDER_MISMATCH') ||
      upper.contains('BILL_RESERVE_CATEGORY_MISMATCH') ||
      upper.contains('BILL_RESERVE_REFERENCE_MISMATCH')) {
    return pick(
      'This reserve does not match the selected bill details closely enough.',
      'Reserve hii hailingani vya kutosha na taarifa za bili ulizochagua.',
    );
  }
  if (containsAny([
    'SCHEMA CACHE',
    'COULD NOT FIND A RELATIONSHIP',
    'RELATIONSHIP BETWEEN',
    'COLUMN ',
    ' RELATION ',
    ' TABLE ',
    'PGRST',
    'POSTGREST',
    'SUPABASE',
    '/WEALTH/',
    '/API/',
    'DIOEXCEPTION',
    'SOCKETEXCEPTION',
    'TYPEERROR',
    'NOSUCHMETHODERROR',
    'NULL CHECK OPERATOR',
    'STACK TRACE',
    'HTTP://',
    'HTTPS://',
  ])) {
    return safeFallback();
  }

  return fallback ?? normalized;
}
