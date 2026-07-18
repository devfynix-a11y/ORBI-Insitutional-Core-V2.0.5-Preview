String mapBackendStatusMessage(
  String raw, {
  bool sw = false,
  String? fallback,
}) {
  final normalized = raw.trim().replaceFirst(
    RegExp(
      r'^(_?Exception|Error|DioException|FormatException|StateError|TypeError):\s*',
      caseSensitive: false,
    ),
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
  if (upper.contains('OTP_THROTTLED') ||
      upper.contains('TOO MANY') ||
      upper.contains('RATE LIMIT') ||
      upper.contains('429') ||
      upper.contains('THROTTLE')) {
    return pick(
      'Too many attempts. Please wait about 60 seconds, then try again.',
      'Majaribio ni mengi. Tafadhali subiri takriban sekunde 60, kisha jaribu tena.',
    );
  }
  if (upper.contains('INVALID_OTP') ||
      upper.contains('OTP INVALID') ||
      upper.contains('OTP EXPIRED') ||
      upper.contains('VERIFICATION CODE')) {
    return pick(
      'The OTP code is invalid or expired. Request a new code and try again.',
      'Msimbo wa OTP si sahihi au umeisha muda. Omba msimbo mpya kisha jaribu tena.',
    );
  }
  if (upper.contains('PASSWORD_RECENTLY_USED') ||
      upper.contains('INVALIDPASSWORDHISTORY')) {
    return pick(
      'Choose a new password you have not used before.',
      'Chagua nywila mpya ambayo hujawahi kutumia kabla.',
    );
  }
  if (upper.contains('INVALID_PASSWORD_POLICY') ||
      upper.contains('INVALID PASSWORD') ||
      upper.contains('PASSWORD MUST') ||
      upper.contains('MUST CONTAIN AT LEAST 1')) {
    return pick(
      'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      'Nywila lazima iwe na angalau herufi/tarakimu 8, herufi kubwa, herufi ndogo, namba, na alama maalum.',
    );
  }
  if (upper.contains('PASSWORD_RESET_CHALLENGE_REQUIRED')) {
    return pick(
      'Request and enter the OTP before changing your password.',
      'Omba na uweke OTP kabla ya kubadili nywila.',
    );
  }
  if (upper.contains('USE_EMAIL_FOR_NON_TZ_PASSWORD_RESET')) {
    return pick(
      'For accounts outside Tanzania, password reset works best with your registered email.',
      'Kwa akaunti zilizo nje ya Tanzania, kubadili nywila hufanya kazi vizuri kwa email uliyosajili.',
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
  if (upper.contains('PAYSAFE_ESCROW_QUERY_FAILED')) {
    return pick(
      'PaySafe records could not be loaded from the ledger. Please try again shortly.',
      'Taarifa za PaySafe hazikuweza kusomwa kutoka ledger. Tafadhali jaribu tena baada ya muda mfupi.',
    );
  }
  if (upper.contains('PAYSAFE_ESCROW_QUERY_TIMEOUT') ||
      upper.contains('PAYSAFE_ESCROW_CREATE_TIMEOUT') ||
      upper.contains('PAYSAFE_TRANSITION_TIMEOUT')) {
    return pick(
      'PaySafe is taking longer than expected. Please try again shortly.',
      'PaySafe inachukua muda kuliko kawaida. Tafadhali jaribu tena baada ya muda mfupi.',
    );
  }
  if (upper.contains('PAYSAFE_VAULT_NOT_FOUND')) {
    return pick(
      'Your PaySafe wallet is not ready yet. Refresh your wallet or contact support if this continues.',
      'Walleti yako ya PaySafe bado haijawa tayari. Sasisha walleti au wasiliana na support ikiwa itaendelea.',
    );
  }
  if (upper.contains('PAYSAFE_VAULT_UNAVAILABLE') ||
      upper.contains('PAYSAFE_VAULT_LOOKUP_FAILED')) {
    return pick(
      'PaySafe wallet service is temporarily unavailable. Please try again shortly.',
      'Huduma ya walleti ya PaySafe haipatikani kwa muda. Tafadhali jaribu tena baada ya muda mfupi.',
    );
  }
  if (upper.contains('VAULT_OFFLINE')) {
    return pick(
      'Vault service is offline. Please try again shortly.',
      'Huduma ya vault haipo hewani kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.',
    );
  }
  if (upper.contains('SERVICE_ROLE_REQUIRED')) {
    return pick(
      'PaySafe settlement service is not configured correctly. Please contact support.',
      'Huduma ya settlement ya PaySafe haijasanidiwa vizuri. Tafadhali wasiliana na support.',
    );
  }
  if (upper.contains('PAYSAFE_AMOUNT_INVALID')) {
    return pick(
      'Enter a valid PaySafe amount.',
      'Weka kiasi sahihi cha PaySafe.',
    );
  }
  if (upper.contains('PAYSAFE_DESCRIPTION_REQUIRED')) {
    return pick(
      'Enter a short PaySafe description.',
      'Weka maelezo mafupi ya PaySafe.',
    );
  }
  if (upper.contains('RECIPIENT_NOT_FOUND')) {
    return pick(
      'We could not find that recipient. Check their ORBI ID, phone, or email and try again.',
      'Hatukumpata mpokeaji huyo. Hakiki ORBI ID, simu, au email yake kisha jaribu tena.',
    );
  }
  if (upper.contains('PAYSAFE_SELF_ESCROW_NOT_ALLOWED')) {
    return pick(
      'You cannot create a PaySafe with yourself.',
      'Huwezi kutengeneza PaySafe na wewe mwenyewe.',
    );
  }
  if (upper.contains('OPERATING_WALLET_REQUIRED')) {
    return pick(
      'Your main wallet is not ready for PaySafe yet. Refresh your wallet or contact support.',
      'Walleti yako kuu bado haiko tayari kwa PaySafe. Sasisha walleti au wasiliana na support.',
    );
  }
  if (upper.contains('RECIPIENT_VAULT_NOT_FOUND')) {
    return pick(
      'The recipient wallet is not ready for PaySafe yet.',
      'Walleti ya mpokeaji bado haiko tayari kwa PaySafe.',
    );
  }
  if (upper.contains('PAYSAFE_SENDER_REGISTRY_INVALID')) {
    return pick(
      'This PaySafe can only be created from a customer account.',
      'PaySafe hii inaweza kuanzishwa na akaunti ya mteja pekee.',
    );
  }
  if (upper.contains('PAYSAFE_RECIPIENT_REGISTRY_INVALID')) {
    return pick(
      'This recipient type is not supported for this PaySafe flow yet.',
      'Aina hii ya mpokeaji bado haiungwi mkono kwenye PaySafe hii.',
    );
  }
  if (upper.contains('PAYSAFE_CURRENCY_MISMATCH')) {
    return pick(
      'Both PaySafe wallets must use the same currency.',
      'Walleti zote za PaySafe lazima zitumie sarafu moja.',
    );
  }
  if (upper.contains('INSUFFICIENT_FUNDS')) {
    return pick(
      'You do not have enough balance to create this PaySafe.',
      'Salio lako halitoshi kutengeneza PaySafe hii.',
    );
  }
  if (upper.contains('PAYSAFE_SENDER_ACCOUNT_NOT_ACTIVE') ||
      upper.contains('PAYSAFE_RECIPIENT_ACCOUNT_NOT_ACTIVE')) {
    return pick(
      'One of the accounts is not active for PaySafe.',
      'Moja ya akaunti haiko active kwa PaySafe.',
    );
  }
  if (upper.contains('ESCROW_ACCESS_DENIED')) {
    return pick(
      'You do not have access to this PaySafe.',
      'Huna ruhusa ya kuona PaySafe hii.',
    );
  }
  if (upper.contains('ESCROW_NOT_FOUND')) {
    return pick(
      'This PaySafe record could not be found.',
      'Taarifa hii ya PaySafe haijapatikana.',
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
      'You do not have access to this Fungu.',
      'Huna ruhusa ya kutumia Fungu hili.',
    );
  }
  if (upper.contains('SHARED_POT_CONTRIBUTION_DENIED')) {
    return pick(
      'Your role cannot contribute to this Fungu.',
      'Role yako hairuhusu kuchangia kwenye Fungu hili.',
    );
  }
  if (upper.contains('SHARED_POT_WITHDRAW_DENIED')) {
    return pick(
      'Only the Fungu owner or manager can withdraw from this Fungu.',
      'Mmiliki au meneja wa Fungu pekee ndiye anaweza kutoa fedha kwenye Fungu hili.',
    );
  }
  if (upper.contains('SHARED_POT_ORG_REQUIRED')) {
    return pick(
      'Organization Fungu requires your account to be linked to an organization.',
      'Fungu la taasisi linahitaji akaunti yako iwe imeunganishwa na taasisi.',
    );
  }
  if (upper.contains('SHARED_POT_PRIVATE_INVITES_DISABLED')) {
    return pick(
      'Personal Fungu does not allow member invitations.',
      'Fungu binafsi haliruhusu kualika wanachama.',
    );
  }
  if (upper.contains('SHARED_POT_ORG_MEMBER_REQUIRED')) {
    return pick(
      'Only users from the same organization can join this Fungu.',
      'Ni watumiaji wa taasisi hiyo hiyo pekee wanaoweza kujiunga na Fungu hili.',
    );
  }
  if (upper.contains('SHARED_POT_WITHDRAWAL_REASON_REQUIRED')) {
    return pick(
      'Enter a reason for this withdrawal request.',
      'Weka sababu ya ombi hili la kutoa fedha.',
    );
  }
  if (upper.contains('SHARED_POT_NOT_MATURED')) {
    return pick(
      'This Fungu is locked until its maturity date.',
      'Fungu hili limefungwa hadi tarehe yake ya ukomavu.',
    );
  }
  if (upper.contains('SHARED_POT_WITHDRAWAL_LIMIT_EXCEEDED')) {
    return pick(
      'This withdrawal is above the allowed Fungu limit.',
      'Kiasi hiki cha kutoa kimezidi kikomo cha Fungu.',
    );
  }
  if (upper.contains('SHARED_POT_WITHDRAW_SELF_APPROVAL_DENIED')) {
    return pick(
      'Another authorised member must approve this withdrawal.',
      'Mwanachama mwingine mwenye ruhusa lazima aidhinishe utoaji huu.',
    );
  }
  if (upper.contains('ORG_ADMIN_MAX_REACHED')) {
    return pick(
      'This organization already has two admins. Remove one admin before adding another.',
      'Taasisi hii tayari ina admins wawili. Ondoa admin mmoja kabla ya kuongeza mwingine.',
    );
  }
  if (upper.contains('ORG_ADMIN_MIN_REQUIRED')) {
    return pick(
      'This organization must keep at least one admin. Add another admin before removing this one.',
      'Taasisi lazima ibaki na angalau admin mmoja. Ongeza admin mwingine kabla ya kumuondoa huyu.',
    );
  }
  if (upper.contains('SHARED_POT_DELETE_BALANCE_NOT_EMPTY')) {
    return pick(
      'This Fungu must have a zero balance before it can be archived.',
      'Fungu hili lazima liwe na salio sifuri kabla ya kuhifadhiwa.',
    );
  }
  if (upper.contains('SHARED_POT_DELETE_DENIED') ||
      upper.contains('SHARED_POT_DELETE_APPROVAL_DENIED') ||
      upper.contains('SHARED_POT_DELETE_CANCEL_DENIED')) {
    return pick(
      'Only an authorised owner or manager can manage this archive request.',
      'Ni mmiliki au meneja mwenye ruhusa pekee anayeweza kusimamia ombi hili la kuhifadhi.',
    );
  }
  if (upper.contains('SHARED_POT_DELETE_ALREADY_REVIEWED')) {
    return pick(
      'You have already responded to this archive request.',
      'Tayari umejibu ombi hili la kuhifadhi.',
    );
  }
  if (upper.contains('SHARED_POT_DELETE_CANCEL_CLOSED') ||
      upper.contains('SHARED_POT_DELETE_REQUEST_NOT_PENDING')) {
    return pick(
      'This archive request can no longer be changed.',
      'Ombi hili la kuhifadhi haliwezi kubadilishwa tena.',
    );
  }
  if (upper.contains('SHARED_POT_DELETE_REQUEST_EXISTS')) {
    return pick(
      'There is already an active archive request for this Fungu.',
      'Tayari kuna ombi la kuhifadhi linaloendelea kwa Fungu hili.',
    );
  }
  if (upper.contains('INSUFFICIENT_POT_FUNDS')) {
    return pick(
      'This Fungu does not have enough money for that withdrawal.',
      'Fungu hili halina fedha za kutosha kwa kutoa kiasi hicho.',
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
      'That person already owns this Fungu.',
      'Mtu huyo tayari ni mmiliki wa Fungu hili.',
    );
  }
  if (upper.contains('SHARED_POT_MEMBER_ALREADY_EXISTS')) {
    return pick(
      'That user is already a member of this Fungu.',
      'Mtumiaji huyo tayari ni mwanachama wa Fungu hili.',
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
      'Fungu details could not be loaded right now. Please refresh and try again.',
      'Taarifa za Fungu hazikuweza kupakiwa sasa. Tafadhali pakia upya kisha jaribu tena.',
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
  if (upper.contains('SHARED_BUDGET_FUNDS_REQUIRED')) {
    return pick(
      'This Meza has no allocated funds. Allocate funds before spending.',
      'Meza hii haina fedha zilizotengwa. Weka fedha kwanza.',
    );
  }
  if (upper.contains('SHARED_BUDGET_ALLOCATE_DENIED')) {
    return pick(
      'Only the owner or manager can allocate funds to this Meza.',
      'Ni mmiliki au meneja pekee anaweza kuweka fedha kwenye Meza hii.',
    );
  }
  if (upper.contains('SHARED_BUDGET_ALLOCATION_LIMIT_EXCEEDED')) {
    return pick(
      'This allocation is above the Meza limit.',
      'Kiasi hiki cha kuweka fedha kimezidi kikomo cha Meza.',
    );
  }
  if (upper.contains('SHARED_BUDGET_NOT_FOUND')) {
    return pick(
      'This Meza could not be found. Please refresh and try again.',
      'Meza hii haijapatikana. Tafadhali pakia upya kisha jaribu tena.',
    );
  }
  if (upper.contains('INVALID UUID') ||
      upper.contains('INVALID_FORMAT') ||
      upper.contains('VALIDATION_FAILED')) {
    return pick(
      'Some request details are not valid. Please refresh and try again.',
      'Baadhi ya taarifa za ombi si sahihi. Tafadhali pakia upya kisha jaribu tena.',
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
