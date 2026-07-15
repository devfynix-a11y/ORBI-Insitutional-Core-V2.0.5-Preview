// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get settingsTitle => 'Mipangilio';

  @override
  String get languageTitle => 'Lugha';

  @override
  String get languageSubtitle =>
      'Chagua lugha unayopendelea kwa kiolesura cha programu.';

  @override
  String get notificationsTitle => 'Arifa';

  @override
  String get notificationsSubtitle =>
      'Sanidi jinsi unavyopokea arifa na taarifa.';

  @override
  String get languageEnglish => 'Kiingereza';

  @override
  String get languageEnglishSubtitle =>
      'Lugha chaguo-msingi kwa programu na huduma';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageSwahiliSubtitle => 'Lugha ya Kiswahili kwa Orbi';

  @override
  String get applyToAppLanguageTitle => 'Tumia kwenye lugha ya programu';

  @override
  String get applyToAppLanguageSubtitle =>
      'Badili lugha ya kiolesura cha programu.';

  @override
  String get applyToServicesTitle => 'Tumia kwenye huduma';

  @override
  String get applyToServicesSubtitle => 'Tumia lugha hii kwa arifa na ujumbe.';

  @override
  String get serviceNotificationsTitle => 'Arifa za huduma';

  @override
  String get securityAlertsTitle => 'Arifa za usalama';

  @override
  String get securityAlertsSubtitle =>
      'Majaribio ya kuingia, vifaa vipya, na ukaguzi wa usalama.';

  @override
  String get financialAlertsTitle => 'Arifa za kifedha';

  @override
  String get financialAlertsSubtitle => 'Miamala, malipo, na uhamisho.';

  @override
  String get budgetAlertsTitle => 'Arifa za bajeti';

  @override
  String get budgetAlertsSubtitle =>
      'Vikomo vya matumizi na taarifa za bajeti.';

  @override
  String get goalsTitle => 'Malengo na Bajeti';

  @override
  String get goalsSubtitle =>
      'Unda malengo ya akiba, hamisha fedha ndani yake, na panga vizuri mipaka ya matumizi ya kila siku.';

  @override
  String get goalsRefresh => 'Sasisha';

  @override
  String get goalsNewGoal => 'Lengo Jipya';

  @override
  String get goalsNewBudget => 'Bajeti Mpya';

  @override
  String get goalsNewTask => 'Kazi Mpya';

  @override
  String get goalsPlanningTitle => 'Mpango wa matumizi';

  @override
  String get goalsMetricGoals => 'Malengo';

  @override
  String get goalsMetricSaved => 'Uliyoweka';

  @override
  String get goalsMetricTarget => 'Lengo';

  @override
  String get goalsMetricBudgets => 'Bajeti';

  @override
  String get goalsTabGoals => 'Malengo';

  @override
  String get goalsTabBudget => 'Bajeti';

  @override
  String get goalsTabTasks => 'Kazi';

  @override
  String get goalsEmptyTitle => 'Hakuna malengo bado';

  @override
  String get goalsEmptyMessage =>
      'Unda lengo lako la kwanza na uanze kuhamisha fedha za pochi kwenda humo.';

  @override
  String get goalsBudgetEmptyTitle => 'Hakuna bajeti bado';

  @override
  String get goalsBudgetEmptyMessage =>
      'Unda makundi ya bajeti kwa chakula, usafiri, kodi na mengineyo.';

  @override
  String get goalsTasksEmptyTitle => 'Hakuna kazi bado';

  @override
  String get goalsTasksEmptyMessage =>
      'Ongeza kazi za mpango kufuatilia hatua zinazosaidia malengo yako kusonga mbele.';

  @override
  String get goalsDefaultGoalName => 'Lengo la akiba';

  @override
  String get goalsDefaultBudgetName => 'Kundi la bajeti';

  @override
  String get goalsTaskFallback => 'Kazi ya mpango';

  @override
  String get goalsDeadlineLabel => 'Mwisho wa muda';

  @override
  String get goalsAllocateButton => 'Tenga';

  @override
  String get goalsWithdrawButton => 'Toa';

  @override
  String get goalsDeleteButton => 'Futa';

  @override
  String get goalsEditButton => 'Hariri';

  @override
  String goalsBudgetLimit(String amount) {
    return 'Kikomo cha bajeti: $amount';
  }

  @override
  String get goalsHardLimit => 'Kikomo kigumu';

  @override
  String get goalsSoftLimit => 'Kikomo laini';

  @override
  String get goalsLoadFailedTitle => 'Imeshindikana kupakia malengo na bajeti';

  @override
  String get goalsCreateGoalTitle => 'Unda lengo';

  @override
  String get goalsEditGoalTitle => 'Hariri lengo';

  @override
  String get goalsGoalNameLabel => 'Jina la lengo';

  @override
  String get goalsTargetAmountLabel => 'Kiasi cha lengo';

  @override
  String get goalsFundingStrategyLabel => 'Mbinu ya ufadhili';

  @override
  String get goalsFundingManual => 'Kwa mkono';

  @override
  String get goalsFundingPercentage => 'Otomatiki kwa asilimia ya mapato';

  @override
  String get goalsFundingFixed => 'Otomatiki kwa kiasi cha mwezi';

  @override
  String get goalsAutoAllocationLabel => 'Washa mgao wa kiotomatiki';

  @override
  String get goalsAutoAllocationHint =>
      'Ruhusu Orbi kupeleka sehemu ya mapato yajayo kwenye lengo hili kiotomatiki.';

  @override
  String get goalsIncomePercentageLabel => 'Asilimia ya mapato';

  @override
  String get goalsIncomePercentageHint =>
      'Ni kiasi gani cha fedha zinazoingia kielekezwe hapa.';

  @override
  String get goalsMonthlyTargetLabel => 'Kiasi cha mwezi kiotomatiki';

  @override
  String get goalsMonthlyTargetHint =>
      'Kiasi maalum cha kuhamisha kwenda kwenye lengo hili kila mwezi.';

  @override
  String get goalsOptional => 'Si lazima';

  @override
  String get goalsGoalValidationMessage =>
      'Weka jina la lengo na kiasi sahihi cha lengo.';

  @override
  String get goalsIncomePercentageValidation =>
      'Weka asilimia sahihi ya mapato kwa mgao wa kiotomatiki.';

  @override
  String get goalsMonthlyTargetValidation =>
      'Weka kiasi sahihi cha mwezi kwa mgao wa kiotomatiki.';

  @override
  String get goalsGoalCreatedMessage => 'Lengo limeundwa.';

  @override
  String get goalsGoalUpdatedMessage => 'Lengo limesasishwa.';

  @override
  String get goalsSaveGoalButton => 'Hifadhi lengo';

  @override
  String get goalsUpdateGoalButton => 'Sasisha lengo';

  @override
  String get goalsCreateBudgetTitle => 'Unda bajeti';

  @override
  String get goalsEditBudgetTitle => 'Hariri bajeti';

  @override
  String get goalsCreateTaskTitle => 'Unda kazi';

  @override
  String get goalsEditTaskTitle => 'Hariri kazi';

  @override
  String get goalsCategoryNameLabel => 'Jina la kundi';

  @override
  String get goalsBudgetAmountLabel => 'Kiasi cha bajeti';

  @override
  String get goalsTaskTextLabel => 'Kazi';

  @override
  String get goalsTaskLinkedGoalLabel => 'Lengo lililounganishwa';

  @override
  String get goalsTaskNoLinkedGoal => 'Hakuna lengo lililounganishwa';

  @override
  String get goalsTaskBountyLabel => 'Kiasi cha zawadi';

  @override
  String get goalsTaskDuePickerLabel => 'Tarehe ya mwisho';

  @override
  String get goalsTaskCompletedToggle => 'Weka kuwa imekamilika';

  @override
  String get goalsBudgetValidationMessage =>
      'Weka jina la kundi na kiasi sahihi cha bajeti.';

  @override
  String get goalsTaskValidationMessage => 'Weka kazi kabla ya kuhifadhi.';

  @override
  String get goalsBudgetCreatedMessage => 'Bajeti imeundwa.';

  @override
  String get goalsBudgetUpdatedMessage => 'Bajeti imesasishwa.';

  @override
  String get goalsTaskCreatedMessage => 'Kazi imeundwa.';

  @override
  String get goalsTaskUpdatedMessage => 'Kazi imesasishwa.';

  @override
  String get goalsSaveBudgetButton => 'Hifadhi bajeti';

  @override
  String get goalsUpdateBudgetButton => 'Sasisha bajeti';

  @override
  String get goalsSaveTaskButton => 'Hifadhi kazi';

  @override
  String get goalsUpdateTaskButton => 'Sasisha kazi';

  @override
  String goalsAllocateSheetTitle(String name) {
    return 'Tenga kwenda kwa $name';
  }

  @override
  String get goalsAllocateFallbackName => 'lengo';

  @override
  String get goalsNoSourceWalletsMessage =>
      'Hakuna pochi iliyopatikana kwa hatua hii kwenye akaunti yako.';

  @override
  String get goalsNoDestinationWalletsMessage =>
      'Hakuna pochi ya marudio iliyopatikana kwa hatua hii kwenye akaunti yako.';

  @override
  String get goalsSourceWalletLabel => 'Pochi ya chanzo';

  @override
  String get goalsDestinationWalletLabel => 'Pochi ya marudio';

  @override
  String get goalsAmountLabel => 'Kiasi';

  @override
  String get goalsAllocateValidationMessage =>
      'Chagua pochi na uweke kiasi sahihi.';

  @override
  String get goalsAllocatedMessage => 'Fedha zimetengwa kwenda kwenye lengo.';

  @override
  String get goalsAllocateFundsButton => 'Tenga fedha';

  @override
  String goalsWithdrawSheetTitle(String name) {
    return 'Toa kutoka $name';
  }

  @override
  String get goalsWithdrawLockedHint =>
      'Fedha za lengo zinalindwa. Utoaji wake unapaswa kuwa wa makusudi na wa wazi.';

  @override
  String get goalsWithdrawValidationMessage =>
      'Chagua pochi ya marudio na uweke kiasi sahihi.';

  @override
  String get goalsWithdrawnMessage => 'Fedha zimetolewa kutoka kwenye lengo.';

  @override
  String get goalsWithdrawFundsButton => 'Toa fedha';

  @override
  String get goalsDeleteGoalTitle => 'Futa lengo';

  @override
  String get goalsDeleteGoalMessage =>
      'Lengo hili litaondolewa kwenye mpango wako.';

  @override
  String get goalsDeletedMessage => 'Lengo limefutwa.';

  @override
  String get goalsDeleteBudgetTitle => 'Futa bajeti';

  @override
  String get goalsDeleteBudgetMessage => 'Kundi hili la bajeti litaondolewa.';

  @override
  String get goalsBudgetDeletedMessage => 'Bajeti imefutwa.';

  @override
  String get goalsDeleteTaskTitle => 'Futa kazi';

  @override
  String get goalsDeleteTaskMessage => 'Kazi hii ya mpango itaondolewa.';

  @override
  String get goalsTaskDeletedMessage => 'Kazi imefutwa.';

  @override
  String get goalsTaskCompletedMessage => 'Kazi imekamilika.';

  @override
  String get goalsTaskReopenedMessage => 'Kazi imefunguliwa tena.';

  @override
  String get goalsContinueAction => 'Endelea';

  @override
  String get goalsFlexibleDate => 'Inabadilika';

  @override
  String get goalsTaskCompleted => 'Imekamilika';

  @override
  String get goalsTaskPending => 'Inasubiri';

  @override
  String get goalsTaskDueLabel => 'Mwisho';

  @override
  String goalsTaskLinkedGoal(String name) {
    return 'Lengo: $name';
  }

  @override
  String goalsTaskBounty(String amount) {
    return 'Zawadi: $amount';
  }

  @override
  String get marketingUpdatesTitle => 'Taarifa za matangazo';

  @override
  String get marketingUpdatesSubtitle =>
      'Matangazo, vidokezo, na matangazo ya bidhaa.';

  @override
  String get applyToAppButton => 'Tumia kwenye Programu';

  @override
  String get applyToServicesButton => 'Tumia kwenye Huduma';

  @override
  String get applyAllButton => 'Tumia Zote';

  @override
  String get applyButton => 'Tumia';

  @override
  String get applyingButton => 'Inaweka...';

  @override
  String appLanguageSetMessage(String language) {
    return 'Lugha ya programu imewekwa kuwa $language.';
  }

  @override
  String get appLanguageFollowSystemMessage =>
      'Lugha ya programu itafuata mipangilio ya mfumo.';

  @override
  String get appLoadingStatus => 'Inapakia ORBI';

  @override
  String get appLoadingDetail =>
      'Tunaandaa nafasi yako salama ya kazi na kurejesha kikao chako.';

  @override
  String get preferencesLoadingStatus => 'Inapakia mapendeleo yako';

  @override
  String get preferencesLoadingDetail =>
      'Tunalinganisha lugha, mandhari, na mipangilio ya kifaa chako.';

  @override
  String get inactivityWarningTitle => 'Bado unatumia ORBI?';

  @override
  String get inactivityWarningMessage =>
      'Programu itafungwa hivi karibuni kwa sababu ya kutotumika.';

  @override
  String inactivityWarningCountdown(int seconds) {
    return 'Inafunga ndani ya sekunde $seconds';
  }

  @override
  String get inactivityWarningStayButton => 'Bado natumia ORBI?';

  @override
  String get actionCancel => 'Ghairi';

  @override
  String get actionVerify => 'Thibitisha';

  @override
  String get actionLogout => 'Toka';

  @override
  String get actionSetUpNow => 'Weka Sasa';

  @override
  String get actionUnlock => 'Fungua';

  @override
  String get actionSendLink => 'Tuma Kiungo';

  @override
  String get actionSubmit => 'Wasilisha';

  @override
  String get actionUpdate => 'Sasisha';

  @override
  String get actionSave => 'Hifadhi';

  @override
  String get actionClose => 'Funga';

  @override
  String get actionRetry => 'Jaribu Tena';

  @override
  String get actionOk => 'Sawa';

  @override
  String get actionAddCard => 'Ongeza Kadi';

  @override
  String get actionPrintReceipt => 'Chapisha Risiti';

  @override
  String get actionDownloadPrint => 'Pakua / Chapisha';

  @override
  String get actionShareReceipt => 'Shiriki Risiti';

  @override
  String get actionCreateRequest => 'Unda Ombi';

  @override
  String get actionScanAgain => 'Changanua Tena';

  @override
  String get actionFromGallery => 'Kutoka Galeria';

  @override
  String get actionCapture => 'Piga Picha';

  @override
  String get actionLogin => 'Ingia';

  @override
  String get labelEmail => 'Barua pepe';

  @override
  String get labelPassword => 'Nenosiri';

  @override
  String get loginEnterEmailPasswordMessage =>
      'Weka barua pepe na nenosiri ili kuingia.';

  @override
  String get loginInvalidPinMessage => 'PIN si sahihi.';

  @override
  String get loginEnterPinTitle => 'Weka PIN';

  @override
  String get loginPinLabel => 'PIN ya tarakimu 4-6';

  @override
  String get loginEnterOtpTitle => 'Weka OTP';

  @override
  String get loginOtpCodeLabel => 'Msimbo';

  @override
  String get loginBiometricSetupRequiredTitle =>
      'Usajili wa Biometriki Unahitajika';

  @override
  String get loginBiometricSetupRequiredBody =>
      'Ili kuendelea, lazima usajili biometriki ya kifaa chako. Hii inahitajika na sera ya usalama ya akaunti yako.';

  @override
  String get loginBiometricSetupFailedMessage =>
      'Usajili wa biometriki haukufaulu. Tafadhali jaribu tena.';

  @override
  String get loginResetPasswordTitle => 'Weka Upya Nenosiri';

  @override
  String get loginEmailHint => 'user@example.com';

  @override
  String get loginResetLinkSentMessage =>
      'Ikiwa akaunti ipo, barua pepe ya kuweka upya nenosiri imetumwa.';

  @override
  String get loginResetFailedMessage =>
      'Imeshindikana kuanzisha mchakato wa kuweka upya nenosiri.';

  @override
  String get loginOrbiLoginTitle => 'INGIA ORBI';

  @override
  String get loginSecureDeviceAttached => 'Kifaa salama kimeunganishwa';

  @override
  String get loginAuthenticateWithBiometric =>
      'Thibitisha kwa alama ya kidole au uso';

  @override
  String get loginBiometricFallbackHint =>
      'Ikiwa dirisha la uthibitisho halifunguki, tumia kuingia kwa nenosiri hapa chini.';

  @override
  String get loginSecurityVerificationTitle => 'Uthibitisho wa usalama';

  @override
  String get loginAuthenticatingSecurely => 'Inaingiza akaunti yako...';

  @override
  String get loginAuthenticating => 'Inaingia...';

  @override
  String get loginUsePasswordInstead => 'Tumia Nenosiri Badala Yake';

  @override
  String get loginUsePinInstead => 'Tumia PIN Badala Yake';

  @override
  String get loginOrbiTagline => 'ORBI Financial Technologies';

  @override
  String get loginWelcomeTitle => 'Karibu ORBI';

  @override
  String get appBarGreetingMorning => 'Habari za asubuhi';

  @override
  String get appBarGreetingAfternoon => 'Habari za mchana';

  @override
  String get appBarGreetingEvening => 'Habari za jioni';

  @override
  String get appBarCustomerIdLabel => 'ID';

  @override
  String get dashboardLinkedCardsTitle => 'Kadi zilizounganishwa';

  @override
  String get dashboardLinkedCardsEmptyTitle =>
      'Bado hakuna kadi zilizounganishwa';

  @override
  String get dashboardLinkedCardsEmptyMessage =>
      'Unganisha wallet yako ili kudhibiti utajiri wako.';

  @override
  String get loginSecureSignInSubtitle =>
      'Ingia kwa usalama kwa nenosiri au biometriki.';

  @override
  String get loginUseFingerprintButton => 'Tumia Alama ya Kidole / Face ID';

  @override
  String get loginOrUsePassword => 'au tumia nenosiri';

  @override
  String get loginBiometricTemporarilyLocked =>
      'Biometriki imefungwa kwa muda. Tumia kuingia kwa nenosiri.';

  @override
  String get loginBiometricMissing =>
      'Usajili wa biometriki haujapatikana. Tafadhali ingia kwa nenosiri mara moja, kisha washa tena biometriki kwenye Mipangilio.';

  @override
  String get loginUnlockWithPin => 'Fungua kwa PIN';

  @override
  String get loginForgotPassword => 'Umesahau nenosiri?';

  @override
  String get loginNewUserCreateAccount => 'Mtumiaji mpya? Fungua akaunti';

  @override
  String get signupAcceptTermsMessage =>
      'Tafadhali kubali masharti ili kuendelea.';

  @override
  String get signupCreateAccountTitle => 'Fungua akaunti yako ya ORBI';

  @override
  String get signupSubtitle => 'Usajili salama unaounganishwa na ORBI backend.';

  @override
  String get signupStepPersonalInfo => 'Taarifa binafsi';

  @override
  String get signupStepContactDetails => 'Maelezo ya mawasiliano';

  @override
  String get signupStepVerification => 'Uthibitisho';

  @override
  String get signupStepShortInfo => 'Taarifa';

  @override
  String get signupStepShortCountry => 'Nchi';

  @override
  String get signupStepShortVerify => 'Thibitisha';

  @override
  String get signupSecurityVerificationTitle => 'Uthibitisho wa usalama';

  @override
  String get signupSecurityVerificationHelper =>
      'Weka OTP iliyotumwa kwenye mawasiliano yako yaliyosajiliwa ili kuendelea na usanidi salama.';

  @override
  String get signupSelectLanguageTitle => 'Chagua lugha';

  @override
  String get signupAboutYouTitle => 'Tuambie kidogo kukuhusu';

  @override
  String get signupAboutYouSubtitle =>
      'Tupatie maelezo machache ili ORBI ikupe huduma zinazokufaa tangu mwanzo.';

  @override
  String get signupAddressHelper =>
      'Weka anuani yako ili tukupangie huduma na ofa zinazokufaa zaidi. (Sio lazima)';

  @override
  String get signupChooseCountryTitle => 'Chagua nchi yako';

  @override
  String get signupChooseCountrySubtitle =>
      'Chagua nchi yako ili ORBI ikupangie lugha, sarafu, na huduma zinazoendana na soko lako.';

  @override
  String get signupLanguageLabel => 'Lugha';

  @override
  String get signupCurrencyLabel => 'Sarafu';

  @override
  String get signupPhoneHelper =>
      'Weka namba yako ya simu ya kawaida tu. Msimbo wa nchi utaongezwa moja kwa moja.';

  @override
  String get signupNationalityHelper =>
      'Taarifa hii imejazwa kwa kuzingatia nchi yako, lakini unaweza kuibadili ukihitaji.';

  @override
  String get signupSecureAccountTitle => 'Linda akaunti yako';

  @override
  String get signupSecureAccountSubtitle =>
      'Weka nenosiri imara ili pesa zako, ofa zako, na shughuli zako za biashara zibaki salama.';

  @override
  String get secureAccountSetupTitle => 'Linda akaunti yako';

  @override
  String get secureAccountSetupSubtitle =>
      'Usajili umefanikiwa. Maliza hatua hizi mbili za usalama kabla ya kuingia kwenye ORBI.';

  @override
  String get secureAccountSetupRegisterFingerprintFirst =>
      'Sajili fingerprint kwanza, kisha weka PIN.';

  @override
  String get secureAccountSetupPinMismatch =>
      'Weka PIN ya namba 4 na uthibitishe sawa.';

  @override
  String get secureAccountSetupSuccess =>
      'Fingerprint na PIN zimehifadhiwa salama.';

  @override
  String get secureAccountSetupPinEnrollFailed =>
      'Imeshindikana kuhifadhi PIN kwa usalama.';

  @override
  String get secureAccountSetupBiometricReady =>
      'Fingerprint imesajiliwa. Sasa weka PIN ili ukamilishe.';

  @override
  String get secureAccountSetupLoading =>
      'Tunaimarisha usalama wa akaunti yako...';

  @override
  String get secureAccountStepFingerprintTitle => 'Sajili fingerprint';

  @override
  String get secureAccountStepFingerprintMessage =>
      'Biometriki itaruhusu kuingia kwa haraka na salama.';

  @override
  String get secureAccountStepPinTitle => 'Weka PIN';

  @override
  String get secureAccountStepPinMessage =>
      'PIN itatumika kwa vitendo vya fedha na ufunguaji wa haraka.';

  @override
  String get secureAccountSignOutInstead => 'Toka kwenye akaunti hii';

  @override
  String get actionRegisterNow => 'Sajili sasa';

  @override
  String get commonDone => 'Imekamilika';

  @override
  String get commonReady => 'Imewekwa';

  @override
  String get signupAgreeTermsTitle => 'Nakubali masharti na vigezo vya ORBI';

  @override
  String get signupAgreeTermsSubtitle =>
      'Kwa kujiunga na ORBI, unapata njia salama zaidi ya kupokea mshahara, kusimamia matumizi, kupata ofa, na kujenga maisha bora ya kifedha kwa kujiamini.';

  @override
  String get signupReviewTitle => 'Mapitio ya usajili';

  @override
  String get signupReviewNameFallback => 'Jina lako';

  @override
  String get signupReviewEmailFallback => 'Barua pepe bado';

  @override
  String get signupEasyOnboardingBadge => 'Usajili rahisi';

  @override
  String get signupPersonalizedBadge => 'Imeundwa kwa ajili yako';

  @override
  String get signupSafeSecureBadge => 'Salama na ya kuaminika';

  @override
  String get signupHeroSubtitle =>
      'Fungua akaunti yako ya ORBI kwa hatua chache rahisi na uanze kusimamia pesa, malipo, na fursa zako kwa kujiamini zaidi.';

  @override
  String signupStepCounter(String current, String total, String title) {
    return 'Hatua ya $current kati ya $total • $title';
  }

  @override
  String get signupSignInButton => 'Ingia';

  @override
  String get signupBackButton => 'Rudi';

  @override
  String get signupNextButton => 'Endelea';

  @override
  String get signupSubmittingButton => 'Inawasilisha...';

  @override
  String get labelFullName => 'Jina kamili';

  @override
  String get signupFullNameRequired => 'Jina kamili linahitajika';

  @override
  String get signupFullNameInvalid => 'Weka jina sahihi';

  @override
  String get labelCountry => 'Nchi';

  @override
  String get labelPhoneNumber => 'Namba ya simu';

  @override
  String get signupPhoneRequired => 'Namba ya simu inahitajika';

  @override
  String get signupPhoneInvalid => 'Weka namba sahihi ya simu';

  @override
  String get labelNationality => 'Uraia';

  @override
  String get labelAddress => 'Anuani';

  @override
  String get labelPreferredCurrency => 'Sarafu unayopendelea';

  @override
  String get labelEmailAddress => 'Anwani ya barua pepe';

  @override
  String get signupEmailRequired => 'Barua pepe inahitajika';

  @override
  String get signupEmailInvalid => 'Weka barua pepe sahihi';

  @override
  String get signupPasswordRequired => 'Nenosiri linahitajika';

  @override
  String get signupPasswordMin => 'Tumia angalau herufi 8';

  @override
  String get labelConfirmPassword => 'Thibitisha nenosiri';

  @override
  String get signupPasswordsMismatch => 'Nenosiri halifanani';

  @override
  String get signupAgreeTerms => 'Nakubali Masharti na Sera ya Faragha';

  @override
  String get actionCreateAccount => 'Fungua Akaunti';

  @override
  String get signupAlreadyHaveAccount => 'Una akaunti tayari? Ingia';

  @override
  String get onboardingWelcomeTitle => 'Karibu ORBI';

  @override
  String get onboardingWelcomeSubtitle =>
      'Hapa ndipo safari yako rahisi na salama ya kifedha inaanza.';

  @override
  String get onboardingHeroTitle =>
      'Huduma ya kifedha iliyoandaliwa kukusaidia kukuza maisha yako.';

  @override
  String get onboardingHeroSubtitle =>
      'Pokea mshahara, tuma pesa, lipa bili, simamia matumizi ya biashara, na unufaike na wafanyabiashara unaowaamini ukiwa na udhibiti zaidi na mawazo ya utulivu.';

  @override
  String get onboardingBadgeFast => 'Haraka';

  @override
  String get onboardingBadgeEveryday => 'Thamani ya kila siku';

  @override
  String get onboardingBadgeSecure => 'Salama';

  @override
  String get onboardingPromo1Badge => 'Kujiamini kwanza';

  @override
  String get onboardingPromo1Title =>
      'Pata amani ya moyo kila unapohamisha pesa';

  @override
  String get onboardingPromo1Body =>
      'Kuanzia kutuma pesa hadi kulipa bili, ORBI husaidia pesa zako zifike salama na kwa urahisi ili uwe huru kuendelea na maisha bila wasiwasi wa kila mara.';

  @override
  String get onboardingPromo2Badge => 'Nguvu ya mshahara';

  @override
  String get onboardingPromo2Title =>
      'Fanya mshahara wako kuwa na thamani zaidi tangu siku ya kwanza';

  @override
  String get onboardingPromo2Body =>
      'Pokea mshahara, hudumia familia, lipa mahitaji muhimu, na panga mbele kwa utulivu zaidi ili kila siku ya malipo ikusogeze karibu na malengo yako.';

  @override
  String get onboardingPromo3Badge => 'Maisha nadhifu';

  @override
  String get onboardingPromo3Title =>
      'Tumia kwa mpangilio, gundua thamani, na epuka mshangao';

  @override
  String get onboardingPromo3Body =>
      'Baki ndani ya bajeti, nunua kwa wafanyabiashara unaowaamini, na ufurahie ofa bora kupitia huduma inayofanya matumizi ya kila siku yawe mepesi, wazi, na yenye mpangilio.';

  @override
  String get onboardingPromo4Badge => 'Tayari kwa biashara';

  @override
  String get onboardingPromo4Title =>
      'Imejengwa kwa watu wenye malengo na biashara zinazokua';

  @override
  String get onboardingPromo4Body =>
      'Iwe unasimamia pesa zako mwenyewe, bajeti za timu, au malipo ya wafanyabiashara, ORBI inakupa njia salama, iliyopangwa, na ya kuaminika zaidi ya kukua.';

  @override
  String get onboardingTermsTitle => 'Masharti kwa ufupi';

  @override
  String get onboardingTermsSubtitle =>
      'Kabla ya kufungua akaunti, pitia kwa ufupi mambo ya msingi yanayosaidia kuweka akaunti na malipo yako salama.';

  @override
  String get onboardingTermsHighlight1 =>
      'Tumia taarifa sahihi za utambulisho, mawasiliano, na nchi unapofungua akaunti yako.';

  @override
  String get onboardingTermsHighlight2 =>
      'Linda nenosiri lako, misimbo ya OTP, na biometriki ili hakuna mtu mwingine aweze kutumia akaunti yako.';

  @override
  String get onboardingTermsHighlight3 =>
      'Baadhi ya malipo na hatua za akaunti zinaweza kuhitaji uthibitisho kwa usalama wako.';

  @override
  String get onboardingTermsHighlight4 =>
      'Baadhi ya huduma zinaweza kuhitaji ukaguzi wa ziada kabla ya kuwashwa kikamilifu.';

  @override
  String get onboardingTermsConfirm =>
      'Utakubali masharti haya tena kabla ya kukamilisha usajili wa akaunti yako.';

  @override
  String get actionBack => 'Rudi';

  @override
  String get actionNext => 'Endelea';

  @override
  String get actionViewAll => 'Angalia Zote';

  @override
  String get profileMakePaymentTitle => 'Fanya Malipo';

  @override
  String get profileScanQrCodeTitle => 'Changanua Msimbo wa QR';

  @override
  String get profileScanQrAction => 'Changanua QR';

  @override
  String get paymentFlashOn => 'Washa mwanga';

  @override
  String get paymentFlashOff => 'Zima mwanga';

  @override
  String get paymentQrPrompt =>
      'Elekeza kamera kwenye QR code ili kuchanganua.';

  @override
  String paymentScannedValue(String value) {
    return 'Thamani iliyochanganuliwa:\n$value';
  }

  @override
  String get paymentNoReceiptSelected =>
      'Hakuna risiti au hati iliyochaguliwa.\nPiga picha au leta kutoka chini.';

  @override
  String paymentSavedPath(String path) {
    return 'Njia iliyohifadhiwa: $path';
  }

  @override
  String get paymentAnalyzing => 'Inachambua...';

  @override
  String get paymentAnalyzeReceipt => 'Chambua Risiti';

  @override
  String get paymentExtractedDetails => 'Taarifa Zilizopatikana';

  @override
  String get paymentMerchantLabel => 'Mfanyabiashara';

  @override
  String get paymentAmountLabel => 'Kiasi';

  @override
  String get paymentDateLabel => 'Tarehe';

  @override
  String get walletTitle => 'Utajiri';

  @override
  String get shellSessionExpiredMessage =>
      'Muda wa kikao umeisha. Tafadhali ingia tena.';

  @override
  String get shellNoNetworkMessage =>
      'Hakuna muunganisho wa intaneti. Tafadhali angalia mtandao kisha ujaribu tena.';

  @override
  String get shellStartupFailedMessage =>
      'Imeshindikana kupakia taarifa za mwanzo. Tafadhali jaribu tena.';

  @override
  String get shellStartupUnavailableTitle => 'Taarifa za mwanzo hazijapatikana';

  @override
  String get shellQuickActionsTitle => 'Vitendo vya haraka';

  @override
  String get shellQuickActionsSubtitle =>
      'Fikia haraka huduma za fedha unazotumia zaidi.';

  @override
  String get shellActionTransfer => 'Tuma';

  @override
  String get shellActionRequest => 'Omba';

  @override
  String get shellActionScanPay => 'Scan na Lipa';

  @override
  String get shellActionAlerts => 'Arifa';

  @override
  String get shellNavHome => 'Nyumbani';

  @override
  String get shellNavTransactions => 'Miamala';

  @override
  String get shellNavGoals => 'Malengo';

  @override
  String get shellBootstrapSubtitle => 'Jukwaa Lako Salama la Kifedha';

  @override
  String get shellOfflineBanner =>
      'Haupo mtandaoni au masasisho ya moja kwa moja yamesimama. Baadhi ya taarifa zinaweza kuwa za zamani.';

  @override
  String get shellPleaseWaitMoment => 'Tafadhali subiri kidogo...';

  @override
  String walletFeatureComingSoon(String feature) {
    return '$feature inakuja hivi karibuni';
  }

  @override
  String get walletSubtitle =>
      'Muonekano wa wazi wa akaunti zako, salio, na uwezo wako wa kifedha';

  @override
  String walletProvisioningPreparingAuto(String current, String total) {
    return 'Tunaandaa akaunti zako za utajiri na kadi yako. Inaendelea kusasishwa yenyewe... ($current/$total)';
  }

  @override
  String get walletProvisioningPreparingManual =>
      'Bado tunaandaa akaunti zako za utajiri na kadi yako. Buruta chini kusasisha.';

  @override
  String get walletTotalBalanceTitle => 'Jumla ya Salio la Utajiri';

  @override
  String walletAccountsCount(String count) {
    return 'Akaunti $count';
  }

  @override
  String get walletFilterAll => 'Zote';

  @override
  String get walletFilterOrbi => 'Orbi';

  @override
  String get walletFilterLinked => 'Zilizounganishwa';

  @override
  String get walletShowBalances => 'Onyesha salio';

  @override
  String get walletHideBalances => 'Ficha salio';

  @override
  String get walletQuickTransfer => 'Tuma';

  @override
  String get walletQuickTopUp => 'Ongeza Salio';

  @override
  String get walletQuickLinkAccount => 'Unganisha Akaunti';

  @override
  String get walletQuickSendMoney => 'Kutuma pesa';

  @override
  String get walletQuickTopUpFlow => 'Huduma ya kuongeza salio';

  @override
  String get walletQuickLinkAccountFlow => 'Huduma ya kuunganisha akaunti';

  @override
  String walletIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get walletTransactionsButton => 'Miamala';

  @override
  String get walletFetchTransactionsFailed =>
      'Imeshindikana kupata miamala ya akaunti hii kwa sasa.';

  @override
  String walletTransactionsTitle(String wallet) {
    return 'Miamala ya $wallet';
  }

  @override
  String get walletNoTransactionsFound =>
      'Hakuna miamala iliyopatikana kwenye akaunti hii.';

  @override
  String walletTransactionRef(String ref) {
    return 'Rejea: $ref';
  }

  @override
  String get walletFailedLoadAccounts =>
      'Imeshindikana kupakia akaunti za utajiri';

  @override
  String get walletNoAccountsYet =>
      'Bado hakuna akaunti za utajiri zilizopatikana.';

  @override
  String get walletNoAccountsMatchFilter =>
      'Hakuna akaunti zinazolingana na kichujio hiki.';

  @override
  String get walletMainCardShownTop =>
      'Kadi yako kuu ya akaunti inaonyeshwa juu.';

  @override
  String get walletLoadingAccounts => 'Inapakia akaunti za utajiri...';

  @override
  String get dashboardNetWorth => 'Jumla ya Utajiri';

  @override
  String get dashboardLifecycleTitle => 'Mzunguko wa fedha';

  @override
  String get dashboardUnallocated => 'Haijatengwa';

  @override
  String get dashboardAllocated => 'Imetengwa';

  @override
  String get dashboardSecure => 'Salama';

  @override
  String dashboardThisMonth(String value) {
    return '$value% mwezi huu';
  }

  @override
  String get dashboardPortfolio => 'Mkusanyiko wa Fedha';

  @override
  String get dashboardLinkedWallets => 'Wallet Zilizounganishwa';

  @override
  String get dashboardOrbiWallet => 'Wallet ya Orbi';

  @override
  String get dashboardInternalAccounts => 'Akaunti za Ndani';

  @override
  String get dashboardReadyToUse => 'Tayari kutumika';

  @override
  String get dashboardAnalyzingBehavior =>
      'Inachambua mwenendo wako wa kifedha...';

  @override
  String get dashboardInsightWedge => 'Muhtasari wa Maarifa';

  @override
  String get dashboardInsightsSubtitle =>
      'Tahadhari, mapendekezo, na ushauri wa kifedha unaotengenezwa na AI.';

  @override
  String get dashboardNoInsightsTitle => 'Bado hakuna maarifa yaliyopatikana';

  @override
  String get dashboardNoInsightsMessage =>
      'Maarifa yataonekana baada ya shughuli zako za hivi karibuni za kifedha kuchambuliwa.';

  @override
  String get dashboardSpendingAlerts => 'Tahadhari za Matumizi';

  @override
  String get dashboardBudgetSuggestions => 'Mapendekezo ya Bajeti';

  @override
  String get dashboardFinancialAdvice => 'Ushauri wa Kifedha';

  @override
  String get dashboardNoItemsNow => 'Kwa sasa hakuna taarifa za kuonyesha.';

  @override
  String get settingsBiometricDisabledMessage =>
      'Kuingia kwa biometriki kumezimwa';

  @override
  String get settingsSetPinTitle => 'Weka PIN';

  @override
  String get settingsPinsInvalidMessage => 'PIN hazifanani au si sahihi.';

  @override
  String get settingsChangePinTitle => 'Badilisha PIN';

  @override
  String get settingsCurrentPinIncorrectMessage => 'PIN ya sasa si sahihi.';

  @override
  String get settingsNewPinInvalidMessage =>
      'PIN mpya si sahihi au hailingani.';

  @override
  String get settingsPinUpdatedMessage => 'PIN imesasishwa kwa mafanikio.';

  @override
  String get settingsChangePasswordTitle => 'Badilisha Nenosiri';

  @override
  String get settingsPasswordMinMessage =>
      'Nenosiri lazima liwe na angalau herufi 8.';

  @override
  String get settingsPasswordsNoMatchMessage => 'Manenosiri hayafanani.';

  @override
  String get settingsChooseFromGallery => 'Chagua kutoka galeria';

  @override
  String get settingsTakePhoto => 'Piga picha';

  @override
  String get settingsUpdateKycInformation => 'Sasisha Taarifa za KYC';

  @override
  String get settingsUploadIdFirstMessage =>
      'Pakia picha ya kitambulisho kwanza';

  @override
  String get settingsEnterIdNumberMessage => 'Weka namba ya kitambulisho';

  @override
  String get settingsKycSubmittedMessage => 'KYC imewasilishwa kwa ukaguzi';

  @override
  String get settingsLogoutTitle => 'Toka';

  @override
  String get settingsLogoutConfirmMessage => 'Una uhakika unataka kutoka?';

  @override
  String get sendMoneySearchRecipientMessage =>
      'Tafuta na thibitisha mpokeaji kabla ya kuendelea';

  @override
  String get sendMoneyEnterValidAmountMessage => 'Weka kiasi sahihi';

  @override
  String get sendMoneySessionExpiredMessage =>
      'Muda wa kikao umekwisha. Tafadhali ingia tena.';

  @override
  String get sendMoneyTransferBlockedMessage =>
      'Uhamisho huu umezuiwa kwa usalama.';

  @override
  String get sendMoneyVerificationSuccessMessage =>
      'Uthibitishaji umefanikiwa. Inaendelea...';

  @override
  String get sendMoneyTitle => 'Tuma Pesa';

  @override
  String requestMoneyCreatedMessage(String from, String amount) {
    return 'Ombi limeundwa kwa $from ($amount)';
  }

  @override
  String get requestMoneyTitle => 'Omba Pesa';

  @override
  String get enterpriseTitle => 'Biashara';

  @override
  String get enterpriseEnableAutoSweepTitle => 'Wezesha Auto-sweep';

  @override
  String get enterpriseAutoSweepUpdatedMessage => 'Auto-sweep imesasishwa';

  @override
  String get enterpriseApprovalSubmittedMessage => 'Uidhinishaji umepelekwa';

  @override
  String get paymentScannerTitle => 'Kichanganua';

  @override
  String get paymentHubTitle => 'Lipa';

  @override
  String get paymentHubSubtitle =>
      'Lipa bili, lipa wafanyabiashara, au tumia QR na risiti kutoka sehemu moja.';

  @override
  String get paymentTabBills => 'Bili';

  @override
  String get paymentTabMerchants => 'Wafanyabiashara';

  @override
  String get paymentBillsTitle => 'Lipa bili';

  @override
  String get paymentBillsSubtitle =>
      'Chagua kundi la huduma, kisha endelea na mtoa huduma unayetaka kumlipa.';

  @override
  String get paymentMerchantTitle => 'Lipa wafanyabiashara';

  @override
  String get paymentMerchantSubtitle =>
      'Lipa mfanyabiashara kwa namba ya malipo, QR, au picha ya risiti.';

  @override
  String get paymentMerchantNumberTitle => 'Lipa kwa namba ya mfanyabiashara';

  @override
  String get paymentMerchantNumberSubtitle =>
      'Weka namba ya malipo ya mfanyabiashara ili kuendelea na malipo yaliyothibitishwa.';

  @override
  String get paymentMerchantNumberLabel => 'Namba ya malipo ya mfanyabiashara';

  @override
  String get paymentMerchantNumberHint => 'Weka namba ya malipo';

  @override
  String get paymentContinueMerchantPay =>
      'Endelea na malipo ya mfanyabiashara';

  @override
  String get paymentBillProvidersTitle => 'Watoa huduma maarufu';

  @override
  String get paymentBillProvidersEmpty =>
      'Watoa huduma wataonekana hapa kwa kundi hili la bili.';

  @override
  String get paymentQrDetectedTitle => 'Uchanganuzi umepatikana';

  @override
  String get paymentQrDetectedSubtitle =>
      'ORBI imeandaa rasimu ya malipo kutoka kwenye maelezo ya msimbo uliosomwa.';

  @override
  String get paymentMerchantQrTitle => 'Lipa mfanyabiashara kwa QR';

  @override
  String get paymentMerchantQrSubtitle =>
      'Changanua QR yoyote inayotumika kwa malipo na ORBI itengeneze rasimu ya malipo papo hapo.';

  @override
  String get paymentMerchantQrFrameHint =>
      'Weka QR ya mfanyabiashara ndani ya fremu';

  @override
  String get paymentScanSearching => 'Inatafuta QR...';

  @override
  String get paymentScanSearchingSubtitle =>
      'Changanua ili ORBI iandae rasimu ya malipo moja kwa moja kutoka kwenye maelezo yaliyopatikana.';

  @override
  String get paymentScannerUnavailableTitle => 'Kichanganuzi hakipatikani';

  @override
  String get paymentScannerPermissionRequired =>
      'Ruhusa ya kamera inahitajika kuchanganua QR.';

  @override
  String get paymentScannerUnsupported =>
      'Kifaa hiki hakitumii uchanganuzi wa QR.';

  @override
  String get paymentScannerPreparing =>
      'Kichanganuzi kinaandaliwa. Jaribu tena.';

  @override
  String get paymentScannerGenericError =>
      'Imeshindikana kufungua kichanganuzi cha QR sasa hivi.';

  @override
  String get paymentScannerOpenSettings => 'Fungua mipangilio';

  @override
  String get paymentScanDetected => 'QR imesomwa';

  @override
  String get paymentScanSourceQr => 'QR scan';

  @override
  String get paymentScanSourceReceipt => 'Risiti';

  @override
  String get paymentScanTypeMerchant => 'Malipo ya mfanyabiashara';

  @override
  String get paymentScanTypeBill => 'Malipo ya bili';

  @override
  String get paymentScanTypeUniversal => 'Malipo ya jumla';

  @override
  String paymentScanBillDraftTitle(String name) {
    return 'Bili ya $name iko tayari';
  }

  @override
  String paymentScanMerchantDraftTitle(String name) {
    return '$name iko tayari kulipwa';
  }

  @override
  String paymentScanUniversalDraftTitle(String name) {
    return 'Maelezo ya $name yamepatikana';
  }

  @override
  String get paymentScanBillDraftSubtitle =>
      'ORBI imeoanisha mtoa huduma na kuandaa rasimu ya malipo ya bili kutoka kwenye scan hii.';

  @override
  String get paymentScanMerchantDraftSubtitle =>
      'ORBI imemtambua mfanyabiashara na kuunda rasimu ya malipo tayari kwa ukaguzi.';

  @override
  String get paymentScanUniversalDraftSubtitle =>
      'ORBI imenasa maelezo ya malipo na kuunda rasimu ambayo unaweza kukagua kabla ya kulipa.';

  @override
  String get paymentScanDraftAmountPending => 'Kiasi kinangoja';

  @override
  String get paymentScanDraftAutoCreated => 'Rasimu imeundwa';

  @override
  String get paymentScanNeedsReview =>
      'Baadhi ya maelezo bado yanahitaji ukaguzi kabla ya malipo.';

  @override
  String get paymentScanNeedsReviewSubtitle =>
      'ORBI imenasa scan, lakini baadhi ya maelezo ya malipo bado yanahitaji ukaguzi wako.';

  @override
  String get paymentScanOpenDraft => 'Kagua rasimu ya malipo';

  @override
  String get paymentScanDetailMerchantId => 'Namba ya mfanyabiashara';

  @override
  String get paymentNoteLabel => 'Maelezo';

  @override
  String get paymentReceiptTitle => 'Tumia picha ya risiti';

  @override
  String get paymentReceiptSubtitle =>
      'Pakia au piga picha ya risiti na uache ORBI iandae rasimu ya malipo kutokana na maelezo yaliyosomwa.';

  @override
  String get paymentUseForPayment => 'Tumia kwenye malipo';

  @override
  String get paymentOrbiPayTitle => 'ORBI Pay';

  @override
  String get paymentOrbiPayNoWallets =>
      'Hakuna walleti inayopatikana kwa ORBI Pay kwa sasa.';

  @override
  String get paymentOrbiPayAmountHint => 'Weka kiasi';

  @override
  String get paymentOrbiPayAmountValidation =>
      'Weka kiasi sahihi kwa ORBI Pay.';

  @override
  String get paymentOrbiPayPreviewTitle => 'Muhtasari wa malipo';

  @override
  String get paymentOrbiPayPreviewAction => 'Hakiki';

  @override
  String get paymentOrbiPayConfirmAction => 'Lipa sasa';

  @override
  String get paymentOrbiPaySuccess =>
      'Malipo ya mfanyabiashara ya ORBI Pay yametumwa.';

  @override
  String get paymentMerchantDefaultNote => 'Malipo ya mfanyabiashara';

  @override
  String get paymentBillPayTitle => 'Malipo ya bili';

  @override
  String get paymentBillPreviewTitle => 'Muhtasari wa bili';

  @override
  String get paymentBillPayConfirmAction => 'Lipa bili';

  @override
  String get paymentBillFundingWallet => 'Walleti';

  @override
  String get paymentBillFundingReserve => 'Reserve';

  @override
  String get paymentBillFundingSharedBudget => 'Shared budget';

  @override
  String get paymentBillWalletHelper =>
      'Walleti za goal zimeondolewa ili kulinda matumizi ya bili.';

  @override
  String get paymentBillReserveHelper =>
      'Malipo haya yatatumia walleti inayoungwa mkono na reserve ya bili iliyolingana.';

  @override
  String get paymentBillSharedBudgetHelper =>
      'Tumia shared budget tu kama bili hii ni ya familia au timu hiyo.';

  @override
  String get paymentBillReserveMatchedTitle => 'Bill reserve imepatikana';

  @override
  String get paymentBillReserveUsingTitle => 'Inalipa kutoka reserve';

  @override
  String paymentBillReserveMatchedMessage(Object provider, Object amount) {
    return '$provider ina reserve yenye takriban $amount tayari kwa bili hii.';
  }

  @override
  String paymentBillReserveUsingMessage(Object provider, Object amount) {
    return '$provider itatumia kiasi cha reserve kinachokadiriwa kuwa $amount kwa malipo haya.';
  }

  @override
  String get paymentBillReserveStrongMatch => 'Match ya reserve ni imara';

  @override
  String get paymentBillReservePossibleMatch => 'Match ya reserve inawezekana';

  @override
  String get paymentBillNoFundingSources =>
      'Hakuna chanzo salama cha kulipia bili kinachopatikana sasa hivi.';

  @override
  String get paymentBillPayReserveSuccess =>
      'Malipo ya bili yamekamilika kwa kutumia walleti ya reserve iliyolingana.';

  @override
  String get paymentBillPaySharedBudgetSuccess =>
      'Malipo ya bili yamehifadhiwa kwenye shared budget.';

  @override
  String get paymentBillPaySuccess => 'Malipo ya bili yametumwa.';

  @override
  String get paymentBillReferenceHint =>
      'Weka namba ya mita, control number, au rejea ya akaunti';

  @override
  String get paymentScanConfidenceHigh => 'Uhakika mkubwa';

  @override
  String get paymentScanConfidenceMedium => 'Uhakika wa kati';

  @override
  String get paymentScanConfidenceLow => 'Uhakika mdogo';

  @override
  String get paymentScanConfidenceInvalid => 'Scan batili';

  @override
  String get paymentScanInvalidTitle => 'Msimbo huu hauko tayari kwa malipo';

  @override
  String get paymentScanInvalidSubtitle =>
      'ORBI haikuweza kupata maelezo ya malipo ya kuaminika ya kutosha kutoka kwenye scan hii. Jaribu msimbo mwingine au tumia namba ya malipo ya mfanyabiashara.';

  @override
  String get paymentScanInvalidFallbackAction =>
      'Tumia namba ya malipo ya mfanyabiashara';

  @override
  String get paymentScanInvalidStatus =>
      'Scan hii haiwezi kutumika kwa malipo.';

  @override
  String get paymentScanDetailRecipient => 'Mpokeaji';

  @override
  String get paymentScanDetailProvider => 'Mtoa huduma';

  @override
  String get paymentScanDetailCategory => 'Kundi la bili';

  @override
  String get paymentScanDetailReference => 'Rejea';

  @override
  String get paymentScanDetailSchema => 'Muundo';

  @override
  String get paymentScanPaymentReady => 'Rasimu ya malipo iko tayari';

  @override
  String get paymentScanMerchantAutoRoute =>
      'Inafungua rasimu ya malipo ya mfanyabiashara...';

  @override
  String get paymentScanBillAutoRoute =>
      'Inafungua rasimu ya malipo ya bili...';

  @override
  String get paymentReviewPayment => 'Kagua malipo';

  @override
  String notificationsCouldNotOpenMessage(String value) {
    return 'Haikuweza kufungua $value';
  }

  @override
  String get notificationsDetailsTitle => 'Maelezo';

  @override
  String notificationsSelectedCount(int count) {
    return '$count zimechaguliwa';
  }

  @override
  String get notificationsClearSelection => 'Futa uchaguzi';

  @override
  String get notificationsSelectAll => 'Chagua zote';

  @override
  String get notificationsMarkAllRead => 'Weka zote kama zimesomwa';

  @override
  String get notificationsEmptyTitle => 'Umeshapata yote';

  @override
  String get notificationsEmptyMessage =>
      'Arifa mpya na masasisho ya akaunti yataonekana hapa.';

  @override
  String get notificationsLoadFailedTitle => 'Imeshindikana kupakia arifa';

  @override
  String get notificationsJustNow => 'sasa hivi';

  @override
  String notificationsMinutesAgo(int count) {
    return 'dakika $count zilizopita';
  }

  @override
  String notificationsHoursAgo(int count) {
    return 'saa $count zilizopita';
  }

  @override
  String notificationsDaysAgo(int count) {
    return 'siku $count zilizopita';
  }

  @override
  String notificationsFullTime(String date, String time) {
    return '$date saa $time';
  }

  @override
  String get transactionsSessionExpiredMessage =>
      'Muda wa kikao umekwisha. Tafadhali ingia tena.';

  @override
  String get transactionsFetchFailedMessage =>
      'Imeshindikana kupata miamala kwa sasa.';

  @override
  String get transactionsLoadFailedTitle => 'Imeshindikana kupakia miamala';

  @override
  String get transactionsHistoryTitle => 'Historia ya Miamala';

  @override
  String get transactionsFilterByMoneyState => 'Chuja kwa hali ya fedha';

  @override
  String get transactionsFilterAll => 'Zote';

  @override
  String get transactionsEmptyTitle => 'Bado hakuna miamala';

  @override
  String get transactionsEmptyMessage =>
      'Malipo na uhamisho uliokamilika vitaonekana hapa.';

  @override
  String get transactionsNoFilteredMatchesTitle =>
      'Hakuna miamala inayolingana';

  @override
  String get transactionsNoFilteredMatchesMessage =>
      'Jaribu hali nyingine ya fedha kuona shughuli zinazolingana.';

  @override
  String transactionsItemsCount(int count) {
    return 'vipengee $count';
  }

  @override
  String transactionsReceivedFrom(String name) {
    return 'Imepokelewa kutoka kwa $name';
  }

  @override
  String transactionsSentTo(String name) {
    return 'Imetumwa kwa $name';
  }

  @override
  String get transactionsGenericTitle => 'Muamala';

  @override
  String get transactionsCredit => 'Mkopo';

  @override
  String get transactionsDebit => 'Malipo';

  @override
  String get transactionsNotAvailable => 'Hakuna';

  @override
  String get transactionsStatusCompleted => 'Imekamilika';

  @override
  String get transactionsReceiptReferenceId => 'Namba ya rejea';

  @override
  String get transactionsReceiptType => 'Aina';

  @override
  String get transactionsReceiptStatus => 'Hali';

  @override
  String get transactionsReceiptAmount => 'Kiasi';

  @override
  String get transactionsReceiptBaseAmount => 'Kiasi cha msingi';

  @override
  String get transactionsReceiptTax => 'Kodi';

  @override
  String get transactionsReceiptServiceFee => 'Ada ya huduma';

  @override
  String get transactionsReceiptTotalCharged => 'Jumla iliyokatwa';

  @override
  String get transactionsReceiptDirection => 'Mwelekeo';

  @override
  String get transactionsReceiptMoneyState => 'Hali ya Fedha';

  @override
  String get transactionsReceiptDate => 'Tarehe';

  @override
  String get transactionsReceiptFrom => 'Kutoka';

  @override
  String get transactionsReceiptTo => 'Kwenda';

  @override
  String get actionDone => 'Sawa';

  @override
  String get sendMoneyLoadSourceWalletsFailedMessage =>
      'Imeshindikana kupakia pochi za chanzo.';

  @override
  String get sendMoneySearchMinCharsMessage =>
      'Andika angalau herufi 5 kutafuta';

  @override
  String get sendMoneySearchMinCharsLongMessage =>
      'Tafadhali andika angalau herufi 5 ili kuanza kutafuta.';

  @override
  String get sendMoneyRecipientNotFoundMessage =>
      'Hatujampata mtu huyo. Tafadhali hakiki kitambulisho au namba ya simu ujaribu tena.';

  @override
  String get sendMoneySearchUnavailableMessage =>
      'Huduma ya utafutaji haipatikani kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.';

  @override
  String get sendMoneyPreviewFailedMessage =>
      'Imeshindikana kuonyesha hakikisho la uhamisho huu kwa sasa.';

  @override
  String get sendMoneyPreviewTimedOutMessage =>
      'Ombi la hakikisho limechelewa. Tafadhali jaribu tena.';

  @override
  String get sendMoneyPreviewRequestFailedMessage =>
      'Ombi la hakikisho limeshindwa. Tafadhali jaribu tena.';

  @override
  String sendMoneyPreviewRequestFailedWithStatus(int status) {
    return 'Hakikisho limeshindwa ($status). Tafadhali jaribu tena.';
  }

  @override
  String get sendMoneyPreviewInvalidFormatMessage =>
      'Muundo wa majibu ya hakikisho si sahihi';

  @override
  String get sendMoneyPreviewUnavailableMessage =>
      'Imeshindikana kuonyesha hakikisho la muamala huu.';

  @override
  String get sendMoneyPreviewDataMissingMessage =>
      'Taarifa za hakikisho hazipo kwenye majibu';

  @override
  String get sendMoneyPreviewRejectedMessage =>
      'Hakikisho limekataliwa na mfumo wa nyuma.';

  @override
  String get sendMoneyConfirmTransferTitle => 'Thibitisha Uhamisho';

  @override
  String get sendMoneySubmittingLabel => 'Inawasilisha...';

  @override
  String get sendMoneyConfirmAction => 'Thibitisha';

  @override
  String get sendMoneyTransactionSuccessfulTitle => 'Muamala Umefanikiwa';

  @override
  String get sendMoneyTransactionFailedTitle => 'Muamala Umeshindikana';

  @override
  String get sendMoneySubmitFailedMessage =>
      'Imeshindikana kuwasilisha uhamisho huu kwa sasa.';

  @override
  String get sendMoneyExternalSubmitFailedMessage =>
      'Imeshindikana kuwasilisha uhamisho wa nje kwa sasa.';

  @override
  String get sendMoneyReceiptTransactionId => 'Kitambulisho cha muamala';

  @override
  String get sendMoneyReceiptReference => 'Rejea';

  @override
  String get sendMoneyReceiptControlId => 'Namba ya udhibiti';

  @override
  String get sendMoneyReceiptStatus => 'Hali';

  @override
  String get sendMoneyReceiptType => 'Aina';

  @override
  String get sendMoneyReceiptTransaction => 'Muamala';

  @override
  String get sendMoneyReceiptRecipient => 'Mpokeaji';

  @override
  String get sendMoneyReceiptSourceWallet => 'Pochi ya chanzo';

  @override
  String get sendMoneyReceiptAmount => 'Kiasi';

  @override
  String get sendMoneyReceiptTax => 'Kodi';

  @override
  String get sendMoneyReceiptFee => 'Ada';

  @override
  String get sendMoneyReceiptTotal => 'Jumla';

  @override
  String get sendMoneyReceiptDescription => 'Maelezo';

  @override
  String get sendMoneyReceiptTime => 'Muda';

  @override
  String get sendMoneyHeroTitle => 'Hamisha Pesa Haraka';

  @override
  String get sendMoneyHeroInternalSubtitle =>
      'Hamisha fedha kwa haraka kati ya watumiaji wa Orbi kwa hakikisho salama na uchaguzi wa pochi.';

  @override
  String get sendMoneyHeroExternalSubtitle =>
      'Tuma malipo ya kitaalamu kwa benki, pochi za simu, PayPal, na njia za crypto.';

  @override
  String sendMoneyCurrencyPill(String currency) {
    return 'Sarafu: $currency';
  }

  @override
  String sendMoneySenderWalletReady(String sender) {
    return 'Mtumaji: $sender • Pochi ya uendeshaji iko tayari';
  }

  @override
  String sendMoneySenderWalletMissing(String sender) {
    return 'Mtumaji: $sender • Pochi ya uendeshaji haipo';
  }

  @override
  String get sendMoneySectionRecipientTitle => '1. Mpokeaji';

  @override
  String get sendMoneySectionRecipientSubtitle =>
      'Tafuta kwa Orbi ID, barua pepe, au simu';

  @override
  String get sendMoneyRecipientFieldLabel => 'Orbi ID au simu ya mpokeaji';

  @override
  String get sendMoneyRecipientFieldHint => 'OB26-1234-5678 au +2557XXXXXXX';

  @override
  String get sendMoneyRecipientRequiredMessage =>
      'Weka Orbi ID au namba ya simu ya mpokeaji';

  @override
  String get sendMoneySectionSourceWalletTitle => '2. Pochi ya Chanzo';

  @override
  String get sendMoneySectionSourceWalletSubtitle =>
      'Chagua Goal/Budget kama unataka kutumia pochi ndogo kama chanzo';

  @override
  String get sendMoneySectionAmountNoteTitle => '3. Kiasi na Maelezo';

  @override
  String get sendMoneySectionAmountNoteSubtitle =>
      'Weka kiasi cha kutuma na maelezo ya hiari';

  @override
  String get sendMoneyAmountLabel => 'Kiasi';

  @override
  String get sendMoneyDescriptionOptionalLabel => 'Maelezo (si lazima)';

  @override
  String get sendMoneyDescriptionHint => 'Sababu ya uhamisho';

  @override
  String get sendMoneyPreparingPreviewLabel => 'Inaandaa hakikisho...';

  @override
  String get sendMoneyContinueTransferLabel => 'Endelea na Uhamisho';

  @override
  String get sendMoneyNoGoalWalletsMessage =>
      'Hakuna pochi ya lengo au bajeti inayopatikana kwa sasa. Uhamisho huu utatumia Operating Wallet kiotomatiki.';

  @override
  String get sendMoneyOperatingWalletAutoTitle => 'Operating Wallet (Auto)';

  @override
  String get sendMoneyOperatingWalletAutoSubtitle =>
      'Chanzo cha kawaida ikiwa hakuna pochi ndogo iliyochaguliwa';

  @override
  String get sendMoneyDefaultBadge => 'MSINGI';

  @override
  String get sendMoneySourceBadgeOperating => 'OPERATING';

  @override
  String get sendMoneySourceBadgeGoal => 'GOAL';

  @override
  String get sendMoneySourceBadgeBudget => 'BAJETI';

  @override
  String get sendMoneySourceBadgeSavings => 'AKIBA';

  @override
  String get sendMoneySourceBadgeSubWallet => 'SUB-WALLET';

  @override
  String get sendMoneyGoalSourceWarningTitle => 'Fedha za lengo zinalindwa';

  @override
  String get sendMoneyGoalSourceWarningBody =>
      'Umechagua pochi ya chanzo inayotegemea lengo. Endelea tu ikiwa kweli unakusudia kutumia au kutoa fedha kutoka kwenye mgao huo wa lengo.';

  @override
  String get sendMoneyGoalSourceContinueAction => 'Endelea Hata Hivyo';

  @override
  String get sendMoneyGoalSourceInlineWarning =>
      'Chanzo hiki kinategemea lengo. Fedha za lengo zitumike kwa makusudi tu, si kama matumizi ya kawaida.';

  @override
  String sendMoneyWalletIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get sendMoneyExternalSectionRailProviderTitle =>
      '1. Njia na Mtoa Huduma';

  @override
  String get sendMoneyExternalSectionRailProviderSubtitle =>
      'Chagua njia ya malipo';

  @override
  String get sendMoneyProviderCodeLabel => 'Msimbo wa mtoa huduma';

  @override
  String get sendMoneyProviderCodeHint => 'Mfano: NMB, MPESA, PAYPAL';

  @override
  String get sendMoneyProviderCodeRequiredMessage =>
      'Weka msimbo wa mtoa huduma';

  @override
  String get sendMoneyExternalSectionDestinationTitle => '2. Marudio';

  @override
  String get sendMoneyExternalSectionDestinationSubtitle =>
      'Fedha zinaenda wapi';

  @override
  String get sendMoneyCardNumberLabel => 'Namba ya kadi';

  @override
  String get sendMoneyAccountAddressLabel => 'Akaunti / Anwani';

  @override
  String get sendMoneyCardNumberHint => 'Weka namba ya kadi';

  @override
  String get sendMoneyDestinationAccountHint => 'Weka akaunti ya marudio';

  @override
  String get sendMoneyCardNumberRequiredMessage => 'Weka namba ya kadi';

  @override
  String get sendMoneyAccountAddressRequiredMessage => 'Weka akaunti au anwani';

  @override
  String get sendMoneyRecipientReferenceLabel => 'Rejea ya mpokeaji';

  @override
  String get sendMoneyRecipientReferenceHint => 'Rejea ya marudio ya kutuma';

  @override
  String get sendMoneyRecipientReferenceRequiredMessage =>
      'Weka rejea ya mpokeaji';

  @override
  String get sendMoneyExternalSectionFundingTitle => '3. Chanzo cha Fedha';

  @override
  String get sendMoneyExternalSectionFundingSubtitle =>
      'Chagua aina ya chanzo na pochi';

  @override
  String get sendMoneySourceWalletLabel => 'Pochi ya chanzo';

  @override
  String get sendMoneySourceWalletHint =>
      'Internal, External Mobile, External Bank';

  @override
  String get sendMoneyBackendSourceWalletLabel =>
      'Pochi ya chanzo kutoka backend';

  @override
  String get sendMoneyLoadingWalletsHint => 'Inapakia pochi...';

  @override
  String get sendMoneySelectLoadedWalletHint => 'Chagua pochi iliyopakiwa';

  @override
  String get sendMoneySelectSourceWalletRequiredMessage =>
      'Chagua pochi ya chanzo kutoka orodha ya backend';

  @override
  String get sendMoneyExternalSectionAmountNoteTitle => '4. Kiasi na Maelezo';

  @override
  String get sendMoneyBudgetCategoryLabel => 'Kundi la bajeti';

  @override
  String get sendMoneyBudgetCategoryHint =>
      'Kundi la matumizi lisilo la lazima';

  @override
  String get sendMoneyBudgetCategoryOptionalHelper =>
      'Weka transfer hii ndani ya kundi la bajeti kwa ufuatiliaji na tahadhari.';

  @override
  String get sendMoneyBudgetCategoryNone => 'Hakuna kundi la bajeti';

  @override
  String get sendMoneyNoBudgetCategoriesMessage =>
      'Hakuna makundi ya bajeti bado. Unda moja kwenye Malengo na Bajeti ili kuweka transfer ndani yake.';

  @override
  String get sendMoneyBudgetCategoriesLoadFailedMessage =>
      'Imeshindikana kupakia makundi ya bajeti kwa sasa.';

  @override
  String sendMoneyBudgetSummaryTitle(String name) {
    return 'Bajeti: $name';
  }

  @override
  String sendMoneyBudgetSummaryBody(
    String budget,
    String spent,
    String remaining,
  ) {
    return 'Kikomo $budget • Kimetumika $spent • Kimebaki $remaining';
  }

  @override
  String sendMoneyBudgetHardLimitLabel(String period) {
    return 'Kikomo kigumu • $period';
  }

  @override
  String sendMoneyBudgetSoftLimitLabel(String period) {
    return 'Kikomo laini • $period';
  }

  @override
  String sendMoneyBudgetHardLimitMessage(String name, String remaining) {
    return '$name iko chini ya kikomo kigumu. Imebaki $remaining tu, hivyo transfer hii haiwezi kuendelea.';
  }

  @override
  String get sendMoneyBudgetSoftLimitTitle => 'Onyo la bajeti';

  @override
  String sendMoneyBudgetSoftLimitBody(String name, String remaining) {
    return '$name inaweza kuzidiwa. Imebaki $remaining tu kwenye bajeti hii. Endelea na utegemee fallback funding ikiwa sera ya backend inaruhusu?';
  }

  @override
  String get sendMoneyBudgetSoftLimitContinue => 'Endelea kwa Onyo';

  @override
  String get sendMoneyContinueExternalTransferLabel =>
      'Endelea na Uhamisho wa Nje';

  @override
  String get sendMoneyModeInternalTitle => 'Internal P2P';

  @override
  String get sendMoneyModeInternalSubtitle =>
      'Mtumiaji wa Orbi kwa mtumiaji mwingine';

  @override
  String get sendMoneyModeExternalTitle => 'Nje';

  @override
  String get sendMoneyModeExternalSubtitle => 'Benki, Mobile, PayPal, Crypto';

  @override
  String get sendMoneyRailBank => 'Benki';

  @override
  String get sendMoneyRailMobileWallet => 'Pochi ya simu';

  @override
  String get sendMoneyRailPaypal => 'PayPal';

  @override
  String get sendMoneyRailCrypto => 'Crypto';

  @override
  String get sendMoneySourceTypeInternal => 'Ndani';

  @override
  String get sendMoneySourceTypeExternalMobileWallet => 'Pochi ya simu ya nje';

  @override
  String get sendMoneySourceTypeExternalBank => 'Benki ya nje';

  @override
  String get sendMoneyRecipientIdLabel => 'ID ya mpokeaji';

  @override
  String get sendMoneyFullNameLabel => 'Jina kamili';

  @override
  String get sendMoneyVerifiedLabel => 'Imethibitishwa';

  @override
  String get sendMoneyNotVerifiedLabel => 'Haijathibitishwa';

  @override
  String get sendMoneyRecipientFallback => 'Mpokeaji';

  @override
  String get sendMoneyPreviewServiceFeeLabel => 'Ada ya huduma';

  @override
  String get sendMoneyPreviewTotalToPayLabel => 'Jumla ya kulipa';

  @override
  String get sendMoneyPreviewExchangeRateLabel => 'Kiwango cha ubadilishaji';

  @override
  String get sendMoneyPreviewFxFeeLabel => 'Ada ya FX';

  @override
  String get sendMoneyPreviewRecipientGetsLabel => 'Mpokeaji anapata';

  @override
  String get sendMoneyPreviewAvailableBalanceLabel => 'Salio linalopatikana';

  @override
  String sendMoneyInsufficientBalanceMessage(String amount) {
    return 'Salio halitoshi. Umepungua kwa $amount.';
  }

  @override
  String sendMoneySecurityCheckStatus(String status) {
    return 'Ukaguzi wa usalama: $status';
  }

  @override
  String get otpCodeSentLabel => 'Msimbo uliotumwa kwenye simu yako';

  @override
  String get pinConfirmLabel => 'Thibitisha PIN';

  @override
  String get pinCurrentLabel => 'PIN ya sasa';

  @override
  String get pinNewLabel => 'PIN mpya';

  @override
  String get pinConfirmNewLabel => 'Thibitisha PIN mpya';

  @override
  String get passwordNewLabel => 'Nenosiri jipya';

  @override
  String get passwordConfirmLabel => 'Thibitisha nenosiri';

  @override
  String get settingsBiometricEnabledMessage =>
      'Kuingia kwa biometriki kumewezeshwa';

  @override
  String get settingsBiometricEnableFailedMessage =>
      'Imeshindikana kuwezesha kuingia kwa biometriki';

  @override
  String get settingsPinRequiredForBiometricMessage =>
      'Uwekaji wa PIN unahitajika ili kutumia kuingia kwa biometriki. Kuingia kwa biometriki kumezimwa.';

  @override
  String get settingsProfileUpdatedMessage =>
      'Wasifu umesasishwa kwa mafanikio';

  @override
  String get settingsProfileUpdateFailedMessage =>
      'Imeshindikana kusasisha wasifu';

  @override
  String get settingsPasswordUpdatedMessage =>
      'Nenosiri limesasishwa kwa mafanikio.';

  @override
  String get settingsPasswordUpdateFailedMessage =>
      'Imeshindikana kusasisha nenosiri.';

  @override
  String get settingsProfilePhotoUpdatedMessage =>
      'Picha ya wasifu imesasishwa';

  @override
  String get settingsProfilePhotoFailedMessage => 'Imeshindikana kupakia picha';

  @override
  String get sessionExpiredLoginMessage =>
      'Muda wa kikao umekwisha. Tafadhali ingia tena.';

  @override
  String get otpEnterCodeLabel => 'Weka msimbo wa OTP';

  @override
  String otpAttemptHelper(String helperText, int attempt) {
    return '$helperText\nJaribio la $attempt';
  }

  @override
  String enterpriseOperatingVaultThreshold(String currency) {
    return 'Kizingiti cha hazina ya uendeshaji ($currency)';
  }

  @override
  String get requestMoneyFromLabel => 'Ombi Kutoka';

  @override
  String get requestMoneyAmountLabel => 'Kiasi';

  @override
  String get requestMoneyReasonLabel => 'Sababu (si lazima)';

  @override
  String get requestMoneyFromHint => 'Simu, barua pepe, au jina la mtumiaji';

  @override
  String get requestMoneyAmountHint => '0.00';

  @override
  String get requestMoneyReasonHint => 'Ombi hili ni la nini?';

  @override
  String get settingsKycRegisteredFullNameLabel => 'Jina Kamili Lililosajiliwa';

  @override
  String get settingsKycIdTypeLabel => 'Aina ya Kitambulisho';

  @override
  String get settingsKycIdNumberLabel => 'Namba ya Kitambulisho';

  @override
  String get requestMoneyIntro =>
      'Unda ombi la malipo na ulitume kwa mtumiaji mwingine.';

  @override
  String get requestMoneyValidatorFrom => 'Weka mtu wa kumuomba';

  @override
  String get requestMoneyValidatorAmount => 'Weka kiasi sahihi';

  @override
  String get settingsKycSubmitFailedMessage =>
      'Imeshindikana kuwasilisha taarifa za KYC';

  @override
  String get sendMoneyVerificationCancelledMessage =>
      'Uthibitishaji wa muamala ulighairiwa. Tafadhali jaribu tena.';

  @override
  String get otpInvalidCodeMessage =>
      'Msimbo si sahihi. Tafadhali jaribu tena.';

  @override
  String get settingsProfileNameMissingMessage =>
      'Jina la wasifu halipo. Sasisha wasifu kwanza.';

  @override
  String get settingsUploadIdHoldingMessage =>
      'Pakia picha ya skrini/picha ukiwa umeshika kitambulisho chako';

  @override
  String get settingsScanNameMismatchMessage =>
      'Jina la skani linatofautiana na jina la wasifu. Hakikisha majina yanalingana na wasifu wako uliosajiliwa.';

  @override
  String get settingsScanSuccessMessage =>
      'Taarifa za kitambulisho zimechambuliwa kwa mafanikio.';

  @override
  String get settingsScanDobLabel => 'DOB';

  @override
  String get settingsScanExpiryLabel => 'Mwisho';

  @override
  String get settingsServicePreferencesUpdatedMessage =>
      'Mapendeleo ya huduma yamesasishwa';

  @override
  String get settingsServicePreferencesUpdateFailedMessage =>
      'Imeshindikana kusasisha mapendeleo';

  @override
  String get settingsAllPreferencesUpdatedMessage =>
      'Mapendeleo yote yamesasishwa kwa mafanikio';

  @override
  String get settingsAppLanguageUpdatedServiceFailedMessage =>
      'Lugha ya programu imesasishwa, lakini mapendeleo ya huduma yameshindikana';

  @override
  String get settingsServiceUpdatedAppFailedMessage =>
      'Mapendeleo ya huduma yamesasishwa, lakini lugha ya programu imeshindikana';

  @override
  String get settingsAllPreferencesUpdateFailedMessage =>
      'Imeshindikana kusasisha mapendeleo yoyote';

  @override
  String get settingsAppLanguageUpdateFailedMessage =>
      'Imeshindikana kusasisha lugha ya programu';

  @override
  String get settingsNoPreferencesSelectedMessage =>
      'Hakuna mapendeleo yaliyochaguliwa kutumia';

  @override
  String get settingsSecurityVerificationHelper =>
      'Weka OTP iliyotumwa kwenye mawasiliano yako yaliyosajiliwa ili kuidhinisha hatua hii ya usalama.';

  @override
  String get settingsKycVerificationRequiredTitle =>
      'Uthibitishaji wa KYC Unahitajika';

  @override
  String get settingsKycVerificationRequiredMessage =>
      'Sasisha taarifa zako za KYC ili kupata ufikiaji zaidi, viwango vikubwa vya miamala, na huduma zaidi za ORBI.';

  @override
  String get settingsKycUploadRequirementTitle => 'Mahitaji ya kupakia KYC';

  @override
  String get settingsKycUploadRequirementMessage =>
      '• Pakia picha ya wazi ukiwa umeshika kitambulisho chako\n• Uso wako na maandishi ya kitambulisho yaonekane vizuri\n• Tumia mwanga mzuri na epuka ukungu au kukata pembeni';

  @override
  String get settingsIdTypeNationalId => 'Kitambulisho cha Taifa';

  @override
  String get settingsIdTypePassport => 'Pasipoti';

  @override
  String get settingsIdTypeDrivingLicense => 'Leseni ya Udereva';

  @override
  String get settingsIdTypeVoterId => 'Kitambulisho cha Mpiga Kura';

  @override
  String get settingsScanCouldNotExtractMessage =>
      'Haikuweza kuchambua taarifa. Tumia picha ya kitambulisho iliyo wazi na yenye mwanga mzuri.';

  @override
  String get settingsKycRegisteredNameHelper =>
      'Jina hapa chini limejazwa moja kwa moja kutoka kwenye wasifu wako uliosajiliwa na lazima lifanane na kitambulisho chako.';

  @override
  String get settingsFaceAndIdReadableMessage =>
      'Hakikisha uso wako na maandishi ya kitambulisho yanaonekana wazi.';

  @override
  String get settingsAutoScanHelperMessage =>
      'Auto-scan hutumia AI ya multimodal kuchambua jina kamili, namba ya kitambulisho, aina ya hati, DOB, na tarehe ya mwisho wa matumizi. Endesha skani kila baada ya kupakia picha mpya.';

  @override
  String get settingsScanningIdLabel => 'Inachanganua kitambulisho...';

  @override
  String get settingsAutoFillFromIdScanLabel =>
      'Jaza moja kwa moja kutoka skani ya kitambulisho';

  @override
  String get settingsAutoScanVerifyFailedMessage =>
      'Auto-scan haikuweza kuthibitisha hati hii. Jaribu picha iliyo wazi zaidi.';

  @override
  String get settingsSubmitDisabledUntilScanMessage =>
      'Kutuma kumezimwa hadi auto-scan irudishe majibu.';

  @override
  String get settingsSubmitKycLabel => 'Wasilisha KYC';

  @override
  String get settingsUserFallback => 'Mtumiaji';

  @override
  String get settingsNoEmailFallback => 'Hakuna barua pepe';

  @override
  String get settingsUserInitialFallback => 'M';

  @override
  String settingsCustomerIdLabel(String customerId) {
    return 'ID ya Mteja: $customerId';
  }

  @override
  String settingsKycStatusLabel(String status) {
    return 'KYC: $status';
  }

  @override
  String get settingsVerifyNowMessage =>
      'Thibitisha sasa kufungua ufikiaji kamili';

  @override
  String get settingsAccountInformationTitle => 'Taarifa za Akaunti';

  @override
  String get settingsAccountInformationSubtitle =>
      'Weka maelezo ya wasifu wako yakiwa safi na ya kisasa.';

  @override
  String get settingsFullNameLabel => 'Jina Kamili';

  @override
  String get settingsPhoneLabel => 'Simu';

  @override
  String get settingsAddressLabel => 'Anwani';

  @override
  String get settingsCurrencyLabel => 'Sarafu';

  @override
  String get settingsSavingLabel => 'Inahifadhi...';

  @override
  String get settingsSaveProfileLabel => 'Hifadhi Wasifu';

  @override
  String get settingsSecurityTitle => 'Usalama';

  @override
  String get settingsSecuritySubtitle =>
      'Imarisha kuingia na linda ufikiaji wa taarifa nyeti za akaunti.';

  @override
  String get settingsUseBiometricsTitle => 'Tumia kuingia kwa biometriki';

  @override
  String get settingsUseBiometricsSubtitle =>
      'Tumia biometriki za kifaa chako kwa kuingia kwa haraka na salama.';

  @override
  String get settingsEnableDeviceBiometricsSubtitle =>
      'Ongeza biometriki kwenye mipangilio ya kifaa chako ili kuwezesha chaguo hili.';

  @override
  String get settingsBiometricUnavailableTitle =>
      'Biometriki haipatikani kwenye kifaa hiki';

  @override
  String get settingsBiometricUnavailableSubtitle =>
      'Bado unaweza kulinda akaunti yako kwa nenosiri na OTP.';

  @override
  String get settingsChangePinSubtitle =>
      'Sasisha PIN mbadala inayotumika kwa kuingia kwa biometriki';

  @override
  String get settingsChangePasswordSubtitle =>
      'Sasisha nenosiri la akaunti yako';

  @override
  String get settingsDeviceNotificationsTitle => 'Arifa za Kifaa';

  @override
  String get settingsDeviceNotificationsSubtitle =>
      'Dhibiti njia za arifa za ndani kwenye kifaa hiki.';

  @override
  String get settingsPushNotificationsTitle => 'Arifa za Push';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Arifa za papo hapo kwa shughuli na matukio ya usalama.';

  @override
  String get settingsEmailAlertsTitle => 'Arifa za Barua Pepe';

  @override
  String get settingsEmailAlertsSubtitle =>
      'Pokea muhtasari na ujumbe muhimu kwa barua pepe.';

  @override
  String get settingsMarketingUpdatesSubtitle =>
      'Vidokezo, huduma mpya, na ofa za Orbi mara kwa mara.';

  @override
  String get settingsHelpSupportTitle => 'Msaada na Usaidizi';

  @override
  String get settingsHelpSupportSubtitle =>
      'Wasiliana na timu ya usaidizi ya ORBI';

  @override
  String get settingsAboutTitle => 'Kuhusu ORBI';

  @override
  String get settingsAboutVersionSubtitle => 'Toleo 1.0.0+1';

  @override
  String get chatSessionUnavailableMessage =>
      'Mazungumzo salama hayapatikani kwa kikao hiki. Tafadhali ingia tena.';

  @override
  String get chatConnectionFailedMessage =>
      'Imeshindikana kuifikia Orbi AI. Angalia intaneti yako na ujaribu tena.';

  @override
  String get chatUnavailableMessage =>
      'Orbi AI haipatikani kwa muda. Tafadhali jaribu tena.';

  @override
  String get chatOpenSemantics => 'Fungua mazungumzo salama';

  @override
  String get chatCloseSemantics => 'Funga mazungumzo salama';

  @override
  String get chatTitle => 'ORBI AI';

  @override
  String get chatSubtitle => 'Msaidizi wa ujumbe salama';

  @override
  String get chatResetTooltip => 'Anzisha upya mazungumzo';

  @override
  String get chatEncryptedLabel => 'Imefichwa';

  @override
  String get chatPrivateSessionLabel => 'Kikao binafsi';

  @override
  String get chatUnavailableTitle => 'Mazungumzo hayapatikani';

  @override
  String get chatReadyTitle => 'Mazungumzo salama yako tayari';

  @override
  String get chatReadyMessage =>
      'Uliza kuhusu uhamisho, salio, usaidizi wa miamala, au mwongozo wa akaunti.';

  @override
  String get chatTypingLabel => 'ORBI AI inaandika...';

  @override
  String get chatComposerCompactHint => 'Tuma ujumbe kwa ORBI AI';

  @override
  String get chatComposerHint =>
      'Tuma ujumbe kuhusu salio, uhamisho, au msaada wa akaunti';

  @override
  String get enterpriseOrganizationTitle => 'Shirika';

  @override
  String get enterpriseNoOrganizationTitle =>
      'Hakuna shirika lililounganishwa.';

  @override
  String get enterpriseNoOrganizationMessage =>
      'Akaunti yako haijaunganishwa na taasisi ya biashara.';

  @override
  String get enterpriseBudgetAlertsTitle => 'Arifa za Bajeti';

  @override
  String get enterpriseTreasuryGoalsTitle => 'Malengo ya Hazina';

  @override
  String get enterprisePendingApprovalsTitle => 'Idhini Zinazosubiri';

  @override
  String get enterpriseLoadingTitle => 'Inapakia...';

  @override
  String get enterpriseFetchingOrganizationMessage =>
      'Inaleta taarifa za shirika.';

  @override
  String get enterpriseOrganizationFallback => 'Shirika';

  @override
  String enterpriseRoleLabel(String role) {
    return 'Wajibu: $role';
  }

  @override
  String enterpriseBaseCurrencyLabel(String currency) {
    return 'Sarafu ya msingi: $currency';
  }

  @override
  String get enterpriseNoTreasuryGoalsTitle => 'Hakuna malengo ya hazina';

  @override
  String get enterpriseNoTreasuryGoalsMessage =>
      'Hakuna malengo ya kampuni yaliyowekwa.';

  @override
  String get enterpriseTreasuryGoalFallback => 'Lengo la Hazina';

  @override
  String get moneyStateAvailable => 'Inapatikana';

  @override
  String get moneyStateBudgeted => 'Imewekewa Bajeti';

  @override
  String get moneyStateSaved => 'Imehifadhiwa';

  @override
  String get moneyStateLocked => 'Imefungwa';

  @override
  String get moneyStateSpent => 'Imetumika';

  @override
  String get moneyStateAllocated => 'Imetengwa';

  @override
  String enterpriseAutoSweepEnabledStatus(String thresholdPart) {
    return 'Auto-sweep imewashwa$thresholdPart';
  }

  @override
  String enterpriseThresholdSuffix(String threshold) {
    return ' • Kizingiti $threshold';
  }

  @override
  String get enterpriseAutoSweepDisabledStatus => 'Auto-sweep imezimwa';

  @override
  String get enterpriseAutoSweepConfigurationTitle =>
      'Mipangilio ya auto-sweep';

  @override
  String get enterpriseAllClearTitle => 'Yote ni shwari';

  @override
  String get enterpriseNoBudgetAlertsMessage =>
      'Hakuna arifa za bajeti kwa sasa.';

  @override
  String get enterpriseBudgetAlertFallback => 'Arifa ya bajeti';

  @override
  String get enterpriseBudgetAlertUpper => 'ARIFA YA BAJETI';

  @override
  String get enterpriseNoApprovalsTitle => 'Hakuna idhini';

  @override
  String get enterpriseNothingPendingMessage =>
      'Hakuna kinachosubiri kwa sasa.';

  @override
  String get enterpriseTreasuryApprovalFallback => 'Idhini ya hazina';

  @override
  String enterpriseIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get wealthSharedPotsLoadError => 'Imeshindikana kupakia shared pots.';

  @override
  String get wealthNewSharedPot => 'Shared pot mpya';

  @override
  String get wealthSharedGoalShort => 'Weka fedha pamoja kwa lengo moja.';

  @override
  String get wealthPotName => 'Jina la pot';

  @override
  String get wealthPotNameHint => 'Mfano Ada ya shule';

  @override
  String get wealthPurpose => 'Lengo';

  @override
  String get wealthPurposeHint => 'Familia, timu, biashara';

  @override
  String get wealthTargetAmount => 'Kiasi cha lengo';

  @override
  String get wealthAccessModel => 'Namna ya ufikiaji';

  @override
  String get wealthEnterPotNameFirst => 'Weka jina la pot kwanza.';

  @override
  String get wealthCreateSharedPotError => 'Imeshindikana kuunda shared pot.';

  @override
  String get wealthSaving => 'Inahifadhi...';

  @override
  String get wealthSavePot => 'Hifadhi pot';

  @override
  String get wealthSharedPotCreated => 'Shared pot imeundwa.';

  @override
  String get wealthEditSharedPot => 'Hariri shared pot';

  @override
  String get wealthUpdateSharedPotError =>
      'Imeshindikana kusasisha shared pot.';

  @override
  String get wealthSaveChanges => 'Hifadhi mabadiliko';

  @override
  String get wealthSharedPotUpdated => 'Shared pot imesasishwa.';

  @override
  String get wealthContributeToSharedPot => 'Changia shared pot';

  @override
  String get wealthContributeToPotHelp =>
      'Ongeza fedha kutoka walleti yako kwenda kwenye pot hii.';

  @override
  String get wealthAmount => 'Kiasi';

  @override
  String get wealthEnterAmountFirst => 'Weka kiasi kwanza.';

  @override
  String get wealthContributeError => 'Imeshindikana kuongeza mchango.';

  @override
  String get wealthContributeNow => 'Changia sasa';

  @override
  String get wealthContributionAdded => 'Mchango umeongezwa.';

  @override
  String get wealthWithdrawFromSharedPot => 'Toa kutoka shared pot';

  @override
  String get wealthWithdrawFromPotHelp =>
      'Rudisha fedha kutoka kwenye pot kwenda walleti yako.';

  @override
  String get wealthWithdrawError => 'Imeshindikana kutoa fedha kwenye pot.';

  @override
  String get wealthWithdrawNow => 'Toa sasa';

  @override
  String get wealthFundsWithdrawn => 'Fedha zimetolewa.';

  @override
  String get wealthInviteMember => 'Mwalike mshiriki';

  @override
  String get wealthInviteMemberHelp =>
      'Tuma mwaliko kwa simu au barua pepe ya ORBI ya mshiriki.';

  @override
  String get wealthPhoneOrEmail => 'Simu au barua pepe';

  @override
  String get wealthRole => 'Role';

  @override
  String get wealthEnterPhoneOrEmailFirst => 'Weka simu au barua pepe kwanza.';

  @override
  String get wealthInviteError => 'Imeshindikana kutuma mwaliko.';

  @override
  String get wealthSendInvite => 'Tuma mwaliko';

  @override
  String get wealthInviteSent => 'Mwaliko umetumwa.';

  @override
  String get wealthLoadingMembers => 'Inapakia wanachama...';

  @override
  String get wealthPotMembers => 'Wanachama wa pot';

  @override
  String get wealthPotMembersHelp => 'Wote wenye ruhusa kwenye pot hii.';

  @override
  String get wealthNoMembersYet => 'Hakuna wanachama bado';

  @override
  String get wealthSendFirstInvite => 'Tuma mwaliko wa kwanza kwa pot hii.';

  @override
  String get wealthUpdatingStatus => 'Inasasisha hali...';

  @override
  String get wealthPotStatusUpdated => 'Hali ya pot imesasishwa.';

  @override
  String get wealthSharedPotsTitle => 'Shared Pots';

  @override
  String get wealthNewPot => 'Pot mpya';

  @override
  String get wealthSharedMoneyOrganized => 'Fedha za pamoja, wazi kwa wote';

  @override
  String get wealthSharedMoneyHelp =>
      'Weka fedha pamoja kwa lengo moja. Mfano: familia, shule, au timu ya biashara.';

  @override
  String get wealthSharedPotsLoadTitle => 'Shared pots hazikupatikana';

  @override
  String get commonTryAgain => 'Jaribu tena';

  @override
  String get wealthNoSharedPotYet => 'Hakuna shared pot bado';

  @override
  String get wealthNoSharedPotMessage =>
      'Anza pot kwa familia, shule, au timu ya biashara.';

  @override
  String get wealthCreatePot => 'Unda pot';

  @override
  String get wealthContribute => 'Changia';

  @override
  String get wealthMembers => 'Wanachama';

  @override
  String get wealthWithdraw => 'Toa fedha';

  @override
  String get commonEdit => 'Hariri';

  @override
  String get commonPause => 'Sitisha';

  @override
  String get commonActivate => 'Washa tena';

  @override
  String get commonArchive => 'Hifadhi mbali';

  @override
  String wealthContributedLabel(String value) {
    return 'Amechangia $value';
  }

  @override
  String wealthContributedTargetLabel(String contributed, String target) {
    return 'Amechangia $contributed / Lengo $target';
  }

  @override
  String wealthTargetChip(String value) {
    return 'Target $value';
  }
}
