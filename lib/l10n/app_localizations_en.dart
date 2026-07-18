// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle =>
      'Choose your preferred language for the app interface.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Configure how you receive alerts and updates.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishSubtitle => 'Default language for app and services';

  @override
  String get languageSwahili => 'Swahili';

  @override
  String get languageSwahiliSubtitle => 'Lugha ya Kiswahili kwa Orbi';

  @override
  String get applyToAppLanguageTitle => 'Apply to app language';

  @override
  String get applyToAppLanguageSubtitle => 'Switch the app UI language.';

  @override
  String get applyToServicesTitle => 'Apply to services';

  @override
  String get applyToServicesSubtitle =>
      'Use this language for notifications and messaging.';

  @override
  String get serviceNotificationsTitle => 'Service notifications';

  @override
  String get securityAlertsTitle => 'Security alerts';

  @override
  String get securityAlertsSubtitle =>
      'Login attempts, new devices, and safety checks.';

  @override
  String get financialAlertsTitle => 'Financial alerts';

  @override
  String get financialAlertsSubtitle =>
      'Transactions, payments, and transfers.';

  @override
  String get budgetAlertsTitle => 'Budget alerts';

  @override
  String get budgetAlertsSubtitle => 'Spending limits and budget updates.';

  @override
  String get goalsTitle => 'Goals & Budget';

  @override
  String get goalsSubtitle =>
      'Create savings targets, move money into them, and keep everyday spending limits organized.';

  @override
  String get goalsRefresh => 'Refresh';

  @override
  String get goalsNewGoal => 'New Goal';

  @override
  String get goalsNewBudget => 'New Budget';

  @override
  String get goalsNewTask => 'New Task';

  @override
  String get goalsPlanningTitle => 'Consumer planning';

  @override
  String get goalsMetricGoals => 'Goals';

  @override
  String get goalsMetricSaved => 'Saved';

  @override
  String get goalsMetricTarget => 'Target';

  @override
  String get goalsMetricBudgets => 'Budgets';

  @override
  String get goalsTabGoals => 'Goals';

  @override
  String get goalsTabBudget => 'Budget';

  @override
  String get goalsTabTasks => 'Tasks';

  @override
  String get goalsEmptyTitle => 'No goals yet';

  @override
  String get goalsEmptyMessage =>
      'Create your first goal and start moving wallet funds into it.';

  @override
  String get goalsBudgetEmptyTitle => 'No budgets yet';

  @override
  String get goalsBudgetEmptyMessage =>
      'Create budget categories for groceries, transport, rent, and more.';

  @override
  String get goalsTasksEmptyTitle => 'No tasks yet';

  @override
  String get goalsTasksEmptyMessage =>
      'Add planning tasks to track the actions that move your goals forward.';

  @override
  String get goalsDefaultGoalName => 'Savings goal';

  @override
  String get goalsDefaultBudgetName => 'Budget category';

  @override
  String get goalsTaskFallback => 'Planning task';

  @override
  String get goalsDeadlineLabel => 'Deadline';

  @override
  String get goalsAllocateButton => 'Allocate';

  @override
  String get goalsWithdrawButton => 'Withdraw';

  @override
  String get goalsDeleteButton => 'Delete';

  @override
  String get goalsEditButton => 'Edit';

  @override
  String goalsBudgetLimit(String amount) {
    return 'Budget limit: $amount';
  }

  @override
  String get goalsHardLimit => 'Hard limit';

  @override
  String get goalsSoftLimit => 'Soft limit';

  @override
  String get goalsLoadFailedTitle => 'Unable to load goals and budgets';

  @override
  String get goalsCreateGoalTitle => 'Create goal';

  @override
  String get goalsEditGoalTitle => 'Edit goal';

  @override
  String get goalsGoalNameLabel => 'Goal name';

  @override
  String get goalsTargetAmountLabel => 'Target amount';

  @override
  String get goalsFundingStrategyLabel => 'Funding strategy';

  @override
  String get goalsFundingManual => 'Manual';

  @override
  String get goalsFundingPercentage => 'Auto by income percentage';

  @override
  String get goalsFundingFixed => 'Auto fixed monthly amount';

  @override
  String get goalsAutoAllocationLabel => 'Enable auto allocation';

  @override
  String get goalsAutoAllocationHint =>
      'Let Orbi route part of future income into this goal automatically.';

  @override
  String get goalsIncomePercentageLabel => 'Income percentage';

  @override
  String get goalsIncomePercentageHint =>
      'How much of incoming funds should be routed here.';

  @override
  String get goalsMonthlyTargetLabel => 'Monthly auto amount';

  @override
  String get goalsMonthlyTargetHint =>
      'Fixed amount to move into this goal each month.';

  @override
  String get goalsOptional => 'Optional';

  @override
  String get goalsGoalValidationMessage =>
      'Enter a goal name and valid target amount.';

  @override
  String get goalsIncomePercentageValidation =>
      'Enter a valid income percentage for auto allocation.';

  @override
  String get goalsMonthlyTargetValidation =>
      'Enter a valid monthly amount for auto allocation.';

  @override
  String get goalsGoalCreatedMessage => 'Goal created.';

  @override
  String get goalsGoalUpdatedMessage => 'Goal updated.';

  @override
  String get goalsSaveGoalButton => 'Save goal';

  @override
  String get goalsUpdateGoalButton => 'Update goal';

  @override
  String get goalsCreateBudgetTitle => 'Create budget';

  @override
  String get goalsEditBudgetTitle => 'Edit budget';

  @override
  String get goalsCreateTaskTitle => 'Create task';

  @override
  String get goalsEditTaskTitle => 'Edit task';

  @override
  String get goalsCategoryNameLabel => 'Category name';

  @override
  String get goalsBudgetAmountLabel => 'Budget amount';

  @override
  String get goalsTaskTextLabel => 'Task';

  @override
  String get goalsTaskLinkedGoalLabel => 'Linked goal';

  @override
  String get goalsTaskNoLinkedGoal => 'No linked goal';

  @override
  String get goalsTaskBountyLabel => 'Bounty amount';

  @override
  String get goalsTaskDuePickerLabel => 'Due date';

  @override
  String get goalsTaskCompletedToggle => 'Mark as completed';

  @override
  String get goalsBudgetValidationMessage =>
      'Enter a category name and valid budget amount.';

  @override
  String get goalsTaskValidationMessage => 'Enter a task before saving.';

  @override
  String get goalsBudgetCreatedMessage => 'Budget created.';

  @override
  String get goalsBudgetUpdatedMessage => 'Budget updated.';

  @override
  String get goalsTaskCreatedMessage => 'Task created.';

  @override
  String get goalsTaskUpdatedMessage => 'Task updated.';

  @override
  String get goalsSaveBudgetButton => 'Save budget';

  @override
  String get goalsUpdateBudgetButton => 'Update budget';

  @override
  String get goalsSaveTaskButton => 'Save task';

  @override
  String get goalsUpdateTaskButton => 'Update task';

  @override
  String goalsAllocateSheetTitle(String name) {
    return 'Allocate to $name';
  }

  @override
  String get goalsAllocateFallbackName => 'goal';

  @override
  String get goalsNoSourceWalletsMessage =>
      'No wallet was found for this action on your account.';

  @override
  String get goalsNoDestinationWalletsMessage =>
      'No destination wallet was found for this action on your account.';

  @override
  String get goalsSourceWalletLabel => 'Source wallet';

  @override
  String get goalsDestinationWalletLabel => 'Destination wallet';

  @override
  String get goalsAmountLabel => 'Amount';

  @override
  String get goalsAllocateValidationMessage =>
      'Select a wallet and enter a valid amount.';

  @override
  String get goalsAllocatedMessage => 'Funds allocated to goal.';

  @override
  String get goalsAllocateFundsButton => 'Allocate funds';

  @override
  String goalsWithdrawSheetTitle(String name) {
    return 'Withdraw from $name';
  }

  @override
  String get goalsWithdrawLockedHint =>
      'Goal funds are protected. Withdrawals should be explicit and intentional.';

  @override
  String get goalsWithdrawValidationMessage =>
      'Select a destination wallet and enter a valid amount.';

  @override
  String get goalsWithdrawnMessage => 'Funds withdrawn from goal.';

  @override
  String get goalsWithdrawFundsButton => 'Withdraw funds';

  @override
  String get goalsDeleteGoalTitle => 'Delete goal';

  @override
  String get goalsDeleteGoalMessage =>
      'This goal will be removed from your planner.';

  @override
  String get goalsDeletedMessage => 'Goal deleted.';

  @override
  String get goalsDeleteBudgetTitle => 'Delete budget';

  @override
  String get goalsDeleteBudgetMessage =>
      'This budget category will be removed.';

  @override
  String get goalsBudgetDeletedMessage => 'Budget deleted.';

  @override
  String get goalsDeleteTaskTitle => 'Delete task';

  @override
  String get goalsDeleteTaskMessage => 'This planning task will be removed.';

  @override
  String get goalsTaskDeletedMessage => 'Task deleted.';

  @override
  String get goalsTaskCompletedMessage => 'Task completed.';

  @override
  String get goalsTaskReopenedMessage => 'Task reopened.';

  @override
  String get goalsContinueAction => 'Continue';

  @override
  String get goalsFlexibleDate => 'Flexible';

  @override
  String get goalsTaskCompleted => 'Completed';

  @override
  String get goalsTaskPending => 'Pending';

  @override
  String get goalsTaskDueLabel => 'Due';

  @override
  String goalsTaskLinkedGoal(String name) {
    return 'Goal: $name';
  }

  @override
  String goalsTaskBounty(String amount) {
    return 'Bounty: $amount';
  }

  @override
  String get marketingUpdatesTitle => 'Marketing updates';

  @override
  String get marketingUpdatesSubtitle =>
      'Promotions, tips, and product announcements.';

  @override
  String get applyToAppButton => 'Apply to App';

  @override
  String get applyToServicesButton => 'Apply to Services';

  @override
  String get applyAllButton => 'Apply All';

  @override
  String get applyButton => 'Apply';

  @override
  String get applyingButton => 'Applying...';

  @override
  String appLanguageSetMessage(String language) {
    return 'App language set to $language.';
  }

  @override
  String get appLanguageFollowSystemMessage =>
      'App language will follow system settings.';

  @override
  String get appLoadingStatus => 'Loading ORBI';

  @override
  String get appLoadingDetail =>
      'Preparing your secure workspace and restoring your session.';

  @override
  String get preferencesLoadingStatus => 'Loading your preferences';

  @override
  String get preferencesLoadingDetail =>
      'Syncing language, appearance, and device preferences.';

  @override
  String get inactivityWarningTitle => 'Are you still using ORBI?';

  @override
  String get inactivityWarningMessage =>
      'Your app will lock soon due to inactivity.';

  @override
  String inactivityWarningCountdown(int seconds) {
    return 'Locks in ${seconds}s';
  }

  @override
  String get inactivityWarningStayButton => 'I\'m still using ORBI';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionVerify => 'Verify';

  @override
  String get actionLogout => 'Logout';

  @override
  String get actionSetUpNow => 'Set Up Now';

  @override
  String get actionUnlock => 'Unlock';

  @override
  String get actionSendLink => 'Send Link';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionUpdate => 'Update';

  @override
  String get actionSave => 'Save';

  @override
  String get actionClose => 'Close';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionOk => 'OK';

  @override
  String get actionAddCard => 'Add Card';

  @override
  String get actionPrintReceipt => 'Print Receipt';

  @override
  String get actionDownloadPrint => 'Download / Print';

  @override
  String get actionShareReceipt => 'Share Receipt';

  @override
  String get actionCreateRequest => 'Create Request';

  @override
  String get actionScanAgain => 'Scan Again';

  @override
  String get actionFromGallery => 'From Gallery';

  @override
  String get actionCapture => 'Capture';

  @override
  String get actionLogin => 'Login';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelPassword => 'Password';

  @override
  String get loginEnterEmailPasswordMessage =>
      'Enter both email and password before logging in.';

  @override
  String get loginInvalidPinMessage => 'Invalid PIN.';

  @override
  String get loginEnterPinTitle => 'Enter PIN';

  @override
  String get loginPinLabel => '4-6 digit PIN';

  @override
  String get loginEnterOtpTitle => 'Enter OTP';

  @override
  String get loginOtpCodeLabel => 'Code';

  @override
  String get loginBiometricSetupRequiredTitle => 'Biometric Setup Required';

  @override
  String get loginBiometricSetupRequiredBody =>
      'To continue, you must register your device biometric. This is required by your account security policy.';

  @override
  String get loginBiometricSetupFailedMessage =>
      'Biometric setup failed. Please try again.';

  @override
  String get loginResetPasswordTitle => 'Reset Password';

  @override
  String get loginEmailHint => 'user@example.com';

  @override
  String get loginResetLinkSentMessage =>
      'If the account exists, a password reset email has been sent.';

  @override
  String get loginResetFailedMessage => 'Failed to initiate password reset.';

  @override
  String get loginOrbiLoginTitle => 'ORBI LOGIN';

  @override
  String get loginSecureDeviceAttached => 'Secure device attached';

  @override
  String get loginAuthenticateWithBiometric =>
      'Authenticate with fingerprint or face';

  @override
  String get loginBiometricFallbackHint =>
      'If prompt does not open, use password login below.';

  @override
  String get loginSecurityVerificationTitle => 'Security Verification';

  @override
  String get loginAuthenticatingSecurely => 'Signing you in...';

  @override
  String get loginAuthenticating => 'Signing in...';

  @override
  String get loginUsePasswordInstead => 'Use Password Instead';

  @override
  String get loginUsePinInstead => 'Use PIN Instead';

  @override
  String get loginOrbiTagline => 'ORBI Financial Technologies';

  @override
  String get loginWelcomeTitle => 'Welcome to ORBI';

  @override
  String get appBarGreetingMorning => 'Good Morning';

  @override
  String get appBarGreetingAfternoon => 'Good Afternoon';

  @override
  String get appBarGreetingEvening => 'Good Evening';

  @override
  String get appBarCustomerIdLabel => 'ID';

  @override
  String get dashboardLinkedCardsTitle => 'Linked Cards';

  @override
  String get dashboardLinkedCardsEmptyTitle => 'No linked cards yet';

  @override
  String get dashboardLinkedCardsEmptyMessage =>
      'Link your wallet to manage your wealth.';

  @override
  String get loginSecureSignInSubtitle =>
      'Secure sign in with password or biometrics.';

  @override
  String get loginUseFingerprintButton => 'Use Fingerprint / Face ID';

  @override
  String get loginOrUsePassword => 'or use password';

  @override
  String get loginBiometricTemporarilyLocked =>
      'Biometric temporarily locked. Use password login.';

  @override
  String get loginBiometricMissing =>
      'Biometric registration not found. Please login with password once, then re-enable biometrics in Settings.';

  @override
  String get loginUnlockWithPin => 'Unlock with PIN';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNewUserCreateAccount => 'New user? Create an account';

  @override
  String get signupAcceptTermsMessage => 'Please accept terms to continue.';

  @override
  String get signupCreateAccountTitle => 'Create your ORBI account';

  @override
  String get signupSubtitle => 'Secure signup connected to ORBI backend.';

  @override
  String get signupStepPersonalInfo => 'Personal Info';

  @override
  String get signupStepContactDetails => 'Contact Details';

  @override
  String get signupStepVerification => 'Verification';

  @override
  String get signupStepShortInfo => 'Info';

  @override
  String get signupStepShortCountry => 'Country';

  @override
  String get signupStepShortVerify => 'Verify';

  @override
  String get signupSecurityVerificationTitle => 'Security Verification';

  @override
  String get signupSecurityVerificationHelper =>
      'Enter the OTP sent to your registered contact to continue secure setup.';

  @override
  String get signupSelectLanguageTitle => 'Select language';

  @override
  String get signupAboutYouTitle => 'Tell us about you';

  @override
  String get signupAboutYouSubtitle =>
      'Share a few personal details so we can personalize your ORBI experience from the start.';

  @override
  String get signupAddressHelper =>
      'Add your address to help us tailor services and offers for you. (Optional)';

  @override
  String get signupChooseCountryTitle => 'Choose your country';

  @override
  String get signupChooseCountrySubtitle =>
      'Select your country so ORBI can match your language, currency, and financial experience more closely to your market.';

  @override
  String get signupLanguageLabel => 'Language';

  @override
  String get signupCurrencyLabel => 'Currency';

  @override
  String get signupPhoneHelper =>
      'Enter your local number only. Your country code is added automatically.';

  @override
  String get signupNationalityHelper =>
      'Auto-filled from your country, and you can adjust it if needed.';

  @override
  String get signupSecureAccountTitle => 'Secure your account';

  @override
  String get signupSecureAccountSubtitle =>
      'Create a strong password so your money, rewards, and business activity stay protected.';

  @override
  String get secureAccountSetupTitle => 'Secure your account';

  @override
  String get secureAccountSetupSubtitle =>
      'Signup was successful. Complete these two security steps before entering ORBI.';

  @override
  String get secureAccountSetupRegisterFingerprintFirst =>
      'Register fingerprint first, then set your PIN.';

  @override
  String get secureAccountSetupPinMismatch =>
      'Enter a 4 digit PIN and confirm it correctly.';

  @override
  String get secureAccountSetupSuccess =>
      'Fingerprint and PIN are both secured.';

  @override
  String get secureAccountSetupPinEnrollFailed =>
      'Unable to secure your PIN right now.';

  @override
  String get secureAccountSetupBiometricReady =>
      'Fingerprint is registered. Now set your PIN to finish.';

  @override
  String get secureAccountSetupLoading => 'Securing your account...';

  @override
  String get secureAccountStepFingerprintTitle => 'Register fingerprint';

  @override
  String get secureAccountStepFingerprintMessage =>
      'Biometric login gives you fast and secure account access.';

  @override
  String get secureAccountStepPinTitle => 'Set PIN';

  @override
  String get secureAccountStepPinMessage =>
      'Your PIN protects money actions and gives you fast return access.';

  @override
  String get secureAccountSignOutInstead => 'Sign out instead';

  @override
  String get actionRegisterNow => 'Register now';

  @override
  String get commonDone => 'Done';

  @override
  String get commonReady => 'Ready';

  @override
  String get signupAgreeTermsTitle => 'I agree to ORBI Terms & Conditions';

  @override
  String get signupAgreeTermsSubtitle =>
      'By joining ORBI, you unlock a safer way to receive salary, manage spending, access offers, and grow your financial life with confidence.';

  @override
  String get signupReviewTitle => 'Registration review';

  @override
  String get signupReviewNameFallback => 'Your name';

  @override
  String get signupReviewEmailFallback => 'Email pending';

  @override
  String get signupEasyOnboardingBadge => 'Easy onboarding';

  @override
  String get signupPersonalizedBadge => 'Built around you';

  @override
  String get signupSafeSecureBadge => 'Safe & secure';

  @override
  String get signupHeroSubtitle =>
      'Open your ORBI account in a few simple steps and start managing money, payments, and opportunities with more confidence.';

  @override
  String signupStepCounter(String current, String total, String title) {
    return 'Step $current of $total • $title';
  }

  @override
  String get signupSignInButton => 'Sign in';

  @override
  String get signupBackButton => 'Back';

  @override
  String get signupNextButton => 'Next';

  @override
  String get signupSubmittingButton => 'Submitting...';

  @override
  String get labelFullName => 'Full name';

  @override
  String get signupFullNameRequired => 'Full name is required';

  @override
  String get signupFullNameInvalid => 'Enter a valid name';

  @override
  String get labelCountry => 'Country';

  @override
  String get labelPhoneNumber => 'Phone number';

  @override
  String get signupPhoneRequired => 'Phone is required';

  @override
  String get signupPhoneInvalid => 'Enter a valid phone';

  @override
  String get labelNationality => 'Nationality';

  @override
  String get labelAddress => 'Address';

  @override
  String get labelPreferredCurrency => 'Preferred currency';

  @override
  String get labelEmailAddress => 'Email address';

  @override
  String get signupEmailRequired => 'Email is required';

  @override
  String get signupEmailInvalid => 'Enter a valid email';

  @override
  String get signupPasswordRequired => 'Password is required';

  @override
  String get signupPasswordMin => 'Use at least 8 characters';

  @override
  String get labelConfirmPassword => 'Confirm password';

  @override
  String get signupPasswordsMismatch => 'Passwords do not match';

  @override
  String get signupAgreeTerms => 'I agree to Terms and Privacy Policy';

  @override
  String get actionCreateAccount => 'Create Account';

  @override
  String get signupAlreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get onboardingWelcomeTitle => 'Welcome to ORBI';

  @override
  String get onboardingWelcomeSubtitle =>
      'Your first setup for a guided money experience.';

  @override
  String get onboardingHeroTitle =>
      'A smarter money experience designed to help you grow your wealth.';

  @override
  String get onboardingHeroSubtitle =>
      'Receive salary, send money, pay bills, manage business spending, and enjoy trusted merchant experiences with more confidence, more control, and less pressure.';

  @override
  String get onboardingBadgeFast => 'Fast';

  @override
  String get onboardingBadgeEveryday => 'Everyday value';

  @override
  String get onboardingBadgeSecure => 'Secure';

  @override
  String get onboardingPromo1Badge => 'Confidence first';

  @override
  String get onboardingPromo1Title =>
      'Enjoy peace of mind every time you move money';

  @override
  String get onboardingPromo1Body =>
      'From transfers to bill payments, ORBI helps your money move smoothly and safely so you can focus on life, not financial stress.';

  @override
  String get onboardingPromo2Badge => 'Salary power';

  @override
  String get onboardingPromo2Title =>
      'Make your salary feel more valuable from day one';

  @override
  String get onboardingPromo2Body =>
      'Receive salary, support family, pay essentials, and plan ahead with more clarity, giving every payday a stronger sense of control and progress.';

  @override
  String get onboardingPromo3Badge => 'Smarter lifestyle';

  @override
  String get onboardingPromo3Title =>
      'Spend with control, discover value, and avoid surprises';

  @override
  String get onboardingPromo3Body =>
      'Stay on budget, shop with trusted merchants, and enjoy better offers through an experience designed to make everyday spending feel lighter and smarter.';

  @override
  String get onboardingPromo4Badge => 'Business ready';

  @override
  String get onboardingPromo4Title =>
      'Built for ambitious people and growing businesses';

  @override
  String get onboardingPromo4Body =>
      'Whether you manage personal money, team budgets, or merchant payments, ORBI gives you a more organized, secure, and professional way to grow.';

  @override
  String get onboardingTermsTitle => 'Terms at a glance';

  @override
  String get onboardingTermsSubtitle =>
      'Before registration, please review the basics that help keep your account, payments, and financial experience safe.';

  @override
  String get onboardingTermsHighlight1 =>
      'Use accurate identity, contact, and country details when creating your account.';

  @override
  String get onboardingTermsHighlight2 =>
      'Protect your password, OTP codes, and biometric access so no one can act on your behalf.';

  @override
  String get onboardingTermsHighlight3 =>
      'Some payments and account actions may require verification for your protection.';

  @override
  String get onboardingTermsHighlight4 =>
      'Certain features may need extra review before they are fully activated.';

  @override
  String get onboardingTermsConfirm =>
      'You will confirm these terms again before finishing your account registration.';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionViewAll => 'View all';

  @override
  String get profileMakePaymentTitle => 'Make Payment';

  @override
  String get profileScanQrCodeTitle => 'Scan QR Code';

  @override
  String get profileScanQrAction => 'Scan QR';

  @override
  String get paymentFlashOn => 'Flash On';

  @override
  String get paymentFlashOff => 'Flash Off';

  @override
  String get paymentQrPrompt => 'Point camera at a QR code to scan.';

  @override
  String paymentScannedValue(String value) {
    return 'Scanned value:\n$value';
  }

  @override
  String get paymentNoReceiptSelected =>
      'No receipt or document selected.\nCapture or import below.';

  @override
  String paymentSavedPath(String path) {
    return 'Saved path: $path';
  }

  @override
  String get paymentAnalyzing => 'Analyzing...';

  @override
  String get paymentAnalyzeReceipt => 'Analyze Receipt';

  @override
  String get paymentExtractedDetails => 'Extracted Details';

  @override
  String get paymentMerchantLabel => 'Merchant';

  @override
  String get paymentAmountLabel => 'Amount';

  @override
  String get paymentDateLabel => 'Date';

  @override
  String get walletTitle => 'Wealth';

  @override
  String get shellSessionExpiredMessage =>
      'Session expired. Please log in again.';

  @override
  String get shellNoNetworkMessage =>
      'No network connection. Check internet and retry.';

  @override
  String get shellStartupFailedMessage =>
      'Failed to load startup data. Please retry.';

  @override
  String get shellStartupUnavailableTitle => 'Startup data unavailable';

  @override
  String get shellQuickActionsTitle => 'Quick Actions';

  @override
  String get shellQuickActionsSubtitle =>
      'Jump into the most-used money actions.';

  @override
  String get shellActionTransfer => 'Transfer';

  @override
  String get shellActionRequest => 'Request';

  @override
  String get shellActionScanPay => 'Scan & Pay';

  @override
  String get shellActionAlerts => 'Alerts';

  @override
  String get shellNavHome => 'Home';

  @override
  String get shellNavTransactions => 'Transactions';

  @override
  String get shellNavGoals => 'Goals';

  @override
  String get shellBootstrapSubtitle => 'Your Secure Financial Platform';

  @override
  String get shellOfflineBanner =>
      'You are offline or live updates are paused. Some data may be stale.';

  @override
  String get shellPleaseWaitMoment => 'Please, wait a moment...';

  @override
  String walletFeatureComingSoon(String feature) {
    return '$feature coming soon';
  }

  @override
  String get walletSubtitle =>
      'A clear view of your accounts, balances, and liquidity';

  @override
  String walletProvisioningPreparingAuto(String current, String total) {
    return 'We are preparing your wealth accounts and card. Refreshing automatically... ($current/$total)';
  }

  @override
  String get walletProvisioningPreparingManual =>
      'We are still preparing your wealth accounts and card. Pull to refresh.';

  @override
  String get walletTotalBalanceTitle => 'Total Wealth Balance';

  @override
  String walletAccountsCount(String count) {
    return '$count accounts';
  }

  @override
  String get walletFilterAll => 'All';

  @override
  String get walletFilterOrbi => 'Orbi';

  @override
  String get walletFilterLinked => 'Linked';

  @override
  String get walletShowBalances => 'Show balances';

  @override
  String get walletHideBalances => 'Hide balances';

  @override
  String get walletQuickTransfer => 'Transfer';

  @override
  String get walletQuickTopUp => 'Top Up';

  @override
  String get walletQuickLinkAccount => 'Link Account';

  @override
  String get walletQuickSendMoney => 'Send money';

  @override
  String get walletQuickTopUpFlow => 'Top up flow';

  @override
  String get walletQuickLinkAccountFlow => 'Link account flow';

  @override
  String walletIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get walletTransactionsButton => 'Transactions';

  @override
  String get walletFetchTransactionsFailed =>
      'Unable to fetch transactions for this account right now.';

  @override
  String walletTransactionsTitle(String wallet) {
    return '$wallet Transactions';
  }

  @override
  String get walletNoTransactionsFound =>
      'No transactions found for this account.';

  @override
  String walletTransactionRef(String ref) {
    return 'Ref: $ref';
  }

  @override
  String get walletFailedLoadAccounts => 'Failed to load wealth accounts';

  @override
  String get walletNoAccountsYet => 'No wealth accounts available yet.';

  @override
  String get walletNoAccountsMatchFilter => 'No accounts match this filter.';

  @override
  String get walletMainCardShownTop =>
      'Your main account card is shown at the top.';

  @override
  String get walletLoadingAccounts => 'Loading wealth accounts...';

  @override
  String get dashboardNetWorth => 'Net Worth';

  @override
  String get dashboardLifecycleTitle => 'Money lifecycle';

  @override
  String get dashboardUnallocated => 'Unallocated';

  @override
  String get dashboardAllocated => 'Allocated';

  @override
  String get dashboardSecure => 'Secure';

  @override
  String dashboardThisMonth(String value) {
    return '$value% this month';
  }

  @override
  String get dashboardPortfolio => 'Portfolio';

  @override
  String get dashboardLinkedWallets => 'Linked Wallets';

  @override
  String get dashboardOrbiWallet => 'Orbi Wallet';

  @override
  String get dashboardInternalAccounts => 'Internal Accounts';

  @override
  String get dashboardReadyToUse => 'Ready to use';

  @override
  String get dashboardAnalyzingBehavior =>
      'Analyzing your financial behavior...';

  @override
  String get dashboardInsightWedge => 'Insight Wedge';

  @override
  String get dashboardInsightsSubtitle =>
      'AI-generated alerts, suggestions, and advice for your finances.';

  @override
  String get dashboardNoInsightsTitle => 'No insights available yet';

  @override
  String get dashboardNoInsightsMessage =>
      'Insights will appear once your latest financial activity has been analyzed.';

  @override
  String get dashboardSpendingAlerts => 'Spending Alerts';

  @override
  String get dashboardBudgetSuggestions => 'Budget Suggestions';

  @override
  String get dashboardFinancialAdvice => 'Financial Advice';

  @override
  String get dashboardNoItemsNow => 'No items available right now.';

  @override
  String get settingsBiometricDisabledMessage => 'Biometric login disabled';

  @override
  String get settingsSetPinTitle => 'Set PIN';

  @override
  String get settingsPinsInvalidMessage => 'PINs do not match or are invalid.';

  @override
  String get settingsChangePinTitle => 'Change PIN';

  @override
  String get settingsCurrentPinIncorrectMessage => 'Current PIN is incorrect.';

  @override
  String get settingsNewPinInvalidMessage =>
      'New PIN is invalid or does not match.';

  @override
  String get settingsPinUpdatedMessage => 'PIN updated successfully.';

  @override
  String get settingsChangePasswordTitle => 'Change Password';

  @override
  String get settingsPasswordMinMessage =>
      'Password must be at least 8 characters.';

  @override
  String get settingsPasswordsNoMatchMessage => 'Passwords do not match.';

  @override
  String get settingsChooseFromGallery => 'Choose from gallery';

  @override
  String get settingsTakePhoto => 'Take photo';

  @override
  String get settingsUpdateKycInformation => 'Update KYC Information';

  @override
  String get settingsUploadIdFirstMessage => 'Upload ID image first';

  @override
  String get settingsEnterIdNumberMessage => 'Enter your ID number';

  @override
  String get settingsKycSubmittedMessage =>
      'KYC submitted successfully for review';

  @override
  String get settingsLogoutTitle => 'Logout';

  @override
  String get settingsLogoutConfirmMessage => 'Are you sure you want to logout?';

  @override
  String get sendMoneySearchRecipientMessage =>
      'Search and confirm the recipient before continuing';

  @override
  String get sendMoneyEnterValidAmountMessage => 'Enter a valid amount';

  @override
  String get sendMoneySessionExpiredMessage =>
      'Your session has expired. Please log in again.';

  @override
  String get sendMoneyTransferBlockedMessage =>
      'This transfer is blocked for safety.';

  @override
  String get sendMoneyVerificationSuccessMessage =>
      'Verification successful. Continuing...';

  @override
  String get sendMoneyTitle => 'Send Money';

  @override
  String requestMoneyCreatedMessage(String from, String amount) {
    return 'Request created for $from ($amount)';
  }

  @override
  String get requestMoneyTitle => 'Request Money';

  @override
  String get enterpriseTitle => 'Enterprise';

  @override
  String get enterpriseEnableAutoSweepTitle => 'Enable Auto-sweep';

  @override
  String get enterpriseAutoSweepUpdatedMessage => 'Auto-sweep updated';

  @override
  String get enterpriseApprovalSubmittedMessage => 'Approval submitted';

  @override
  String get paymentScannerTitle => 'Scanner';

  @override
  String get paymentHubTitle => 'Pay';

  @override
  String get paymentHubSubtitle =>
      'Pay bills, settle merchant payments, or use QR and receipt tools from one place.';

  @override
  String get paymentTabBills => 'Bills';

  @override
  String get paymentTabMerchants => 'Merchants';

  @override
  String get paymentBillsTitle => 'Pay bills';

  @override
  String get paymentBillsSubtitle =>
      'Choose a service category, then continue with the provider you want to pay.';

  @override
  String get paymentMerchantTitle => 'Pay merchants';

  @override
  String get paymentMerchantSubtitle =>
      'Pay a merchant by pay number, QR scan, or receipt photo.';

  @override
  String get paymentMerchantNumberTitle => 'Pay by merchant number';

  @override
  String get paymentMerchantNumberSubtitle =>
      'Enter the merchant pay number to continue with a verified payment.';

  @override
  String get paymentMerchantNumberLabel => 'Merchant pay number';

  @override
  String get paymentMerchantNumberHint => 'Enter pay number';

  @override
  String get paymentContinueMerchantPay => 'Continue to merchant payment';

  @override
  String get paymentBillProvidersTitle => 'Popular providers';

  @override
  String get paymentBillProvidersEmpty =>
      'Providers will appear here for this bill category.';

  @override
  String get paymentQrDetectedTitle => 'Scan detected';

  @override
  String get paymentQrDetectedSubtitle =>
      'ORBI prepared a payment draft from the scanned details.';

  @override
  String get paymentMerchantQrTitle => 'Pay merchant with QR';

  @override
  String get paymentMerchantQrSubtitle =>
      'Scan any supported payment QR and let ORBI build the payment draft instantly.';

  @override
  String get paymentMerchantQrFrameHint =>
      'Place the merchant QR inside the frame';

  @override
  String get paymentScanSearching => 'Looking for QR...';

  @override
  String get paymentScanSearchingSubtitle =>
      'Scan to build a payment draft automatically from the detected details.';

  @override
  String get paymentScannerUnavailableTitle => 'Scanner unavailable';

  @override
  String get paymentScannerPermissionRequired =>
      'Camera permission is required to scan QR codes.';

  @override
  String get paymentScannerUnsupported =>
      'QR scanning is not supported on this device.';

  @override
  String get paymentScannerPreparing =>
      'Scanner is still preparing. Try again.';

  @override
  String get paymentScannerGenericError =>
      'Unable to open QR scanner right now.';

  @override
  String get paymentScannerOpenSettings => 'Open settings';

  @override
  String get paymentScanDetected => 'QR detected';

  @override
  String get paymentScanSourceQr => 'QR scan';

  @override
  String get paymentScanSourceReceipt => 'Receipt scan';

  @override
  String get paymentScanTypeMerchant => 'Merchant payment';

  @override
  String get paymentScanTypeBill => 'Bill payment';

  @override
  String get paymentScanTypeUniversal => 'Universal payment';

  @override
  String paymentScanBillDraftTitle(String name) {
    return '$name bill is ready';
  }

  @override
  String paymentScanMerchantDraftTitle(String name) {
    return '$name is ready to pay';
  }

  @override
  String paymentScanUniversalDraftTitle(String name) {
    return '$name details detected';
  }

  @override
  String get paymentScanBillDraftSubtitle =>
      'ORBI matched the provider and prepared a bill payment draft from this scan.';

  @override
  String get paymentScanMerchantDraftSubtitle =>
      'ORBI recognized the merchant and created a ready-to-review merchant payment draft.';

  @override
  String get paymentScanUniversalDraftSubtitle =>
      'ORBI captured the payment details and created a draft you can review before paying.';

  @override
  String get paymentScanDraftAmountPending => 'Amount pending';

  @override
  String get paymentScanDraftAutoCreated => 'Draft created';

  @override
  String get paymentScanNeedsReview =>
      'Some details still need review before payment.';

  @override
  String get paymentScanNeedsReviewSubtitle =>
      'ORBI captured the scan, but a few payment details still need your review.';

  @override
  String get paymentScanOpenDraft => 'Review payment draft';

  @override
  String get paymentScanDetailMerchantId => 'Merchant ID';

  @override
  String get paymentNoteLabel => 'Note';

  @override
  String get paymentReceiptTitle => 'Use a receipt photo';

  @override
  String get paymentReceiptSubtitle =>
      'Upload or capture a receipt and let ORBI prepare a payment draft from the extracted details.';

  @override
  String get paymentUseForPayment => 'Use for payment';

  @override
  String get paymentOrbiPayTitle => 'ORBI Pay';

  @override
  String get paymentOrbiPayNoWallets =>
      'No wallet is available for ORBI Pay right now.';

  @override
  String get paymentOrbiPayAmountHint => 'Enter amount';

  @override
  String get paymentOrbiPayAmountValidation =>
      'Enter a valid amount for ORBI Pay.';

  @override
  String get paymentOrbiPayPreviewTitle => 'Payment preview';

  @override
  String get paymentOrbiPayPreviewAction => 'Preview';

  @override
  String get paymentOrbiPayConfirmAction => 'Pay now';

  @override
  String get paymentOrbiPaySuccess => 'ORBI Pay merchant payment submitted.';

  @override
  String get paymentMerchantDefaultNote => 'Merchant payment';

  @override
  String get paymentBillPayTitle => 'Bill payment';

  @override
  String get paymentBillPreviewTitle => 'Bill preview';

  @override
  String get paymentBillPayConfirmAction => 'Pay bill';

  @override
  String get paymentBillFundingWallet => 'Wallet';

  @override
  String get paymentBillFundingReserve => 'Reserve';

  @override
  String get paymentBillFundingSharedBudget => 'Shared budget';

  @override
  String get paymentBillWalletHelper =>
      'Goal-backed wallets are excluded for safer bill payments.';

  @override
  String get paymentBillReserveHelper =>
      'This payment will use the reserve-backed wallet for the matched bill reserve.';

  @override
  String get paymentBillSharedBudgetHelper =>
      'Use a shared budget only when this bill belongs to that family or team budget.';

  @override
  String get paymentBillReserveMatchedTitle => 'Bill reserve matched';

  @override
  String get paymentBillReserveUsingTitle => 'Paying from reserve';

  @override
  String paymentBillReserveMatchedMessage(Object provider, Object amount) {
    return '$provider has a reserve with around $amount ready for this bill.';
  }

  @override
  String paymentBillReserveUsingMessage(Object provider, Object amount) {
    return '$provider will use the matched reserve amount of around $amount for this payment.';
  }

  @override
  String get paymentBillReserveStrongMatch => 'Strong reserve match';

  @override
  String get paymentBillReservePossibleMatch => 'Possible reserve match';

  @override
  String get paymentBillNoFundingSources =>
      'No safe bill payment source is available right now.';

  @override
  String get paymentBillPayReserveSuccess =>
      'Bill payment completed using the matched reserve wallet.';

  @override
  String get paymentBillPaySharedBudgetSuccess =>
      'Bill payment recorded against the shared budget.';

  @override
  String get paymentBillPaySuccess => 'Bill payment submitted.';

  @override
  String get paymentBillReferenceHint =>
      'Enter meter, control number, or account reference';

  @override
  String get paymentScanConfidenceHigh => 'High confidence';

  @override
  String get paymentScanConfidenceMedium => 'Medium confidence';

  @override
  String get paymentScanConfidenceLow => 'Low confidence';

  @override
  String get paymentScanConfidenceInvalid => 'Invalid scan';

  @override
  String get paymentScanInvalidTitle => 'This code is not ready for payment';

  @override
  String get paymentScanInvalidSubtitle =>
      'ORBI could not find enough trusted payment details in this scan. You can try another code or use merchant pay number.';

  @override
  String get paymentScanInvalidFallbackAction => 'Use merchant pay number';

  @override
  String get paymentScanInvalidStatus =>
      'This scan could not be used for payment.';

  @override
  String get paymentScanDetailRecipient => 'Recipient';

  @override
  String get paymentScanDetailProvider => 'Provider';

  @override
  String get paymentScanDetailCategory => 'Bill category';

  @override
  String get paymentScanDetailReference => 'Reference';

  @override
  String get paymentScanDetailSchema => 'Schema';

  @override
  String get paymentScanPaymentReady => 'Payment draft ready';

  @override
  String get paymentScanMerchantAutoRoute =>
      'Opening merchant payment draft...';

  @override
  String get paymentScanBillAutoRoute => 'Opening bill payment draft...';

  @override
  String get paymentReviewPayment => 'Review payment';

  @override
  String notificationsCouldNotOpenMessage(String value) {
    return 'Could not open $value';
  }

  @override
  String get notificationsDetailsTitle => 'Details';

  @override
  String notificationsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get notificationsClearSelection => 'Clear selection';

  @override
  String get notificationsSelectAll => 'Select all';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsEmptyTitle => 'All caught up';

  @override
  String get notificationsEmptyMessage =>
      'New alerts and account updates will appear here.';

  @override
  String get notificationsLoadFailedTitle => 'Could not load notifications';

  @override
  String get notificationsJustNow => 'just now';

  @override
  String notificationsMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String notificationsHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String notificationsDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String notificationsFullTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get transactionsSessionExpiredMessage =>
      'Your session has expired. Please log in again.';

  @override
  String get transactionsFetchFailedMessage =>
      'Unable to fetch transactions right now.';

  @override
  String get transactionsLoadFailedTitle => 'Could not load transactions';

  @override
  String get transactionsHistoryTitle => 'Transaction History';

  @override
  String get transactionsFilterByMoneyState => 'Filter by money state';

  @override
  String get transactionsFilterAll => 'All';

  @override
  String get transactionsEmptyTitle => 'No transactions yet';

  @override
  String get transactionsEmptyMessage =>
      'Completed payments and transfers will appear here.';

  @override
  String get transactionsNoFilteredMatchesTitle => 'No matching transactions';

  @override
  String get transactionsNoFilteredMatchesMessage =>
      'Try another money state to view matching activity.';

  @override
  String transactionsItemsCount(int count) {
    return '$count items';
  }

  @override
  String transactionsReceivedFrom(String name) {
    return 'Received from $name';
  }

  @override
  String transactionsSentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String get transactionsGenericTitle => 'Transaction';

  @override
  String get transactionsCredit => 'Credit';

  @override
  String get transactionsDebit => 'Debit';

  @override
  String get transactionsNotAvailable => 'N/A';

  @override
  String get transactionsStatusCompleted => 'Completed';

  @override
  String get transactionsReceiptReferenceId => 'Reference ID';

  @override
  String get transactionsReceiptType => 'Type';

  @override
  String get transactionsReceiptStatus => 'Status';

  @override
  String get transactionsReceiptAmount => 'Amount';

  @override
  String get transactionsReceiptBaseAmount => 'Base Amount';

  @override
  String get transactionsReceiptTax => 'Tax';

  @override
  String get transactionsReceiptServiceFee => 'Service Fee';

  @override
  String get transactionsReceiptTotalCharged => 'Total Charged';

  @override
  String get transactionsReceiptDirection => 'Direction';

  @override
  String get transactionsReceiptMoneyState => 'Money State';

  @override
  String get transactionsReceiptDate => 'Date';

  @override
  String get transactionsReceiptFrom => 'From';

  @override
  String get transactionsReceiptTo => 'To';

  @override
  String get actionDone => 'Done';

  @override
  String get sendMoneyLoadSourceWalletsFailedMessage =>
      'Unable to load source wallets.';

  @override
  String get sendMoneySearchMinCharsMessage =>
      'Type at least 5 characters to search';

  @override
  String get sendMoneySearchMinCharsLongMessage =>
      'Please type at least 5 characters to start searching.';

  @override
  String get sendMoneyRecipientNotFoundMessage =>
      'We couldn\'t find that person. Please check the ID or phone number and try again.';

  @override
  String get sendMoneySearchUnavailableMessage =>
      'Search is currently unavailable. Please try again in a moment.';

  @override
  String get sendMoneyPreviewFailedMessage =>
      'Unable to preview this transfer right now.';

  @override
  String get sendMoneyPreviewTimedOutMessage =>
      'Preview request timed out. Please try again.';

  @override
  String get sendMoneyPreviewRequestFailedMessage =>
      'Preview request failed. Please try again.';

  @override
  String sendMoneyPreviewRequestFailedWithStatus(int status) {
    return 'Preview failed ($status). Please try again.';
  }

  @override
  String get sendMoneyPreviewInvalidFormatMessage =>
      'Invalid preview response format';

  @override
  String get sendMoneyPreviewUnavailableMessage =>
      'Could not preview this transaction.';

  @override
  String get sendMoneyPreviewDataMissingMessage =>
      'Preview data missing from response';

  @override
  String get sendMoneyPreviewRejectedMessage => 'Preview rejected by backend.';

  @override
  String get sendMoneyConfirmTransferTitle => 'Confirm Transfer';

  @override
  String get sendMoneySubmittingLabel => 'Submitting...';

  @override
  String get sendMoneyConfirmAction => 'Confirm';

  @override
  String get sendMoneyTransactionSuccessfulTitle => 'Transaction Successful';

  @override
  String get sendMoneyTransactionFailedTitle => 'Transaction Failed';

  @override
  String get sendMoneySubmitFailedMessage =>
      'Unable to submit this transfer right now.';

  @override
  String get sendMoneyExternalSubmitFailedMessage =>
      'Unable to submit external transfer right now.';

  @override
  String get sendMoneyReceiptTransactionId => 'Transaction ID';

  @override
  String get sendMoneyReceiptReference => 'Reference';

  @override
  String get sendMoneyReceiptControlId => 'Control ID';

  @override
  String get sendMoneyReceiptStatus => 'Status';

  @override
  String get sendMoneyReceiptType => 'Type';

  @override
  String get sendMoneyReceiptTransaction => 'Transaction';

  @override
  String get sendMoneyReceiptRecipient => 'Recipient';

  @override
  String get sendMoneyReceiptSourceWallet => 'Source Wallet';

  @override
  String get sendMoneyReceiptAmount => 'Amount';

  @override
  String get sendMoneyReceiptTax => 'Tax';

  @override
  String get sendMoneyReceiptFee => 'Fee';

  @override
  String get sendMoneyReceiptTotal => 'Total';

  @override
  String get sendMoneyReceiptDescription => 'Description';

  @override
  String get sendMoneyReceiptTime => 'Time';

  @override
  String get sendMoneyHeroTitle => 'Move Money Faster';

  @override
  String get sendMoneyHeroInternalSubtitle =>
      'Instant transfers between Orbi users with secure preview and wallet selection.';

  @override
  String get sendMoneyHeroExternalSubtitle =>
      'Send funds to bank, mobile wallet, PayPal, and crypto destinations.';

  @override
  String sendMoneyCurrencyPill(String currency) {
    return 'Currency: $currency';
  }

  @override
  String sendMoneySenderWalletReady(String sender) {
    return 'Sender: $sender • Operating wallet ready';
  }

  @override
  String sendMoneySenderWalletMissing(String sender) {
    return 'Sender: $sender • Operating wallet missing';
  }

  @override
  String get sendMoneySectionRecipientTitle => '1. Recipient';

  @override
  String get sendMoneySectionRecipientSubtitle =>
      'Search by Orbi ID, email, or phone';

  @override
  String get sendMoneyRecipientFieldLabel => 'Recipient ID or phone';

  @override
  String get sendMoneyRecipientFieldHint => 'OB26-1234-5678 or +2557XXXXXXX';

  @override
  String get sendMoneyRecipientRequiredMessage =>
      'Enter recipient ID or phone number';

  @override
  String get sendMoneySectionSourceWalletTitle => '2. Source Wallet';

  @override
  String get sendMoneySectionSourceWalletSubtitle =>
      'Select Goal/Budget if you want sub-wallet funded transfer';

  @override
  String get sendMoneySectionAmountNoteTitle => '3. Amount & Note';

  @override
  String get sendMoneySectionAmountNoteSubtitle =>
      'Set transfer value and optional description';

  @override
  String get sendMoneyAmountLabel => 'Amount';

  @override
  String get sendMoneyDescriptionOptionalLabel => 'Description (optional)';

  @override
  String get sendMoneyDescriptionHint => 'Transfer reason';

  @override
  String get sendMoneyPreparingPreviewLabel => 'Preparing preview...';

  @override
  String get sendMoneyContinueTransferLabel => 'Continue Transfer';

  @override
  String get sendMoneyNoGoalWalletsMessage =>
      'No goal or budget source wallet is available right now. This transfer will use your Operating Wallet automatically.';

  @override
  String get sendMoneyOperatingWalletAutoTitle => 'Operating Wallet (Auto)';

  @override
  String get sendMoneyOperatingWalletAutoSubtitle =>
      'Default source when no sub-wallet is selected';

  @override
  String get sendMoneyDefaultBadge => 'DEFAULT';

  @override
  String get sendMoneySourceBadgeOperating => 'OPERATING';

  @override
  String get sendMoneySourceBadgeGoal => 'GOAL';

  @override
  String get sendMoneySourceBadgeBudget => 'BUDGET';

  @override
  String get sendMoneySourceBadgeSavings => 'SAVINGS';

  @override
  String get sendMoneySourceBadgeSubWallet => 'SUB-WALLET';

  @override
  String get sendMoneyGoalSourceWarningTitle => 'Goal funds are protected';

  @override
  String get sendMoneyGoalSourceWarningBody =>
      'You selected a goal-backed source wallet. Continue only if you intentionally want to spend or release money from that goal allocation.';

  @override
  String get sendMoneyGoalSourceContinueAction => 'Continue Anyway';

  @override
  String get sendMoneyGoalSourceInlineWarning =>
      'This source is goal-backed. Goal funds should only be used intentionally, not as ordinary spending money.';

  @override
  String sendMoneyWalletIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get sendMoneyExternalSectionRailProviderTitle => '1. Rail & Provider';

  @override
  String get sendMoneyExternalSectionRailProviderSubtitle =>
      'Choose payout channel';

  @override
  String get sendMoneyProviderCodeLabel => 'Provider Code';

  @override
  String get sendMoneyProviderCodeHint => 'Example: NMB, MPESA, PAYPAL';

  @override
  String get sendMoneyProviderCodeRequiredMessage => 'Enter provider code';

  @override
  String get sendMoneyExternalSectionDestinationTitle => '2. Destination';

  @override
  String get sendMoneyExternalSectionDestinationSubtitle =>
      'Where the money is going';

  @override
  String get sendMoneyCardNumberLabel => 'Card Number';

  @override
  String get sendMoneyAccountAddressLabel => 'Account / Address';

  @override
  String get sendMoneyCardNumberHint => 'Enter card number';

  @override
  String get sendMoneyDestinationAccountHint => 'Enter destination account';

  @override
  String get sendMoneyCardNumberRequiredMessage => 'Enter card number';

  @override
  String get sendMoneyAccountAddressRequiredMessage =>
      'Enter account or address';

  @override
  String get sendMoneyRecipientReferenceLabel => 'Recipient Reference';

  @override
  String get sendMoneyRecipientReferenceHint => 'Target destination reference';

  @override
  String get sendMoneyRecipientReferenceRequiredMessage =>
      'Enter recipient reference';

  @override
  String get sendMoneyExternalSectionFundingTitle => '3. Funding Source';

  @override
  String get sendMoneyExternalSectionFundingSubtitle =>
      'Pick source type and wallet';

  @override
  String get sendMoneySourceWalletLabel => 'Source Wallet';

  @override
  String get sendMoneySourceWalletHint =>
      'Internal, External Mobile, External Bank';

  @override
  String get sendMoneyBackendSourceWalletLabel => 'Backend Source Wallet';

  @override
  String get sendMoneyLoadingWalletsHint => 'Loading wallets...';

  @override
  String get sendMoneySelectLoadedWalletHint => 'Select loaded wallet';

  @override
  String get sendMoneySelectSourceWalletRequiredMessage =>
      'Select a source wallet from backend list';

  @override
  String get sendMoneyExternalSectionAmountNoteTitle => '4. Amount & Note';

  @override
  String get sendMoneyBudgetCategoryLabel => 'Budget category';

  @override
  String get sendMoneyBudgetCategoryHint => 'Optional spending category';

  @override
  String get sendMoneyBudgetCategoryOptionalHelper =>
      'Tag this transfer to a budget category for tracking and alerts.';

  @override
  String get sendMoneyBudgetCategoryNone => 'No budget category';

  @override
  String get sendMoneyNoBudgetCategoriesMessage =>
      'No budget categories available yet. Create one in Goals & Budget to tag transfers.';

  @override
  String get sendMoneyBudgetCategoriesLoadFailedMessage =>
      'Unable to load budget categories right now.';

  @override
  String sendMoneyBudgetSummaryTitle(String name) {
    return 'Budget: $name';
  }

  @override
  String sendMoneyBudgetSummaryBody(
    String budget,
    String spent,
    String remaining,
  ) {
    return 'Limit $budget • Spent $spent • Remaining $remaining';
  }

  @override
  String sendMoneyBudgetHardLimitLabel(String period) {
    return 'Hard limit • $period';
  }

  @override
  String sendMoneyBudgetSoftLimitLabel(String period) {
    return 'Soft limit • $period';
  }

  @override
  String sendMoneyBudgetHardLimitMessage(String name, String remaining) {
    return '$name is under a hard limit. Only $remaining remains, so this transfer cannot continue.';
  }

  @override
  String get sendMoneyBudgetSoftLimitTitle => 'Budget warning';

  @override
  String sendMoneyBudgetSoftLimitBody(String name, String remaining) {
    return '$name may be exceeded. Only $remaining remains in this budget. Continue and rely on fallback funding if backend policy allows?';
  }

  @override
  String get sendMoneyBudgetSoftLimitContinue => 'Continue With Warning';

  @override
  String get sendMoneyContinueExternalTransferLabel =>
      'Continue External Transfer';

  @override
  String get sendMoneyModeInternalTitle => 'Internal P2P';

  @override
  String get sendMoneyModeInternalSubtitle => 'Orbi user to user';

  @override
  String get sendMoneyModeExternalTitle => 'External';

  @override
  String get sendMoneyModeExternalSubtitle => 'Bank, Mobile, PayPal, Crypto';

  @override
  String get sendMoneyRailBank => 'Bank';

  @override
  String get sendMoneyRailMobileWallet => 'Mobile Wallet';

  @override
  String get sendMoneyRailPaypal => 'PayPal';

  @override
  String get sendMoneyRailCrypto => 'Crypto';

  @override
  String get sendMoneySourceTypeInternal => 'Internal';

  @override
  String get sendMoneySourceTypeExternalMobileWallet =>
      'External Mobile Wallet';

  @override
  String get sendMoneySourceTypeExternalBank => 'External Bank';

  @override
  String get sendMoneyRecipientIdLabel => 'Recipient ID';

  @override
  String get sendMoneyFullNameLabel => 'Full Name';

  @override
  String get sendMoneyVerifiedLabel => 'Verified';

  @override
  String get sendMoneyNotVerifiedLabel => 'Not verified';

  @override
  String get sendMoneyRecipientFallback => 'Recipient';

  @override
  String get sendMoneyPreviewServiceFeeLabel => 'Service fee';

  @override
  String get sendMoneyPreviewTotalToPayLabel => 'Total to pay';

  @override
  String get sendMoneyPreviewExchangeRateLabel => 'Exchange rate';

  @override
  String get sendMoneyPreviewFxFeeLabel => 'FX fee';

  @override
  String get sendMoneyPreviewRecipientGetsLabel => 'Recipient gets';

  @override
  String get sendMoneyPreviewAvailableBalanceLabel => 'Available balance';

  @override
  String sendMoneyInsufficientBalanceMessage(String amount) {
    return 'Insufficient balance. Short by $amount.';
  }

  @override
  String sendMoneySecurityCheckStatus(String status) {
    return 'Security check: $status';
  }

  @override
  String get otpCodeSentLabel => 'Code sent to your phone';

  @override
  String get pinConfirmLabel => 'Confirm PIN';

  @override
  String get pinCurrentLabel => 'Current PIN';

  @override
  String get pinNewLabel => 'New PIN';

  @override
  String get pinConfirmNewLabel => 'Confirm New PIN';

  @override
  String get passwordNewLabel => 'New password';

  @override
  String get passwordConfirmLabel => 'Confirm password';

  @override
  String get settingsBiometricEnabledMessage => 'Biometric sign-in enabled';

  @override
  String get settingsBiometricEnableFailedMessage =>
      'Unable to enable biometric sign-in';

  @override
  String get settingsPinRequiredForBiometricMessage =>
      'PIN setup is required to use biometric sign-in. Biometric sign-in disabled.';

  @override
  String get settingsProfileUpdatedMessage => 'Profile updated successfully';

  @override
  String get settingsProfileUpdateFailedMessage => 'Failed to update profile';

  @override
  String get settingsPasswordUpdatedMessage => 'Password updated successfully.';

  @override
  String get settingsPasswordUpdateFailedMessage =>
      'Failed to update password.';

  @override
  String get settingsProfilePhotoUpdatedMessage => 'Profile photo updated';

  @override
  String get settingsProfilePhotoFailedMessage => 'Failed to upload photo';

  @override
  String get sessionExpiredLoginMessage =>
      'Session expired. Please log in again.';

  @override
  String get otpEnterCodeLabel => 'Enter OTP code';

  @override
  String otpAttemptHelper(String helperText, int attempt) {
    return '$helperText\nAttempt $attempt';
  }

  @override
  String enterpriseOperatingVaultThreshold(String currency) {
    return 'Operating vault threshold ($currency)';
  }

  @override
  String get requestMoneyFromLabel => 'Request From';

  @override
  String get requestMoneyAmountLabel => 'Amount';

  @override
  String get requestMoneyReasonLabel => 'Reason (optional)';

  @override
  String get requestMoneyFromHint => 'Phone, email, or username';

  @override
  String get requestMoneyAmountHint => '0.00';

  @override
  String get requestMoneyReasonHint => 'What is this request for?';

  @override
  String get settingsKycRegisteredFullNameLabel => 'Registered Full Name';

  @override
  String get settingsKycIdTypeLabel => 'ID Type';

  @override
  String get settingsKycIdNumberLabel => 'ID Number';

  @override
  String get requestMoneyIntro =>
      'Create a payment request and share it with another user.';

  @override
  String get requestMoneyValidatorFrom => 'Enter who to request from';

  @override
  String get requestMoneyValidatorAmount => 'Enter a valid amount';

  @override
  String get settingsKycSubmitFailedMessage =>
      'Failed to submit KYC information';

  @override
  String get sendMoneyVerificationCancelledMessage =>
      'Transaction verification was cancelled. Please try again.';

  @override
  String get otpInvalidCodeMessage => 'Invalid code. Please try again.';

  @override
  String get settingsProfileNameMissingMessage =>
      'Profile name missing. Update profile first.';

  @override
  String get settingsUploadIdHoldingMessage =>
      'Upload a screenshot/photo while holding your ID';

  @override
  String get settingsScanNameMismatchMessage =>
      'Scan name differs from profile name. Keep names matching your registered profile.';

  @override
  String get settingsScanSuccessMessage => 'ID data extracted successfully.';

  @override
  String get settingsScanDobLabel => 'DOB';

  @override
  String get settingsScanExpiryLabel => 'Expiry';

  @override
  String get settingsServicePreferencesUpdatedMessage =>
      'Service preferences updated';

  @override
  String get settingsServicePreferencesUpdateFailedMessage =>
      'Failed to update preferences';

  @override
  String get settingsAllPreferencesUpdatedMessage =>
      'All preferences updated successfully';

  @override
  String get settingsAppLanguageUpdatedServiceFailedMessage =>
      'App language updated, but service preferences failed';

  @override
  String get settingsServiceUpdatedAppFailedMessage =>
      'Service preferences updated, but app language failed';

  @override
  String get settingsAllPreferencesUpdateFailedMessage =>
      'Failed to update any preferences';

  @override
  String get settingsAppLanguageUpdateFailedMessage =>
      'Failed to update app language';

  @override
  String get settingsNoPreferencesSelectedMessage =>
      'No preferences selected to apply';

  @override
  String get settingsSecurityVerificationHelper =>
      'Enter the OTP sent to your registered contact to approve this security action.';

  @override
  String get settingsKycVerificationRequiredTitle =>
      'KYC Verification Required';

  @override
  String get settingsKycVerificationRequiredMessage =>
      'Update your KYC information for more access, unlimited transaction limits, and more features from ORBI.';

  @override
  String get settingsKycUploadRequirementTitle => 'KYC upload requirement';

  @override
  String get settingsKycUploadRequirementMessage =>
      '• Upload a clear screenshot/photo while holding your ID\n• Your face and ID details must be readable\n• Use good lighting and avoid blur or cropped edges';

  @override
  String get settingsIdTypeNationalId => 'National ID';

  @override
  String get settingsIdTypePassport => 'Passport';

  @override
  String get settingsIdTypeDrivingLicense => 'Driving License';

  @override
  String get settingsIdTypeVoterId => 'Voter ID';

  @override
  String get settingsScanCouldNotExtractMessage =>
      'Could not extract data. Use a clear, well-lit ID image.';

  @override
  String get settingsKycRegisteredNameHelper =>
      'Name below is auto-filled from your registered profile and must match your ID.';

  @override
  String get settingsFaceAndIdReadableMessage =>
      'Ensure your face and ID text are clearly readable.';

  @override
  String get settingsAutoScanHelperMessage =>
      'Auto-scan uses multimodal AI to extract full name, ID number, document type, DOB, and expiry date. Run scan after each new upload.';

  @override
  String get settingsScanningIdLabel => 'Scanning ID...';

  @override
  String get settingsAutoFillFromIdScanLabel => 'Auto-fill from ID scan';

  @override
  String get settingsAutoScanVerifyFailedMessage =>
      'Auto-scan could not verify this document. Try a clearer image.';

  @override
  String get settingsSubmitDisabledUntilScanMessage =>
      'Submit is disabled until auto-scan returns a response.';

  @override
  String get settingsSubmitKycLabel => 'Submit KYC';

  @override
  String get settingsUserFallback => 'User';

  @override
  String get settingsNoEmailFallback => 'No email';

  @override
  String get settingsUserInitialFallback => 'U';

  @override
  String settingsCustomerIdLabel(String customerId) {
    return 'Customer ID: $customerId';
  }

  @override
  String settingsKycStatusLabel(String status) {
    return 'KYC: $status';
  }

  @override
  String get settingsVerifyNowMessage => 'Verify now to unlock full access';

  @override
  String get settingsAccountInformationTitle => 'Account Information';

  @override
  String get settingsAccountInformationSubtitle =>
      'Keep your profile details polished and up to date.';

  @override
  String get settingsFullNameLabel => 'Full Name';

  @override
  String get settingsPhoneLabel => 'Phone';

  @override
  String get settingsAddressLabel => 'Address';

  @override
  String get settingsCurrencyLabel => 'Currency';

  @override
  String get settingsSavingLabel => 'Saving...';

  @override
  String get settingsSaveProfileLabel => 'Save Profile';

  @override
  String get settingsSecurityTitle => 'Security';

  @override
  String get settingsSecuritySubtitle =>
      'Strengthen sign-in and protect sensitive account access.';

  @override
  String get settingsUseBiometricsTitle => 'Use biometric sign-in';

  @override
  String get settingsUseBiometricsSubtitle =>
      'Use your device biometrics for faster, secure sign-in.';

  @override
  String get settingsEnableDeviceBiometricsSubtitle =>
      'Add biometrics in your device settings to enable this option.';

  @override
  String get settingsBiometricUnavailableTitle =>
      'Biometric not available on this device';

  @override
  String get settingsBiometricUnavailableSubtitle =>
      'You can still secure your account with password and OTP.';

  @override
  String get settingsChangePinSubtitle =>
      'Update the fallback PIN used for biometric sign-in';

  @override
  String get settingsChangePasswordSubtitle => 'Update your account password';

  @override
  String get settingsDeviceNotificationsTitle => 'Device Notifications';

  @override
  String get settingsDeviceNotificationsSubtitle =>
      'Control local notification channels on this device.';

  @override
  String get settingsPushNotificationsTitle => 'Push Notifications';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Instant alerts for activity and security events.';

  @override
  String get settingsEmailAlertsTitle => 'Email Alerts';

  @override
  String get settingsEmailAlertsSubtitle =>
      'Receive summaries and important messages by email.';

  @override
  String get settingsMarketingUpdatesSubtitle =>
      'Occasional tips, launches, and offers from Orbi.';

  @override
  String get settingsHelpSupportTitle => 'Help & Support';

  @override
  String get settingsHelpSupportSubtitle => 'Contact the ORBI support team';

  @override
  String get settingsAboutTitle => 'About ORBI';

  @override
  String get settingsAboutVersionSubtitle => 'Version 1.0.0+1';

  @override
  String get chatSessionUnavailableMessage =>
      'Secure chat is unavailable for this session. Please log in again.';

  @override
  String get chatConnectionFailedMessage =>
      'Unable to reach Orbi AI. Check your connection and retry.';

  @override
  String get chatUnavailableMessage =>
      'Orbi AI is temporarily unavailable. Please try again.';

  @override
  String get chatOpenSemantics => 'Open secure chat';

  @override
  String get chatCloseSemantics => 'Close secure chat';

  @override
  String get chatTitle => 'ORBI AI';

  @override
  String get chatSubtitle => 'Secure messaging assistant';

  @override
  String get chatResetTooltip => 'Reset chat';

  @override
  String get chatEncryptedLabel => 'Encrypted';

  @override
  String get chatPrivateSessionLabel => 'Private session';

  @override
  String get chatUnavailableTitle => 'Chat unavailable';

  @override
  String get chatReadyTitle => 'Secure chat ready';

  @override
  String get chatReadyMessage =>
      'Ask about transfers, balances, transaction support, or account guidance.';

  @override
  String get chatTypingLabel => 'ORBI AI is typing...';

  @override
  String get chatComposerCompactHint => 'Message ORBI AI';

  @override
  String get chatComposerHint =>
      'Message about balances, transfers, or account help';

  @override
  String get enterpriseOrganizationTitle => 'Organization';

  @override
  String get enterpriseNoOrganizationTitle => 'No organization linked.';

  @override
  String get enterpriseNoOrganizationMessage =>
      'Your account is not attached to an enterprise tenant.';

  @override
  String get enterpriseBudgetAlertsTitle => 'Budget Alerts';

  @override
  String get enterpriseTreasuryGoalsTitle => 'Treasury Goals';

  @override
  String get enterprisePendingApprovalsTitle => 'Pending Approvals';

  @override
  String get enterpriseLoadingTitle => 'Loading...';

  @override
  String get enterpriseFetchingOrganizationMessage =>
      'Fetching organization details.';

  @override
  String get enterpriseOrganizationFallback => 'Organization';

  @override
  String enterpriseRoleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String enterpriseBaseCurrencyLabel(String currency) {
    return 'Base currency: $currency';
  }

  @override
  String get enterpriseNoTreasuryGoalsTitle => 'No treasury goals';

  @override
  String get enterpriseNoTreasuryGoalsMessage =>
      'No corporate goals configured.';

  @override
  String get enterpriseTreasuryGoalFallback => 'Treasury Goal';

  @override
  String get moneyStateAvailable => 'Available';

  @override
  String get moneyStateBudgeted => 'Budgeted';

  @override
  String get moneyStateSaved => 'Saved';

  @override
  String get moneyStateLocked => 'Locked';

  @override
  String get moneyStateSpent => 'Spent';

  @override
  String get moneyStateAllocated => 'Allocated';

  @override
  String enterpriseAutoSweepEnabledStatus(String thresholdPart) {
    return 'Auto-sweep enabled$thresholdPart';
  }

  @override
  String enterpriseThresholdSuffix(String threshold) {
    return ' • Threshold $threshold';
  }

  @override
  String get enterpriseAutoSweepDisabledStatus => 'Auto-sweep disabled';

  @override
  String get enterpriseAutoSweepConfigurationTitle =>
      'Auto-sweep configuration';

  @override
  String get enterpriseAllClearTitle => 'All clear';

  @override
  String get enterpriseNoBudgetAlertsMessage => 'No budget alerts right now.';

  @override
  String get enterpriseBudgetAlertFallback => 'Budget alert';

  @override
  String get enterpriseBudgetAlertUpper => 'BUDGET ALERT';

  @override
  String get enterpriseNoApprovalsTitle => 'No approvals';

  @override
  String get enterpriseNothingPendingMessage => 'Nothing pending right now.';

  @override
  String get enterpriseTreasuryApprovalFallback => 'Treasury approval';

  @override
  String enterpriseIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get wealthSharedPotsLoadError => 'Unable to load shared pots.';

  @override
  String get wealthNewSharedPot => 'New shared pot';

  @override
  String get wealthSharedGoalShort =>
      'Keep money together for one shared goal.';

  @override
  String get wealthPotName => 'Pot name';

  @override
  String get wealthPotNameHint => 'Example School fees';

  @override
  String get wealthPurpose => 'Purpose';

  @override
  String get wealthPurposeHint => 'Family, team, business';

  @override
  String get wealthTargetAmount => 'Target amount';

  @override
  String get wealthAccessModel => 'Access model';

  @override
  String get wealthEnterPotNameFirst => 'Enter the pot name first.';

  @override
  String get wealthCreateSharedPotError => 'Unable to create the shared pot.';

  @override
  String get wealthSaving => 'Saving...';

  @override
  String get wealthSavePot => 'Save pot';

  @override
  String get wealthSharedPotCreated => 'Shared pot created.';

  @override
  String get wealthEditSharedPot => 'Edit shared pot';

  @override
  String get wealthUpdateSharedPotError => 'Unable to update the shared pot.';

  @override
  String get wealthSaveChanges => 'Save changes';

  @override
  String get wealthSharedPotUpdated => 'Shared pot updated.';

  @override
  String get wealthContributeToSharedPot => 'Contribute to shared pot';

  @override
  String get wealthContributeToPotHelp =>
      'Add money from your wallet into this pot.';

  @override
  String get wealthAmount => 'Amount';

  @override
  String get wealthEnterAmountFirst => 'Enter the amount first.';

  @override
  String get wealthContributeError => 'Unable to add the contribution.';

  @override
  String get wealthContributeNow => 'Contribute now';

  @override
  String get wealthContributionAdded => 'Contribution added.';

  @override
  String get wealthWithdrawFromSharedPot => 'Withdraw from shared pot';

  @override
  String get wealthWithdrawFromPotHelp =>
      'Move money from this pot back to your wallet.';

  @override
  String get wealthWithdrawError => 'Unable to withdraw from the shared pot.';

  @override
  String get wealthWithdrawNow => 'Withdraw now';

  @override
  String get wealthFundsWithdrawn => 'Funds withdrawn.';

  @override
  String get wealthInviteMember => 'Invite member';

  @override
  String get wealthInviteMemberHelp =>
      'Send an invitation using the member\'s ORBI phone number or email.';

  @override
  String get wealthPhoneOrEmail => 'Phone or email';

  @override
  String get wealthRole => 'Role';

  @override
  String get wealthEnterPhoneOrEmailFirst => 'Enter phone or email first.';

  @override
  String get wealthInviteError => 'Unable to send the invitation.';

  @override
  String get wealthSendInvite => 'Send invite';

  @override
  String get wealthInviteSent => 'Invitation sent.';

  @override
  String get wealthLoadingMembers => 'Loading members...';

  @override
  String get wealthPotMembers => 'Pot members';

  @override
  String get wealthPotMembersHelp => 'Everyone with access to this pot.';

  @override
  String get wealthNoMembersYet => 'No members yet';

  @override
  String get wealthSendFirstInvite => 'Send the first invitation for this pot.';

  @override
  String get wealthUpdatingStatus => 'Updating status...';

  @override
  String get wealthPotStatusUpdated => 'Pot status updated.';

  @override
  String get wealthSharedPotsTitle => 'Shared Pots';

  @override
  String get wealthNewPot => 'New pot';

  @override
  String get wealthSharedMoneyOrganized => 'Shared money, clearly organised';

  @override
  String get wealthSharedMoneyHelp =>
      'Keep money together for one shared goal. Example: family, school fees, or a business team.';

  @override
  String get wealthSharedPotsLoadTitle => 'Shared pots could not be loaded';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get wealthNoSharedPotYet => 'No shared pot yet';

  @override
  String get wealthNoSharedPotMessage =>
      'Start a pot for family, school fees, or your business team.';

  @override
  String get wealthCreatePot => 'Create pot';

  @override
  String get wealthContribute => 'Contribute';

  @override
  String get wealthMembers => 'Members';

  @override
  String get wealthWithdraw => 'Withdraw';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonActivate => 'Activate';

  @override
  String get commonArchive => 'Archive';

  @override
  String wealthContributedLabel(String value) {
    return 'Contributed $value';
  }

  @override
  String wealthContributedTargetLabel(String contributed, String target) {
    return 'Contributed $contributed / Target $target';
  }

  @override
  String wealthTargetChip(String value) {
    return 'Target $value';
  }
}
