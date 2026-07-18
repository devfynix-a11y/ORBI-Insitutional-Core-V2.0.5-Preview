import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for the app interface.'**
  String get languageSubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure how you receive alerts and updates.'**
  String get notificationsSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default language for app and services'**
  String get languageEnglishSubtitle;

  /// No description provided for @languageSwahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get languageSwahili;

  /// No description provided for @languageSwahiliSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lugha ya Kiswahili kwa Orbi'**
  String get languageSwahiliSubtitle;

  /// No description provided for @applyToAppLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to app language'**
  String get applyToAppLanguageTitle;

  /// No description provided for @applyToAppLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch the app UI language.'**
  String get applyToAppLanguageSubtitle;

  /// No description provided for @applyToServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to services'**
  String get applyToServicesTitle;

  /// No description provided for @applyToServicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this language for notifications and messaging.'**
  String get applyToServicesSubtitle;

  /// No description provided for @serviceNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Service notifications'**
  String get serviceNotificationsTitle;

  /// No description provided for @securityAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Security alerts'**
  String get securityAlertsTitle;

  /// No description provided for @securityAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login attempts, new devices, and safety checks.'**
  String get securityAlertsSubtitle;

  /// No description provided for @financialAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial alerts'**
  String get financialAlertsTitle;

  /// No description provided for @financialAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions, payments, and transfers.'**
  String get financialAlertsSubtitle;

  /// No description provided for @budgetAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlertsTitle;

  /// No description provided for @budgetAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spending limits and budget updates.'**
  String get budgetAlertsSubtitle;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals & Budget'**
  String get goalsTitle;

  /// No description provided for @goalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create savings targets, move money into them, and keep everyday spending limits organized.'**
  String get goalsSubtitle;

  /// No description provided for @goalsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get goalsRefresh;

  /// No description provided for @goalsNewGoal.
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get goalsNewGoal;

  /// No description provided for @goalsNewBudget.
  ///
  /// In en, this message translates to:
  /// **'New Budget'**
  String get goalsNewBudget;

  /// No description provided for @goalsNewTask.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get goalsNewTask;

  /// No description provided for @goalsPlanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Consumer planning'**
  String get goalsPlanningTitle;

  /// No description provided for @goalsMetricGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsMetricGoals;

  /// No description provided for @goalsMetricSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get goalsMetricSaved;

  /// No description provided for @goalsMetricTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalsMetricTarget;

  /// No description provided for @goalsMetricBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get goalsMetricBudgets;

  /// No description provided for @goalsTabGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTabGoals;

  /// No description provided for @goalsTabBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get goalsTabBudget;

  /// No description provided for @goalsTabTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get goalsTabTasks;

  /// No description provided for @goalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get goalsEmptyTitle;

  /// No description provided for @goalsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first goal and start moving wallet funds into it.'**
  String get goalsEmptyMessage;

  /// No description provided for @goalsBudgetEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get goalsBudgetEmptyTitle;

  /// No description provided for @goalsBudgetEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create budget categories for groceries, transport, rent, and more.'**
  String get goalsBudgetEmptyMessage;

  /// No description provided for @goalsTasksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get goalsTasksEmptyTitle;

  /// No description provided for @goalsTasksEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add planning tasks to track the actions that move your goals forward.'**
  String get goalsTasksEmptyMessage;

  /// No description provided for @goalsDefaultGoalName.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get goalsDefaultGoalName;

  /// No description provided for @goalsDefaultBudgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget category'**
  String get goalsDefaultBudgetName;

  /// No description provided for @goalsTaskFallback.
  ///
  /// In en, this message translates to:
  /// **'Planning task'**
  String get goalsTaskFallback;

  /// No description provided for @goalsDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get goalsDeadlineLabel;

  /// No description provided for @goalsAllocateButton.
  ///
  /// In en, this message translates to:
  /// **'Allocate'**
  String get goalsAllocateButton;

  /// No description provided for @goalsWithdrawButton.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get goalsWithdrawButton;

  /// No description provided for @goalsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get goalsDeleteButton;

  /// No description provided for @goalsEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get goalsEditButton;

  /// No description provided for @goalsBudgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Budget limit: {amount}'**
  String goalsBudgetLimit(String amount);

  /// No description provided for @goalsHardLimit.
  ///
  /// In en, this message translates to:
  /// **'Hard limit'**
  String get goalsHardLimit;

  /// No description provided for @goalsSoftLimit.
  ///
  /// In en, this message translates to:
  /// **'Soft limit'**
  String get goalsSoftLimit;

  /// No description provided for @goalsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load goals and budgets'**
  String get goalsLoadFailedTitle;

  /// No description provided for @goalsCreateGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get goalsCreateGoalTitle;

  /// No description provided for @goalsEditGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalsEditGoalTitle;

  /// No description provided for @goalsGoalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalsGoalNameLabel;

  /// No description provided for @goalsTargetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get goalsTargetAmountLabel;

  /// No description provided for @goalsFundingStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Funding strategy'**
  String get goalsFundingStrategyLabel;

  /// No description provided for @goalsFundingManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get goalsFundingManual;

  /// No description provided for @goalsFundingPercentage.
  ///
  /// In en, this message translates to:
  /// **'Auto by income percentage'**
  String get goalsFundingPercentage;

  /// No description provided for @goalsFundingFixed.
  ///
  /// In en, this message translates to:
  /// **'Auto fixed monthly amount'**
  String get goalsFundingFixed;

  /// No description provided for @goalsAutoAllocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable auto allocation'**
  String get goalsAutoAllocationLabel;

  /// No description provided for @goalsAutoAllocationHint.
  ///
  /// In en, this message translates to:
  /// **'Let Orbi route part of future income into this goal automatically.'**
  String get goalsAutoAllocationHint;

  /// No description provided for @goalsIncomePercentageLabel.
  ///
  /// In en, this message translates to:
  /// **'Income percentage'**
  String get goalsIncomePercentageLabel;

  /// No description provided for @goalsIncomePercentageHint.
  ///
  /// In en, this message translates to:
  /// **'How much of incoming funds should be routed here.'**
  String get goalsIncomePercentageHint;

  /// No description provided for @goalsMonthlyTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly auto amount'**
  String get goalsMonthlyTargetLabel;

  /// No description provided for @goalsMonthlyTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount to move into this goal each month.'**
  String get goalsMonthlyTargetHint;

  /// No description provided for @goalsOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get goalsOptional;

  /// No description provided for @goalsGoalValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a goal name and valid target amount.'**
  String get goalsGoalValidationMessage;

  /// No description provided for @goalsIncomePercentageValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid income percentage for auto allocation.'**
  String get goalsIncomePercentageValidation;

  /// No description provided for @goalsMonthlyTargetValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid monthly amount for auto allocation.'**
  String get goalsMonthlyTargetValidation;

  /// No description provided for @goalsGoalCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Goal created.'**
  String get goalsGoalCreatedMessage;

  /// No description provided for @goalsGoalUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Goal updated.'**
  String get goalsGoalUpdatedMessage;

  /// No description provided for @goalsSaveGoalButton.
  ///
  /// In en, this message translates to:
  /// **'Save goal'**
  String get goalsSaveGoalButton;

  /// No description provided for @goalsUpdateGoalButton.
  ///
  /// In en, this message translates to:
  /// **'Update goal'**
  String get goalsUpdateGoalButton;

  /// No description provided for @goalsCreateBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create budget'**
  String get goalsCreateBudgetTitle;

  /// No description provided for @goalsEditBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get goalsEditBudgetTitle;

  /// No description provided for @goalsCreateTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get goalsCreateTaskTitle;

  /// No description provided for @goalsEditTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get goalsEditTaskTitle;

  /// No description provided for @goalsCategoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get goalsCategoryNameLabel;

  /// No description provided for @goalsBudgetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get goalsBudgetAmountLabel;

  /// No description provided for @goalsTaskTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get goalsTaskTextLabel;

  /// No description provided for @goalsTaskLinkedGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked goal'**
  String get goalsTaskLinkedGoalLabel;

  /// No description provided for @goalsTaskNoLinkedGoal.
  ///
  /// In en, this message translates to:
  /// **'No linked goal'**
  String get goalsTaskNoLinkedGoal;

  /// No description provided for @goalsTaskBountyLabel.
  ///
  /// In en, this message translates to:
  /// **'Bounty amount'**
  String get goalsTaskBountyLabel;

  /// No description provided for @goalsTaskDuePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get goalsTaskDuePickerLabel;

  /// No description provided for @goalsTaskCompletedToggle.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get goalsTaskCompletedToggle;

  /// No description provided for @goalsBudgetValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a category name and valid budget amount.'**
  String get goalsBudgetValidationMessage;

  /// No description provided for @goalsTaskValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a task before saving.'**
  String get goalsTaskValidationMessage;

  /// No description provided for @goalsBudgetCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Budget created.'**
  String get goalsBudgetCreatedMessage;

  /// No description provided for @goalsBudgetUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Budget updated.'**
  String get goalsBudgetUpdatedMessage;

  /// No description provided for @goalsTaskCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task created.'**
  String get goalsTaskCreatedMessage;

  /// No description provided for @goalsTaskUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task updated.'**
  String get goalsTaskUpdatedMessage;

  /// No description provided for @goalsSaveBudgetButton.
  ///
  /// In en, this message translates to:
  /// **'Save budget'**
  String get goalsSaveBudgetButton;

  /// No description provided for @goalsUpdateBudgetButton.
  ///
  /// In en, this message translates to:
  /// **'Update budget'**
  String get goalsUpdateBudgetButton;

  /// No description provided for @goalsSaveTaskButton.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get goalsSaveTaskButton;

  /// No description provided for @goalsUpdateTaskButton.
  ///
  /// In en, this message translates to:
  /// **'Update task'**
  String get goalsUpdateTaskButton;

  /// No description provided for @goalsAllocateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Allocate to {name}'**
  String goalsAllocateSheetTitle(String name);

  /// No description provided for @goalsAllocateFallbackName.
  ///
  /// In en, this message translates to:
  /// **'goal'**
  String get goalsAllocateFallbackName;

  /// No description provided for @goalsNoSourceWalletsMessage.
  ///
  /// In en, this message translates to:
  /// **'No wallet was found for this action on your account.'**
  String get goalsNoSourceWalletsMessage;

  /// No description provided for @goalsNoDestinationWalletsMessage.
  ///
  /// In en, this message translates to:
  /// **'No destination wallet was found for this action on your account.'**
  String get goalsNoDestinationWalletsMessage;

  /// No description provided for @goalsSourceWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Source wallet'**
  String get goalsSourceWalletLabel;

  /// No description provided for @goalsDestinationWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination wallet'**
  String get goalsDestinationWalletLabel;

  /// No description provided for @goalsAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get goalsAmountLabel;

  /// No description provided for @goalsAllocateValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a wallet and enter a valid amount.'**
  String get goalsAllocateValidationMessage;

  /// No description provided for @goalsAllocatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Funds allocated to goal.'**
  String get goalsAllocatedMessage;

  /// No description provided for @goalsAllocateFundsButton.
  ///
  /// In en, this message translates to:
  /// **'Allocate funds'**
  String get goalsAllocateFundsButton;

  /// No description provided for @goalsWithdrawSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw from {name}'**
  String goalsWithdrawSheetTitle(String name);

  /// No description provided for @goalsWithdrawLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Goal funds are protected. Withdrawals should be explicit and intentional.'**
  String get goalsWithdrawLockedHint;

  /// No description provided for @goalsWithdrawValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a destination wallet and enter a valid amount.'**
  String get goalsWithdrawValidationMessage;

  /// No description provided for @goalsWithdrawnMessage.
  ///
  /// In en, this message translates to:
  /// **'Funds withdrawn from goal.'**
  String get goalsWithdrawnMessage;

  /// No description provided for @goalsWithdrawFundsButton.
  ///
  /// In en, this message translates to:
  /// **'Withdraw funds'**
  String get goalsWithdrawFundsButton;

  /// No description provided for @goalsDeleteGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get goalsDeleteGoalTitle;

  /// No description provided for @goalsDeleteGoalMessage.
  ///
  /// In en, this message translates to:
  /// **'This goal will be removed from your planner.'**
  String get goalsDeleteGoalMessage;

  /// No description provided for @goalsDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted.'**
  String get goalsDeletedMessage;

  /// No description provided for @goalsDeleteBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete budget'**
  String get goalsDeleteBudgetTitle;

  /// No description provided for @goalsDeleteBudgetMessage.
  ///
  /// In en, this message translates to:
  /// **'This budget category will be removed.'**
  String get goalsDeleteBudgetMessage;

  /// No description provided for @goalsBudgetDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted.'**
  String get goalsBudgetDeletedMessage;

  /// No description provided for @goalsDeleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get goalsDeleteTaskTitle;

  /// No description provided for @goalsDeleteTaskMessage.
  ///
  /// In en, this message translates to:
  /// **'This planning task will be removed.'**
  String get goalsDeleteTaskMessage;

  /// No description provided for @goalsTaskDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task deleted.'**
  String get goalsTaskDeletedMessage;

  /// No description provided for @goalsTaskCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task completed.'**
  String get goalsTaskCompletedMessage;

  /// No description provided for @goalsTaskReopenedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task reopened.'**
  String get goalsTaskReopenedMessage;

  /// No description provided for @goalsContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get goalsContinueAction;

  /// No description provided for @goalsFlexibleDate.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get goalsFlexibleDate;

  /// No description provided for @goalsTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goalsTaskCompleted;

  /// No description provided for @goalsTaskPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get goalsTaskPending;

  /// No description provided for @goalsTaskDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get goalsTaskDueLabel;

  /// No description provided for @goalsTaskLinkedGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal: {name}'**
  String goalsTaskLinkedGoal(String name);

  /// No description provided for @goalsTaskBounty.
  ///
  /// In en, this message translates to:
  /// **'Bounty: {amount}'**
  String goalsTaskBounty(String amount);

  /// No description provided for @marketingUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketing updates'**
  String get marketingUpdatesTitle;

  /// No description provided for @marketingUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Promotions, tips, and product announcements.'**
  String get marketingUpdatesSubtitle;

  /// No description provided for @applyToAppButton.
  ///
  /// In en, this message translates to:
  /// **'Apply to App'**
  String get applyToAppButton;

  /// No description provided for @applyToServicesButton.
  ///
  /// In en, this message translates to:
  /// **'Apply to Services'**
  String get applyToServicesButton;

  /// No description provided for @applyAllButton.
  ///
  /// In en, this message translates to:
  /// **'Apply All'**
  String get applyAllButton;

  /// No description provided for @applyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyButton;

  /// No description provided for @applyingButton.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get applyingButton;

  /// No description provided for @appLanguageSetMessage.
  ///
  /// In en, this message translates to:
  /// **'App language set to {language}.'**
  String appLanguageSetMessage(String language);

  /// No description provided for @appLanguageFollowSystemMessage.
  ///
  /// In en, this message translates to:
  /// **'App language will follow system settings.'**
  String get appLanguageFollowSystemMessage;

  /// No description provided for @appLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading ORBI'**
  String get appLoadingStatus;

  /// No description provided for @appLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Preparing your secure workspace and restoring your session.'**
  String get appLoadingDetail;

  /// No description provided for @preferencesLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading your preferences'**
  String get preferencesLoadingStatus;

  /// No description provided for @preferencesLoadingDetail.
  ///
  /// In en, this message translates to:
  /// **'Syncing language, appearance, and device preferences.'**
  String get preferencesLoadingDetail;

  /// No description provided for @inactivityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you still using ORBI?'**
  String get inactivityWarningTitle;

  /// No description provided for @inactivityWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Your app will lock soon due to inactivity.'**
  String get inactivityWarningMessage;

  /// No description provided for @inactivityWarningCountdown.
  ///
  /// In en, this message translates to:
  /// **'Locks in {seconds}s'**
  String inactivityWarningCountdown(int seconds);

  /// No description provided for @inactivityWarningStayButton.
  ///
  /// In en, this message translates to:
  /// **'I\'m still using ORBI'**
  String get inactivityWarningStayButton;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get actionVerify;

  /// No description provided for @actionLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get actionLogout;

  /// No description provided for @actionSetUpNow.
  ///
  /// In en, this message translates to:
  /// **'Set Up Now'**
  String get actionSetUpNow;

  /// No description provided for @actionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get actionUnlock;

  /// No description provided for @actionSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Link'**
  String get actionSendLink;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @actionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get actionUpdate;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get actionAddCard;

  /// No description provided for @actionPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get actionPrintReceipt;

  /// No description provided for @actionDownloadPrint.
  ///
  /// In en, this message translates to:
  /// **'Download / Print'**
  String get actionDownloadPrint;

  /// No description provided for @actionShareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share Receipt'**
  String get actionShareReceipt;

  /// No description provided for @actionCreateRequest.
  ///
  /// In en, this message translates to:
  /// **'Create Request'**
  String get actionCreateRequest;

  /// No description provided for @actionScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get actionScanAgain;

  /// No description provided for @actionFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From Gallery'**
  String get actionFromGallery;

  /// No description provided for @actionCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get actionCapture;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get actionLogin;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get labelPassword;

  /// No description provided for @loginEnterEmailPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter both email and password before logging in.'**
  String get loginEnterEmailPasswordMessage;

  /// No description provided for @loginInvalidPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN.'**
  String get loginInvalidPinMessage;

  /// No description provided for @loginEnterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get loginEnterPinTitle;

  /// No description provided for @loginPinLabel.
  ///
  /// In en, this message translates to:
  /// **'4-6 digit PIN'**
  String get loginPinLabel;

  /// No description provided for @loginEnterOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get loginEnterOtpTitle;

  /// No description provided for @loginOtpCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get loginOtpCodeLabel;

  /// No description provided for @loginBiometricSetupRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Setup Required'**
  String get loginBiometricSetupRequiredTitle;

  /// No description provided for @loginBiometricSetupRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'To continue, you must register your device biometric. This is required by your account security policy.'**
  String get loginBiometricSetupRequiredBody;

  /// No description provided for @loginBiometricSetupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Biometric setup failed. Please try again.'**
  String get loginBiometricSetupFailedMessage;

  /// No description provided for @loginResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get loginResetPasswordTitle;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'user@example.com'**
  String get loginEmailHint;

  /// No description provided for @loginResetLinkSentMessage.
  ///
  /// In en, this message translates to:
  /// **'If the account exists, a password reset email has been sent.'**
  String get loginResetLinkSentMessage;

  /// No description provided for @loginResetFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to initiate password reset.'**
  String get loginResetFailedMessage;

  /// No description provided for @loginOrbiLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI LOGIN'**
  String get loginOrbiLoginTitle;

  /// No description provided for @loginSecureDeviceAttached.
  ///
  /// In en, this message translates to:
  /// **'Secure device attached'**
  String get loginSecureDeviceAttached;

  /// No description provided for @loginAuthenticateWithBiometric.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with fingerprint or face'**
  String get loginAuthenticateWithBiometric;

  /// No description provided for @loginBiometricFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'If prompt does not open, use password login below.'**
  String get loginBiometricFallbackHint;

  /// No description provided for @loginSecurityVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Verification'**
  String get loginSecurityVerificationTitle;

  /// No description provided for @loginAuthenticatingSecurely.
  ///
  /// In en, this message translates to:
  /// **'Signing you in...'**
  String get loginAuthenticatingSecurely;

  /// No description provided for @loginAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loginAuthenticating;

  /// No description provided for @loginUsePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use Password Instead'**
  String get loginUsePasswordInstead;

  /// No description provided for @loginUsePinInstead.
  ///
  /// In en, this message translates to:
  /// **'Use PIN Instead'**
  String get loginUsePinInstead;

  /// No description provided for @loginOrbiTagline.
  ///
  /// In en, this message translates to:
  /// **'ORBI Financial Technologies'**
  String get loginOrbiTagline;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ORBI'**
  String get loginWelcomeTitle;

  /// No description provided for @appBarGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get appBarGreetingMorning;

  /// No description provided for @appBarGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get appBarGreetingAfternoon;

  /// No description provided for @appBarGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get appBarGreetingEvening;

  /// No description provided for @appBarCustomerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get appBarCustomerIdLabel;

  /// No description provided for @dashboardLinkedCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked Cards'**
  String get dashboardLinkedCardsTitle;

  /// No description provided for @dashboardLinkedCardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No linked cards yet'**
  String get dashboardLinkedCardsEmptyTitle;

  /// No description provided for @dashboardLinkedCardsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Link your wallet to manage your wealth.'**
  String get dashboardLinkedCardsEmptyMessage;

  /// No description provided for @loginSecureSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure sign in with password or biometrics.'**
  String get loginSecureSignInSubtitle;

  /// No description provided for @loginUseFingerprintButton.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint / Face ID'**
  String get loginUseFingerprintButton;

  /// No description provided for @loginOrUsePassword.
  ///
  /// In en, this message translates to:
  /// **'or use password'**
  String get loginOrUsePassword;

  /// No description provided for @loginBiometricTemporarilyLocked.
  ///
  /// In en, this message translates to:
  /// **'Biometric temporarily locked. Use password login.'**
  String get loginBiometricTemporarilyLocked;

  /// No description provided for @loginBiometricMissing.
  ///
  /// In en, this message translates to:
  /// **'Biometric registration not found. Please login with password once, then re-enable biometrics in Settings.'**
  String get loginBiometricMissing;

  /// No description provided for @loginUnlockWithPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock with PIN'**
  String get loginUnlockWithPin;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNewUserCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New user? Create an account'**
  String get loginNewUserCreateAccount;

  /// No description provided for @signupAcceptTermsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please accept terms to continue.'**
  String get signupAcceptTermsMessage;

  /// No description provided for @signupCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your ORBI account'**
  String get signupCreateAccountTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure signup connected to ORBI backend.'**
  String get signupSubtitle;

  /// No description provided for @signupStepPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get signupStepPersonalInfo;

  /// No description provided for @signupStepContactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact Details'**
  String get signupStepContactDetails;

  /// No description provided for @signupStepVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get signupStepVerification;

  /// No description provided for @signupStepShortInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get signupStepShortInfo;

  /// No description provided for @signupStepShortCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get signupStepShortCountry;

  /// No description provided for @signupStepShortVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get signupStepShortVerify;

  /// No description provided for @signupSecurityVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Verification'**
  String get signupSecurityVerificationTitle;

  /// No description provided for @signupSecurityVerificationHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to your registered contact to continue secure setup.'**
  String get signupSecurityVerificationHelper;

  /// No description provided for @signupSelectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get signupSelectLanguageTitle;

  /// No description provided for @signupAboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get signupAboutYouTitle;

  /// No description provided for @signupAboutYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a few personal details so we can personalize your ORBI experience from the start.'**
  String get signupAboutYouSubtitle;

  /// No description provided for @signupAddressHelper.
  ///
  /// In en, this message translates to:
  /// **'Add your address to help us tailor services and offers for you. (Optional)'**
  String get signupAddressHelper;

  /// No description provided for @signupChooseCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your country'**
  String get signupChooseCountryTitle;

  /// No description provided for @signupChooseCountrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your country so ORBI can match your language, currency, and financial experience more closely to your market.'**
  String get signupChooseCountrySubtitle;

  /// No description provided for @signupLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get signupLanguageLabel;

  /// No description provided for @signupCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get signupCurrencyLabel;

  /// No description provided for @signupPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter your local number only. Your country code is added automatically.'**
  String get signupPhoneHelper;

  /// No description provided for @signupNationalityHelper.
  ///
  /// In en, this message translates to:
  /// **'Auto-filled from your country, and you can adjust it if needed.'**
  String get signupNationalityHelper;

  /// No description provided for @signupSecureAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get signupSecureAccountTitle;

  /// No description provided for @signupSecureAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a strong password so your money, rewards, and business activity stay protected.'**
  String get signupSecureAccountSubtitle;

  /// No description provided for @secureAccountSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get secureAccountSetupTitle;

  /// No description provided for @secureAccountSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Signup was successful. Complete these two security steps before entering ORBI.'**
  String get secureAccountSetupSubtitle;

  /// No description provided for @secureAccountSetupRegisterFingerprintFirst.
  ///
  /// In en, this message translates to:
  /// **'Register fingerprint first, then set your PIN.'**
  String get secureAccountSetupRegisterFingerprintFirst;

  /// No description provided for @secureAccountSetupPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4 digit PIN and confirm it correctly.'**
  String get secureAccountSetupPinMismatch;

  /// No description provided for @secureAccountSetupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint and PIN are both secured.'**
  String get secureAccountSetupSuccess;

  /// No description provided for @secureAccountSetupPinEnrollFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to secure your PIN right now.'**
  String get secureAccountSetupPinEnrollFailed;

  /// No description provided for @secureAccountSetupBiometricReady.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint is registered. Now set your PIN to finish.'**
  String get secureAccountSetupBiometricReady;

  /// No description provided for @secureAccountSetupLoading.
  ///
  /// In en, this message translates to:
  /// **'Securing your account...'**
  String get secureAccountSetupLoading;

  /// No description provided for @secureAccountStepFingerprintTitle.
  ///
  /// In en, this message translates to:
  /// **'Register fingerprint'**
  String get secureAccountStepFingerprintTitle;

  /// No description provided for @secureAccountStepFingerprintMessage.
  ///
  /// In en, this message translates to:
  /// **'Biometric login gives you fast and secure account access.'**
  String get secureAccountStepFingerprintMessage;

  /// No description provided for @secureAccountStepPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get secureAccountStepPinTitle;

  /// No description provided for @secureAccountStepPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Your PIN protects money actions and gives you fast return access.'**
  String get secureAccountStepPinMessage;

  /// No description provided for @secureAccountSignOutInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign out instead'**
  String get secureAccountSignOutInstead;

  /// No description provided for @actionRegisterNow.
  ///
  /// In en, this message translates to:
  /// **'Register now'**
  String get actionRegisterNow;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get commonReady;

  /// No description provided for @signupAgreeTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'I agree to ORBI Terms & Conditions'**
  String get signupAgreeTermsTitle;

  /// No description provided for @signupAgreeTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'By joining ORBI, you unlock a safer way to receive salary, manage spending, access offers, and grow your financial life with confidence.'**
  String get signupAgreeTermsSubtitle;

  /// No description provided for @signupReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration review'**
  String get signupReviewTitle;

  /// No description provided for @signupReviewNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get signupReviewNameFallback;

  /// No description provided for @signupReviewEmailFallback.
  ///
  /// In en, this message translates to:
  /// **'Email pending'**
  String get signupReviewEmailFallback;

  /// No description provided for @signupEasyOnboardingBadge.
  ///
  /// In en, this message translates to:
  /// **'Easy onboarding'**
  String get signupEasyOnboardingBadge;

  /// No description provided for @signupPersonalizedBadge.
  ///
  /// In en, this message translates to:
  /// **'Built around you'**
  String get signupPersonalizedBadge;

  /// No description provided for @signupSafeSecureBadge.
  ///
  /// In en, this message translates to:
  /// **'Safe & secure'**
  String get signupSafeSecureBadge;

  /// No description provided for @signupHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open your ORBI account in a few simple steps and start managing money, payments, and opportunities with more confidence.'**
  String get signupHeroSubtitle;

  /// No description provided for @signupStepCounter.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} • {title}'**
  String signupStepCounter(String current, String total, String title);

  /// No description provided for @signupSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signupSignInButton;

  /// No description provided for @signupBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get signupBackButton;

  /// No description provided for @signupNextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get signupNextButton;

  /// No description provided for @signupSubmittingButton.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get signupSubmittingButton;

  /// No description provided for @labelFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get labelFullName;

  /// No description provided for @signupFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get signupFullNameRequired;

  /// No description provided for @signupFullNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name'**
  String get signupFullNameInvalid;

  /// No description provided for @labelCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get labelCountry;

  /// No description provided for @labelPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get labelPhoneNumber;

  /// No description provided for @signupPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone is required'**
  String get signupPhoneRequired;

  /// No description provided for @signupPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone'**
  String get signupPhoneInvalid;

  /// No description provided for @labelNationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get labelNationality;

  /// No description provided for @labelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelAddress;

  /// No description provided for @labelPreferredCurrency.
  ///
  /// In en, this message translates to:
  /// **'Preferred currency'**
  String get labelPreferredCurrency;

  /// No description provided for @labelEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get labelEmailAddress;

  /// No description provided for @signupEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get signupEmailRequired;

  /// No description provided for @signupEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get signupEmailInvalid;

  /// No description provided for @signupPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get signupPasswordRequired;

  /// No description provided for @signupPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get signupPasswordMin;

  /// No description provided for @labelConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get labelConfirmPassword;

  /// No description provided for @signupPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupPasswordsMismatch;

  /// No description provided for @signupAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to Terms and Privacy Policy'**
  String get signupAgreeTerms;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get actionCreateAccount;

  /// No description provided for @signupAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get signupAlreadyHaveAccount;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ORBI'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your first setup for a guided money experience.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'A smarter money experience designed to help you grow your wealth.'**
  String get onboardingHeroTitle;

  /// No description provided for @onboardingHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive salary, send money, pay bills, manage business spending, and enjoy trusted merchant experiences with more confidence, more control, and less pressure.'**
  String get onboardingHeroSubtitle;

  /// No description provided for @onboardingBadgeFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get onboardingBadgeFast;

  /// No description provided for @onboardingBadgeEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday value'**
  String get onboardingBadgeEveryday;

  /// No description provided for @onboardingBadgeSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get onboardingBadgeSecure;

  /// No description provided for @onboardingPromo1Badge.
  ///
  /// In en, this message translates to:
  /// **'Confidence first'**
  String get onboardingPromo1Badge;

  /// No description provided for @onboardingPromo1Title.
  ///
  /// In en, this message translates to:
  /// **'Enjoy peace of mind every time you move money'**
  String get onboardingPromo1Title;

  /// No description provided for @onboardingPromo1Body.
  ///
  /// In en, this message translates to:
  /// **'From transfers to bill payments, ORBI helps your money move smoothly and safely so you can focus on life, not financial stress.'**
  String get onboardingPromo1Body;

  /// No description provided for @onboardingPromo2Badge.
  ///
  /// In en, this message translates to:
  /// **'Salary power'**
  String get onboardingPromo2Badge;

  /// No description provided for @onboardingPromo2Title.
  ///
  /// In en, this message translates to:
  /// **'Make your salary feel more valuable from day one'**
  String get onboardingPromo2Title;

  /// No description provided for @onboardingPromo2Body.
  ///
  /// In en, this message translates to:
  /// **'Receive salary, support family, pay essentials, and plan ahead with more clarity, giving every payday a stronger sense of control and progress.'**
  String get onboardingPromo2Body;

  /// No description provided for @onboardingPromo3Badge.
  ///
  /// In en, this message translates to:
  /// **'Smarter lifestyle'**
  String get onboardingPromo3Badge;

  /// No description provided for @onboardingPromo3Title.
  ///
  /// In en, this message translates to:
  /// **'Spend with control, discover value, and avoid surprises'**
  String get onboardingPromo3Title;

  /// No description provided for @onboardingPromo3Body.
  ///
  /// In en, this message translates to:
  /// **'Stay on budget, shop with trusted merchants, and enjoy better offers through an experience designed to make everyday spending feel lighter and smarter.'**
  String get onboardingPromo3Body;

  /// No description provided for @onboardingPromo4Badge.
  ///
  /// In en, this message translates to:
  /// **'Business ready'**
  String get onboardingPromo4Badge;

  /// No description provided for @onboardingPromo4Title.
  ///
  /// In en, this message translates to:
  /// **'Built for ambitious people and growing businesses'**
  String get onboardingPromo4Title;

  /// No description provided for @onboardingPromo4Body.
  ///
  /// In en, this message translates to:
  /// **'Whether you manage personal money, team budgets, or merchant payments, ORBI gives you a more organized, secure, and professional way to grow.'**
  String get onboardingPromo4Body;

  /// No description provided for @onboardingTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms at a glance'**
  String get onboardingTermsTitle;

  /// No description provided for @onboardingTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Before registration, please review the basics that help keep your account, payments, and financial experience safe.'**
  String get onboardingTermsSubtitle;

  /// No description provided for @onboardingTermsHighlight1.
  ///
  /// In en, this message translates to:
  /// **'Use accurate identity, contact, and country details when creating your account.'**
  String get onboardingTermsHighlight1;

  /// No description provided for @onboardingTermsHighlight2.
  ///
  /// In en, this message translates to:
  /// **'Protect your password, OTP codes, and biometric access so no one can act on your behalf.'**
  String get onboardingTermsHighlight2;

  /// No description provided for @onboardingTermsHighlight3.
  ///
  /// In en, this message translates to:
  /// **'Some payments and account actions may require verification for your protection.'**
  String get onboardingTermsHighlight3;

  /// No description provided for @onboardingTermsHighlight4.
  ///
  /// In en, this message translates to:
  /// **'Certain features may need extra review before they are fully activated.'**
  String get onboardingTermsHighlight4;

  /// No description provided for @onboardingTermsConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will confirm these terms again before finishing your account registration.'**
  String get onboardingTermsConfirm;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get actionViewAll;

  /// No description provided for @profileMakePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Make Payment'**
  String get profileMakePaymentTitle;

  /// No description provided for @profileScanQrCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get profileScanQrCodeTitle;

  /// No description provided for @profileScanQrAction.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get profileScanQrAction;

  /// No description provided for @paymentFlashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash On'**
  String get paymentFlashOn;

  /// No description provided for @paymentFlashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash Off'**
  String get paymentFlashOff;

  /// No description provided for @paymentQrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point camera at a QR code to scan.'**
  String get paymentQrPrompt;

  /// No description provided for @paymentScannedValue.
  ///
  /// In en, this message translates to:
  /// **'Scanned value:\n{value}'**
  String paymentScannedValue(String value);

  /// No description provided for @paymentNoReceiptSelected.
  ///
  /// In en, this message translates to:
  /// **'No receipt or document selected.\nCapture or import below.'**
  String get paymentNoReceiptSelected;

  /// No description provided for @paymentSavedPath.
  ///
  /// In en, this message translates to:
  /// **'Saved path: {path}'**
  String paymentSavedPath(String path);

  /// No description provided for @paymentAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get paymentAnalyzing;

  /// No description provided for @paymentAnalyzeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Analyze Receipt'**
  String get paymentAnalyzeReceipt;

  /// No description provided for @paymentExtractedDetails.
  ///
  /// In en, this message translates to:
  /// **'Extracted Details'**
  String get paymentExtractedDetails;

  /// No description provided for @paymentMerchantLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get paymentMerchantLabel;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentAmountLabel;

  /// No description provided for @paymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get paymentDateLabel;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wealth'**
  String get walletTitle;

  /// No description provided for @shellSessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get shellSessionExpiredMessage;

  /// No description provided for @shellNoNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check internet and retry.'**
  String get shellNoNetworkMessage;

  /// No description provided for @shellStartupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load startup data. Please retry.'**
  String get shellStartupFailedMessage;

  /// No description provided for @shellStartupUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup data unavailable'**
  String get shellStartupUnavailableTitle;

  /// No description provided for @shellQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get shellQuickActionsTitle;

  /// No description provided for @shellQuickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jump into the most-used money actions.'**
  String get shellQuickActionsSubtitle;

  /// No description provided for @shellActionTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get shellActionTransfer;

  /// No description provided for @shellActionRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get shellActionRequest;

  /// No description provided for @shellActionScanPay.
  ///
  /// In en, this message translates to:
  /// **'Scan & Pay'**
  String get shellActionScanPay;

  /// No description provided for @shellActionAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get shellActionAlerts;

  /// No description provided for @shellNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellNavHome;

  /// No description provided for @shellNavTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get shellNavTransactions;

  /// No description provided for @shellNavGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get shellNavGoals;

  /// No description provided for @shellBootstrapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Secure Financial Platform'**
  String get shellBootstrapSubtitle;

  /// No description provided for @shellOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline or live updates are paused. Some data may be stale.'**
  String get shellOfflineBanner;

  /// No description provided for @shellPleaseWaitMoment.
  ///
  /// In en, this message translates to:
  /// **'Please, wait a moment...'**
  String get shellPleaseWaitMoment;

  /// No description provided for @walletFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} coming soon'**
  String walletFeatureComingSoon(String feature);

  /// No description provided for @walletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear view of your accounts, balances, and liquidity'**
  String get walletSubtitle;

  /// No description provided for @walletProvisioningPreparingAuto.
  ///
  /// In en, this message translates to:
  /// **'We are preparing your wealth accounts and card. Refreshing automatically... ({current}/{total})'**
  String walletProvisioningPreparingAuto(String current, String total);

  /// No description provided for @walletProvisioningPreparingManual.
  ///
  /// In en, this message translates to:
  /// **'We are still preparing your wealth accounts and card. Pull to refresh.'**
  String get walletProvisioningPreparingManual;

  /// No description provided for @walletTotalBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Total Wealth Balance'**
  String get walletTotalBalanceTitle;

  /// No description provided for @walletAccountsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} accounts'**
  String walletAccountsCount(String count);

  /// No description provided for @walletFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletFilterAll;

  /// No description provided for @walletFilterOrbi.
  ///
  /// In en, this message translates to:
  /// **'Orbi'**
  String get walletFilterOrbi;

  /// No description provided for @walletFilterLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get walletFilterLinked;

  /// No description provided for @walletShowBalances.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get walletShowBalances;

  /// No description provided for @walletHideBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get walletHideBalances;

  /// No description provided for @walletQuickTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletQuickTransfer;

  /// No description provided for @walletQuickTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletQuickTopUp;

  /// No description provided for @walletQuickLinkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Account'**
  String get walletQuickLinkAccount;

  /// No description provided for @walletQuickSendMoney.
  ///
  /// In en, this message translates to:
  /// **'Send money'**
  String get walletQuickSendMoney;

  /// No description provided for @walletQuickTopUpFlow.
  ///
  /// In en, this message translates to:
  /// **'Top up flow'**
  String get walletQuickTopUpFlow;

  /// No description provided for @walletQuickLinkAccountFlow.
  ///
  /// In en, this message translates to:
  /// **'Link account flow'**
  String get walletQuickLinkAccountFlow;

  /// No description provided for @walletIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String walletIdLabel(String id);

  /// No description provided for @walletTransactionsButton.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletTransactionsButton;

  /// No description provided for @walletFetchTransactionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch transactions for this account right now.'**
  String get walletFetchTransactionsFailed;

  /// No description provided for @walletTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'{wallet} Transactions'**
  String walletTransactionsTitle(String wallet);

  /// No description provided for @walletNoTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found for this account.'**
  String get walletNoTransactionsFound;

  /// No description provided for @walletTransactionRef.
  ///
  /// In en, this message translates to:
  /// **'Ref: {ref}'**
  String walletTransactionRef(String ref);

  /// No description provided for @walletFailedLoadAccounts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load wealth accounts'**
  String get walletFailedLoadAccounts;

  /// No description provided for @walletNoAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No wealth accounts available yet.'**
  String get walletNoAccountsYet;

  /// No description provided for @walletNoAccountsMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No accounts match this filter.'**
  String get walletNoAccountsMatchFilter;

  /// No description provided for @walletMainCardShownTop.
  ///
  /// In en, this message translates to:
  /// **'Your main account card is shown at the top.'**
  String get walletMainCardShownTop;

  /// No description provided for @walletLoadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading wealth accounts...'**
  String get walletLoadingAccounts;

  /// No description provided for @dashboardNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get dashboardNetWorth;

  /// No description provided for @dashboardLifecycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Money lifecycle'**
  String get dashboardLifecycleTitle;

  /// No description provided for @dashboardUnallocated.
  ///
  /// In en, this message translates to:
  /// **'Unallocated'**
  String get dashboardUnallocated;

  /// No description provided for @dashboardAllocated.
  ///
  /// In en, this message translates to:
  /// **'Allocated'**
  String get dashboardAllocated;

  /// No description provided for @dashboardSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get dashboardSecure;

  /// No description provided for @dashboardThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{value}% this month'**
  String dashboardThisMonth(String value);

  /// No description provided for @dashboardPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get dashboardPortfolio;

  /// No description provided for @dashboardLinkedWallets.
  ///
  /// In en, this message translates to:
  /// **'Linked Wallets'**
  String get dashboardLinkedWallets;

  /// No description provided for @dashboardOrbiWallet.
  ///
  /// In en, this message translates to:
  /// **'Orbi Wallet'**
  String get dashboardOrbiWallet;

  /// No description provided for @dashboardInternalAccounts.
  ///
  /// In en, this message translates to:
  /// **'Internal Accounts'**
  String get dashboardInternalAccounts;

  /// No description provided for @dashboardReadyToUse.
  ///
  /// In en, this message translates to:
  /// **'Ready to use'**
  String get dashboardReadyToUse;

  /// No description provided for @dashboardAnalyzingBehavior.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your financial behavior...'**
  String get dashboardAnalyzingBehavior;

  /// No description provided for @dashboardInsightWedge.
  ///
  /// In en, this message translates to:
  /// **'Insight Wedge'**
  String get dashboardInsightWedge;

  /// No description provided for @dashboardInsightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-generated alerts, suggestions, and advice for your finances.'**
  String get dashboardInsightsSubtitle;

  /// No description provided for @dashboardNoInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'No insights available yet'**
  String get dashboardNoInsightsTitle;

  /// No description provided for @dashboardNoInsightsMessage.
  ///
  /// In en, this message translates to:
  /// **'Insights will appear once your latest financial activity has been analyzed.'**
  String get dashboardNoInsightsMessage;

  /// No description provided for @dashboardSpendingAlerts.
  ///
  /// In en, this message translates to:
  /// **'Spending Alerts'**
  String get dashboardSpendingAlerts;

  /// No description provided for @dashboardBudgetSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Budget Suggestions'**
  String get dashboardBudgetSuggestions;

  /// No description provided for @dashboardFinancialAdvice.
  ///
  /// In en, this message translates to:
  /// **'Financial Advice'**
  String get dashboardFinancialAdvice;

  /// No description provided for @dashboardNoItemsNow.
  ///
  /// In en, this message translates to:
  /// **'No items available right now.'**
  String get dashboardNoItemsNow;

  /// No description provided for @settingsBiometricDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Biometric login disabled'**
  String get settingsBiometricDisabledMessage;

  /// No description provided for @settingsSetPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get settingsSetPinTitle;

  /// No description provided for @settingsPinsInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match or are invalid.'**
  String get settingsPinsInvalidMessage;

  /// No description provided for @settingsChangePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePinTitle;

  /// No description provided for @settingsCurrentPinIncorrectMessage.
  ///
  /// In en, this message translates to:
  /// **'Current PIN is incorrect.'**
  String get settingsCurrentPinIncorrectMessage;

  /// No description provided for @settingsNewPinInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'New PIN is invalid or does not match.'**
  String get settingsNewPinInvalidMessage;

  /// No description provided for @settingsPinUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'PIN updated successfully.'**
  String get settingsPinUpdatedMessage;

  /// No description provided for @settingsChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePasswordTitle;

  /// No description provided for @settingsPasswordMinMessage.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get settingsPasswordMinMessage;

  /// No description provided for @settingsPasswordsNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get settingsPasswordsNoMatchMessage;

  /// No description provided for @settingsChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get settingsChooseFromGallery;

  /// No description provided for @settingsTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get settingsTakePhoto;

  /// No description provided for @settingsUpdateKycInformation.
  ///
  /// In en, this message translates to:
  /// **'Update KYC Information'**
  String get settingsUpdateKycInformation;

  /// No description provided for @settingsUploadIdFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload ID image first'**
  String get settingsUploadIdFirstMessage;

  /// No description provided for @settingsEnterIdNumberMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your ID number'**
  String get settingsEnterIdNumberMessage;

  /// No description provided for @settingsKycSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'KYC submitted successfully for review'**
  String get settingsKycSubmittedMessage;

  /// No description provided for @settingsLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogoutTitle;

  /// No description provided for @settingsLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get settingsLogoutConfirmMessage;

  /// No description provided for @sendMoneySearchRecipientMessage.
  ///
  /// In en, this message translates to:
  /// **'Search and confirm the recipient before continuing'**
  String get sendMoneySearchRecipientMessage;

  /// No description provided for @sendMoneyEnterValidAmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get sendMoneyEnterValidAmountMessage;

  /// No description provided for @sendMoneySessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get sendMoneySessionExpiredMessage;

  /// No description provided for @sendMoneyTransferBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This transfer is blocked for safety.'**
  String get sendMoneyTransferBlockedMessage;

  /// No description provided for @sendMoneyVerificationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification successful. Continuing...'**
  String get sendMoneyVerificationSuccessMessage;

  /// No description provided for @sendMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Money'**
  String get sendMoneyTitle;

  /// No description provided for @requestMoneyCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Request created for {from} ({amount})'**
  String requestMoneyCreatedMessage(String from, String amount);

  /// No description provided for @requestMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Money'**
  String get requestMoneyTitle;

  /// No description provided for @enterpriseTitle.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get enterpriseTitle;

  /// No description provided for @enterpriseEnableAutoSweepTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Auto-sweep'**
  String get enterpriseEnableAutoSweepTitle;

  /// No description provided for @enterpriseAutoSweepUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Auto-sweep updated'**
  String get enterpriseAutoSweepUpdatedMessage;

  /// No description provided for @enterpriseApprovalSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Approval submitted'**
  String get enterpriseApprovalSubmittedMessage;

  /// No description provided for @paymentScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get paymentScannerTitle;

  /// No description provided for @paymentHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get paymentHubTitle;

  /// No description provided for @paymentHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay bills, settle merchant payments, or use QR and receipt tools from one place.'**
  String get paymentHubSubtitle;

  /// No description provided for @paymentTabBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get paymentTabBills;

  /// No description provided for @paymentTabMerchants.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get paymentTabMerchants;

  /// No description provided for @paymentBillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay bills'**
  String get paymentBillsTitle;

  /// No description provided for @paymentBillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a service category, then continue with the provider you want to pay.'**
  String get paymentBillsSubtitle;

  /// No description provided for @paymentMerchantTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay merchants'**
  String get paymentMerchantTitle;

  /// No description provided for @paymentMerchantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay a merchant by pay number, QR scan, or receipt photo.'**
  String get paymentMerchantSubtitle;

  /// No description provided for @paymentMerchantNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay by merchant number'**
  String get paymentMerchantNumberTitle;

  /// No description provided for @paymentMerchantNumberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the merchant pay number to continue with a verified payment.'**
  String get paymentMerchantNumberSubtitle;

  /// No description provided for @paymentMerchantNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant pay number'**
  String get paymentMerchantNumberLabel;

  /// No description provided for @paymentMerchantNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter pay number'**
  String get paymentMerchantNumberHint;

  /// No description provided for @paymentContinueMerchantPay.
  ///
  /// In en, this message translates to:
  /// **'Continue to merchant payment'**
  String get paymentContinueMerchantPay;

  /// No description provided for @paymentBillProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular providers'**
  String get paymentBillProvidersTitle;

  /// No description provided for @paymentBillProvidersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Providers will appear here for this bill category.'**
  String get paymentBillProvidersEmpty;

  /// No description provided for @paymentQrDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan detected'**
  String get paymentQrDetectedTitle;

  /// No description provided for @paymentQrDetectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI prepared a payment draft from the scanned details.'**
  String get paymentQrDetectedSubtitle;

  /// No description provided for @paymentMerchantQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay merchant with QR'**
  String get paymentMerchantQrTitle;

  /// No description provided for @paymentMerchantQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan any supported payment QR and let ORBI build the payment draft instantly.'**
  String get paymentMerchantQrSubtitle;

  /// No description provided for @paymentMerchantQrFrameHint.
  ///
  /// In en, this message translates to:
  /// **'Place the merchant QR inside the frame'**
  String get paymentMerchantQrFrameHint;

  /// No description provided for @paymentScanSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for QR...'**
  String get paymentScanSearching;

  /// No description provided for @paymentScanSearchingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to build a payment draft automatically from the detected details.'**
  String get paymentScanSearchingSubtitle;

  /// No description provided for @paymentScannerUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanner unavailable'**
  String get paymentScannerUnavailableTitle;

  /// No description provided for @paymentScannerPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan QR codes.'**
  String get paymentScannerPermissionRequired;

  /// No description provided for @paymentScannerUnsupported.
  ///
  /// In en, this message translates to:
  /// **'QR scanning is not supported on this device.'**
  String get paymentScannerUnsupported;

  /// No description provided for @paymentScannerPreparing.
  ///
  /// In en, this message translates to:
  /// **'Scanner is still preparing. Try again.'**
  String get paymentScannerPreparing;

  /// No description provided for @paymentScannerGenericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open QR scanner right now.'**
  String get paymentScannerGenericError;

  /// No description provided for @paymentScannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get paymentScannerOpenSettings;

  /// No description provided for @paymentScanDetected.
  ///
  /// In en, this message translates to:
  /// **'QR detected'**
  String get paymentScanDetected;

  /// No description provided for @paymentScanSourceQr.
  ///
  /// In en, this message translates to:
  /// **'QR scan'**
  String get paymentScanSourceQr;

  /// No description provided for @paymentScanSourceReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt scan'**
  String get paymentScanSourceReceipt;

  /// No description provided for @paymentScanTypeMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant payment'**
  String get paymentScanTypeMerchant;

  /// No description provided for @paymentScanTypeBill.
  ///
  /// In en, this message translates to:
  /// **'Bill payment'**
  String get paymentScanTypeBill;

  /// No description provided for @paymentScanTypeUniversal.
  ///
  /// In en, this message translates to:
  /// **'Universal payment'**
  String get paymentScanTypeUniversal;

  /// No description provided for @paymentScanBillDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} bill is ready'**
  String paymentScanBillDraftTitle(String name);

  /// No description provided for @paymentScanMerchantDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready to pay'**
  String paymentScanMerchantDraftTitle(String name);

  /// No description provided for @paymentScanUniversalDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} details detected'**
  String paymentScanUniversalDraftTitle(String name);

  /// No description provided for @paymentScanBillDraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI matched the provider and prepared a bill payment draft from this scan.'**
  String get paymentScanBillDraftSubtitle;

  /// No description provided for @paymentScanMerchantDraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI recognized the merchant and created a ready-to-review merchant payment draft.'**
  String get paymentScanMerchantDraftSubtitle;

  /// No description provided for @paymentScanUniversalDraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI captured the payment details and created a draft you can review before paying.'**
  String get paymentScanUniversalDraftSubtitle;

  /// No description provided for @paymentScanDraftAmountPending.
  ///
  /// In en, this message translates to:
  /// **'Amount pending'**
  String get paymentScanDraftAmountPending;

  /// No description provided for @paymentScanDraftAutoCreated.
  ///
  /// In en, this message translates to:
  /// **'Draft created'**
  String get paymentScanDraftAutoCreated;

  /// No description provided for @paymentScanNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Some details still need review before payment.'**
  String get paymentScanNeedsReview;

  /// No description provided for @paymentScanNeedsReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI captured the scan, but a few payment details still need your review.'**
  String get paymentScanNeedsReviewSubtitle;

  /// No description provided for @paymentScanOpenDraft.
  ///
  /// In en, this message translates to:
  /// **'Review payment draft'**
  String get paymentScanOpenDraft;

  /// No description provided for @paymentScanDetailMerchantId.
  ///
  /// In en, this message translates to:
  /// **'Merchant ID'**
  String get paymentScanDetailMerchantId;

  /// No description provided for @paymentNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get paymentNoteLabel;

  /// No description provided for @paymentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Use a receipt photo'**
  String get paymentReceiptTitle;

  /// No description provided for @paymentReceiptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload or capture a receipt and let ORBI prepare a payment draft from the extracted details.'**
  String get paymentReceiptSubtitle;

  /// No description provided for @paymentUseForPayment.
  ///
  /// In en, this message translates to:
  /// **'Use for payment'**
  String get paymentUseForPayment;

  /// No description provided for @paymentOrbiPayTitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI Pay'**
  String get paymentOrbiPayTitle;

  /// No description provided for @paymentOrbiPayNoWallets.
  ///
  /// In en, this message translates to:
  /// **'No wallet is available for ORBI Pay right now.'**
  String get paymentOrbiPayNoWallets;

  /// No description provided for @paymentOrbiPayAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get paymentOrbiPayAmountHint;

  /// No description provided for @paymentOrbiPayAmountValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount for ORBI Pay.'**
  String get paymentOrbiPayAmountValidation;

  /// No description provided for @paymentOrbiPayPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment preview'**
  String get paymentOrbiPayPreviewTitle;

  /// No description provided for @paymentOrbiPayPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get paymentOrbiPayPreviewAction;

  /// No description provided for @paymentOrbiPayConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get paymentOrbiPayConfirmAction;

  /// No description provided for @paymentOrbiPaySuccess.
  ///
  /// In en, this message translates to:
  /// **'ORBI Pay merchant payment submitted.'**
  String get paymentOrbiPaySuccess;

  /// No description provided for @paymentMerchantDefaultNote.
  ///
  /// In en, this message translates to:
  /// **'Merchant payment'**
  String get paymentMerchantDefaultNote;

  /// No description provided for @paymentBillPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill payment'**
  String get paymentBillPayTitle;

  /// No description provided for @paymentBillPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill preview'**
  String get paymentBillPreviewTitle;

  /// No description provided for @paymentBillPayConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Pay bill'**
  String get paymentBillPayConfirmAction;

  /// No description provided for @paymentBillFundingWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get paymentBillFundingWallet;

  /// No description provided for @paymentBillFundingReserve.
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get paymentBillFundingReserve;

  /// No description provided for @paymentBillFundingSharedBudget.
  ///
  /// In en, this message translates to:
  /// **'Shared budget'**
  String get paymentBillFundingSharedBudget;

  /// No description provided for @paymentBillWalletHelper.
  ///
  /// In en, this message translates to:
  /// **'Goal-backed wallets are excluded for safer bill payments.'**
  String get paymentBillWalletHelper;

  /// No description provided for @paymentBillReserveHelper.
  ///
  /// In en, this message translates to:
  /// **'This payment will use the reserve-backed wallet for the matched bill reserve.'**
  String get paymentBillReserveHelper;

  /// No description provided for @paymentBillSharedBudgetHelper.
  ///
  /// In en, this message translates to:
  /// **'Use a shared budget only when this bill belongs to that family or team budget.'**
  String get paymentBillSharedBudgetHelper;

  /// No description provided for @paymentBillReserveMatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill reserve matched'**
  String get paymentBillReserveMatchedTitle;

  /// No description provided for @paymentBillReserveUsingTitle.
  ///
  /// In en, this message translates to:
  /// **'Paying from reserve'**
  String get paymentBillReserveUsingTitle;

  /// No description provided for @paymentBillReserveMatchedMessage.
  ///
  /// In en, this message translates to:
  /// **'{provider} has a reserve with around {amount} ready for this bill.'**
  String paymentBillReserveMatchedMessage(Object provider, Object amount);

  /// No description provided for @paymentBillReserveUsingMessage.
  ///
  /// In en, this message translates to:
  /// **'{provider} will use the matched reserve amount of around {amount} for this payment.'**
  String paymentBillReserveUsingMessage(Object provider, Object amount);

  /// No description provided for @paymentBillReserveStrongMatch.
  ///
  /// In en, this message translates to:
  /// **'Strong reserve match'**
  String get paymentBillReserveStrongMatch;

  /// No description provided for @paymentBillReservePossibleMatch.
  ///
  /// In en, this message translates to:
  /// **'Possible reserve match'**
  String get paymentBillReservePossibleMatch;

  /// No description provided for @paymentBillNoFundingSources.
  ///
  /// In en, this message translates to:
  /// **'No safe bill payment source is available right now.'**
  String get paymentBillNoFundingSources;

  /// No description provided for @paymentBillPayReserveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bill payment completed using the matched reserve wallet.'**
  String get paymentBillPayReserveSuccess;

  /// No description provided for @paymentBillPaySharedBudgetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bill payment recorded against the shared budget.'**
  String get paymentBillPaySharedBudgetSuccess;

  /// No description provided for @paymentBillPaySuccess.
  ///
  /// In en, this message translates to:
  /// **'Bill payment submitted.'**
  String get paymentBillPaySuccess;

  /// No description provided for @paymentBillReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter meter, control number, or account reference'**
  String get paymentBillReferenceHint;

  /// No description provided for @paymentScanConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get paymentScanConfidenceHigh;

  /// No description provided for @paymentScanConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get paymentScanConfidenceMedium;

  /// No description provided for @paymentScanConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get paymentScanConfidenceLow;

  /// No description provided for @paymentScanConfidenceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid scan'**
  String get paymentScanConfidenceInvalid;

  /// No description provided for @paymentScanInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'This code is not ready for payment'**
  String get paymentScanInvalidTitle;

  /// No description provided for @paymentScanInvalidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI could not find enough trusted payment details in this scan. You can try another code or use merchant pay number.'**
  String get paymentScanInvalidSubtitle;

  /// No description provided for @paymentScanInvalidFallbackAction.
  ///
  /// In en, this message translates to:
  /// **'Use merchant pay number'**
  String get paymentScanInvalidFallbackAction;

  /// No description provided for @paymentScanInvalidStatus.
  ///
  /// In en, this message translates to:
  /// **'This scan could not be used for payment.'**
  String get paymentScanInvalidStatus;

  /// No description provided for @paymentScanDetailRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get paymentScanDetailRecipient;

  /// No description provided for @paymentScanDetailProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get paymentScanDetailProvider;

  /// No description provided for @paymentScanDetailCategory.
  ///
  /// In en, this message translates to:
  /// **'Bill category'**
  String get paymentScanDetailCategory;

  /// No description provided for @paymentScanDetailReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get paymentScanDetailReference;

  /// No description provided for @paymentScanDetailSchema.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get paymentScanDetailSchema;

  /// No description provided for @paymentScanPaymentReady.
  ///
  /// In en, this message translates to:
  /// **'Payment draft ready'**
  String get paymentScanPaymentReady;

  /// No description provided for @paymentScanMerchantAutoRoute.
  ///
  /// In en, this message translates to:
  /// **'Opening merchant payment draft...'**
  String get paymentScanMerchantAutoRoute;

  /// No description provided for @paymentScanBillAutoRoute.
  ///
  /// In en, this message translates to:
  /// **'Opening bill payment draft...'**
  String get paymentScanBillAutoRoute;

  /// No description provided for @paymentReviewPayment.
  ///
  /// In en, this message translates to:
  /// **'Review payment'**
  String get paymentReviewPayment;

  /// No description provided for @notificationsCouldNotOpenMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not open {value}'**
  String notificationsCouldNotOpenMessage(String value);

  /// No description provided for @notificationsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get notificationsDetailsTitle;

  /// No description provided for @notificationsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String notificationsSelectedCount(int count);

  /// No description provided for @notificationsClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get notificationsClearSelection;

  /// No description provided for @notificationsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get notificationsSelectAll;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'New alerts and account updates will appear here.'**
  String get notificationsEmptyMessage;

  /// No description provided for @notificationsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications'**
  String get notificationsLoadFailedTitle;

  /// No description provided for @notificationsJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get notificationsJustNow;

  /// No description provided for @notificationsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String notificationsMinutesAgo(int count);

  /// No description provided for @notificationsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notificationsHoursAgo(int count);

  /// No description provided for @notificationsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String notificationsDaysAgo(int count);

  /// No description provided for @notificationsFullTime.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String notificationsFullTime(String date, String time);

  /// No description provided for @transactionsSessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get transactionsSessionExpiredMessage;

  /// No description provided for @transactionsFetchFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch transactions right now.'**
  String get transactionsFetchFailedMessage;

  /// No description provided for @transactionsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions'**
  String get transactionsLoadFailedTitle;

  /// No description provided for @transactionsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionsHistoryTitle;

  /// No description provided for @transactionsFilterByMoneyState.
  ///
  /// In en, this message translates to:
  /// **'Filter by money state'**
  String get transactionsFilterByMoneyState;

  /// No description provided for @transactionsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get transactionsFilterAll;

  /// No description provided for @transactionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get transactionsEmptyTitle;

  /// No description provided for @transactionsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Completed payments and transfers will appear here.'**
  String get transactionsEmptyMessage;

  /// No description provided for @transactionsNoFilteredMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get transactionsNoFilteredMatchesTitle;

  /// No description provided for @transactionsNoFilteredMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another money state to view matching activity.'**
  String get transactionsNoFilteredMatchesMessage;

  /// No description provided for @transactionsItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String transactionsItemsCount(int count);

  /// No description provided for @transactionsReceivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String transactionsReceivedFrom(String name);

  /// No description provided for @transactionsSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String transactionsSentTo(String name);

  /// No description provided for @transactionsGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionsGenericTitle;

  /// No description provided for @transactionsCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get transactionsCredit;

  /// No description provided for @transactionsDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get transactionsDebit;

  /// No description provided for @transactionsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get transactionsNotAvailable;

  /// No description provided for @transactionsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transactionsStatusCompleted;

  /// No description provided for @transactionsReceiptReferenceId.
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get transactionsReceiptReferenceId;

  /// No description provided for @transactionsReceiptType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get transactionsReceiptType;

  /// No description provided for @transactionsReceiptStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get transactionsReceiptStatus;

  /// No description provided for @transactionsReceiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transactionsReceiptAmount;

  /// No description provided for @transactionsReceiptBaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Base Amount'**
  String get transactionsReceiptBaseAmount;

  /// No description provided for @transactionsReceiptTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get transactionsReceiptTax;

  /// No description provided for @transactionsReceiptServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Service Fee'**
  String get transactionsReceiptServiceFee;

  /// No description provided for @transactionsReceiptTotalCharged.
  ///
  /// In en, this message translates to:
  /// **'Total Charged'**
  String get transactionsReceiptTotalCharged;

  /// No description provided for @transactionsReceiptDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get transactionsReceiptDirection;

  /// No description provided for @transactionsReceiptMoneyState.
  ///
  /// In en, this message translates to:
  /// **'Money State'**
  String get transactionsReceiptMoneyState;

  /// No description provided for @transactionsReceiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transactionsReceiptDate;

  /// No description provided for @transactionsReceiptFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transactionsReceiptFrom;

  /// No description provided for @transactionsReceiptTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transactionsReceiptTo;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @sendMoneyLoadSourceWalletsFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load source wallets.'**
  String get sendMoneyLoadSourceWalletsFailedMessage;

  /// No description provided for @sendMoneySearchMinCharsMessage.
  ///
  /// In en, this message translates to:
  /// **'Type at least 5 characters to search'**
  String get sendMoneySearchMinCharsMessage;

  /// No description provided for @sendMoneySearchMinCharsLongMessage.
  ///
  /// In en, this message translates to:
  /// **'Please type at least 5 characters to start searching.'**
  String get sendMoneySearchMinCharsLongMessage;

  /// No description provided for @sendMoneyRecipientNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that person. Please check the ID or phone number and try again.'**
  String get sendMoneyRecipientNotFoundMessage;

  /// No description provided for @sendMoneySearchUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Search is currently unavailable. Please try again in a moment.'**
  String get sendMoneySearchUnavailableMessage;

  /// No description provided for @sendMoneyPreviewFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to preview this transfer right now.'**
  String get sendMoneyPreviewFailedMessage;

  /// No description provided for @sendMoneyPreviewTimedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview request timed out. Please try again.'**
  String get sendMoneyPreviewTimedOutMessage;

  /// No description provided for @sendMoneyPreviewRequestFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview request failed. Please try again.'**
  String get sendMoneyPreviewRequestFailedMessage;

  /// No description provided for @sendMoneyPreviewRequestFailedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Preview failed ({status}). Please try again.'**
  String sendMoneyPreviewRequestFailedWithStatus(int status);

  /// No description provided for @sendMoneyPreviewInvalidFormatMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid preview response format'**
  String get sendMoneyPreviewInvalidFormatMessage;

  /// No description provided for @sendMoneyPreviewUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not preview this transaction.'**
  String get sendMoneyPreviewUnavailableMessage;

  /// No description provided for @sendMoneyPreviewDataMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview data missing from response'**
  String get sendMoneyPreviewDataMissingMessage;

  /// No description provided for @sendMoneyPreviewRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview rejected by backend.'**
  String get sendMoneyPreviewRejectedMessage;

  /// No description provided for @sendMoneyConfirmTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transfer'**
  String get sendMoneyConfirmTransferTitle;

  /// No description provided for @sendMoneySubmittingLabel.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get sendMoneySubmittingLabel;

  /// No description provided for @sendMoneyConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get sendMoneyConfirmAction;

  /// No description provided for @sendMoneyTransactionSuccessfulTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Successful'**
  String get sendMoneyTransactionSuccessfulTitle;

  /// No description provided for @sendMoneyTransactionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Failed'**
  String get sendMoneyTransactionFailedTitle;

  /// No description provided for @sendMoneySubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit this transfer right now.'**
  String get sendMoneySubmitFailedMessage;

  /// No description provided for @sendMoneyExternalSubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit external transfer right now.'**
  String get sendMoneyExternalSubmitFailedMessage;

  /// No description provided for @sendMoneyReceiptTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get sendMoneyReceiptTransactionId;

  /// No description provided for @sendMoneyReceiptReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get sendMoneyReceiptReference;

  /// No description provided for @sendMoneyReceiptControlId.
  ///
  /// In en, this message translates to:
  /// **'Control ID'**
  String get sendMoneyReceiptControlId;

  /// No description provided for @sendMoneyReceiptStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get sendMoneyReceiptStatus;

  /// No description provided for @sendMoneyReceiptType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sendMoneyReceiptType;

  /// No description provided for @sendMoneyReceiptTransaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get sendMoneyReceiptTransaction;

  /// No description provided for @sendMoneyReceiptRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get sendMoneyReceiptRecipient;

  /// No description provided for @sendMoneyReceiptSourceWallet.
  ///
  /// In en, this message translates to:
  /// **'Source Wallet'**
  String get sendMoneyReceiptSourceWallet;

  /// No description provided for @sendMoneyReceiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendMoneyReceiptAmount;

  /// No description provided for @sendMoneyReceiptTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get sendMoneyReceiptTax;

  /// No description provided for @sendMoneyReceiptFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get sendMoneyReceiptFee;

  /// No description provided for @sendMoneyReceiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sendMoneyReceiptTotal;

  /// No description provided for @sendMoneyReceiptDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get sendMoneyReceiptDescription;

  /// No description provided for @sendMoneyReceiptTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sendMoneyReceiptTime;

  /// No description provided for @sendMoneyHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Move Money Faster'**
  String get sendMoneyHeroTitle;

  /// No description provided for @sendMoneyHeroInternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instant transfers between Orbi users with secure preview and wallet selection.'**
  String get sendMoneyHeroInternalSubtitle;

  /// No description provided for @sendMoneyHeroExternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send funds to bank, mobile wallet, PayPal, and crypto destinations.'**
  String get sendMoneyHeroExternalSubtitle;

  /// No description provided for @sendMoneyCurrencyPill.
  ///
  /// In en, this message translates to:
  /// **'Currency: {currency}'**
  String sendMoneyCurrencyPill(String currency);

  /// No description provided for @sendMoneySenderWalletReady.
  ///
  /// In en, this message translates to:
  /// **'Sender: {sender} • Operating wallet ready'**
  String sendMoneySenderWalletReady(String sender);

  /// No description provided for @sendMoneySenderWalletMissing.
  ///
  /// In en, this message translates to:
  /// **'Sender: {sender} • Operating wallet missing'**
  String sendMoneySenderWalletMissing(String sender);

  /// No description provided for @sendMoneySectionRecipientTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Recipient'**
  String get sendMoneySectionRecipientTitle;

  /// No description provided for @sendMoneySectionRecipientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search by Orbi ID, email, or phone'**
  String get sendMoneySectionRecipientSubtitle;

  /// No description provided for @sendMoneyRecipientFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient ID or phone'**
  String get sendMoneyRecipientFieldLabel;

  /// No description provided for @sendMoneyRecipientFieldHint.
  ///
  /// In en, this message translates to:
  /// **'OB26-1234-5678 or +2557XXXXXXX'**
  String get sendMoneyRecipientFieldHint;

  /// No description provided for @sendMoneyRecipientRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient ID or phone number'**
  String get sendMoneyRecipientRequiredMessage;

  /// No description provided for @sendMoneySectionSourceWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Source Wallet'**
  String get sendMoneySectionSourceWalletTitle;

  /// No description provided for @sendMoneySectionSourceWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select Goal/Budget if you want sub-wallet funded transfer'**
  String get sendMoneySectionSourceWalletSubtitle;

  /// No description provided for @sendMoneySectionAmountNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Amount & Note'**
  String get sendMoneySectionAmountNoteTitle;

  /// No description provided for @sendMoneySectionAmountNoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set transfer value and optional description'**
  String get sendMoneySectionAmountNoteSubtitle;

  /// No description provided for @sendMoneyAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendMoneyAmountLabel;

  /// No description provided for @sendMoneyDescriptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get sendMoneyDescriptionOptionalLabel;

  /// No description provided for @sendMoneyDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Transfer reason'**
  String get sendMoneyDescriptionHint;

  /// No description provided for @sendMoneyPreparingPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparing preview...'**
  String get sendMoneyPreparingPreviewLabel;

  /// No description provided for @sendMoneyContinueTransferLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue Transfer'**
  String get sendMoneyContinueTransferLabel;

  /// No description provided for @sendMoneyNoGoalWalletsMessage.
  ///
  /// In en, this message translates to:
  /// **'No goal or budget source wallet is available right now. This transfer will use your Operating Wallet automatically.'**
  String get sendMoneyNoGoalWalletsMessage;

  /// No description provided for @sendMoneyOperatingWalletAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Operating Wallet (Auto)'**
  String get sendMoneyOperatingWalletAutoTitle;

  /// No description provided for @sendMoneyOperatingWalletAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default source when no sub-wallet is selected'**
  String get sendMoneyOperatingWalletAutoSubtitle;

  /// No description provided for @sendMoneyDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get sendMoneyDefaultBadge;

  /// No description provided for @sendMoneySourceBadgeOperating.
  ///
  /// In en, this message translates to:
  /// **'OPERATING'**
  String get sendMoneySourceBadgeOperating;

  /// No description provided for @sendMoneySourceBadgeGoal.
  ///
  /// In en, this message translates to:
  /// **'GOAL'**
  String get sendMoneySourceBadgeGoal;

  /// No description provided for @sendMoneySourceBadgeBudget.
  ///
  /// In en, this message translates to:
  /// **'BUDGET'**
  String get sendMoneySourceBadgeBudget;

  /// No description provided for @sendMoneySourceBadgeSavings.
  ///
  /// In en, this message translates to:
  /// **'SAVINGS'**
  String get sendMoneySourceBadgeSavings;

  /// No description provided for @sendMoneySourceBadgeSubWallet.
  ///
  /// In en, this message translates to:
  /// **'SUB-WALLET'**
  String get sendMoneySourceBadgeSubWallet;

  /// No description provided for @sendMoneyGoalSourceWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal funds are protected'**
  String get sendMoneyGoalSourceWarningTitle;

  /// No description provided for @sendMoneyGoalSourceWarningBody.
  ///
  /// In en, this message translates to:
  /// **'You selected a goal-backed source wallet. Continue only if you intentionally want to spend or release money from that goal allocation.'**
  String get sendMoneyGoalSourceWarningBody;

  /// No description provided for @sendMoneyGoalSourceContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get sendMoneyGoalSourceContinueAction;

  /// No description provided for @sendMoneyGoalSourceInlineWarning.
  ///
  /// In en, this message translates to:
  /// **'This source is goal-backed. Goal funds should only be used intentionally, not as ordinary spending money.'**
  String get sendMoneyGoalSourceInlineWarning;

  /// No description provided for @sendMoneyWalletIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String sendMoneyWalletIdLabel(String id);

  /// No description provided for @sendMoneyExternalSectionRailProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Rail & Provider'**
  String get sendMoneyExternalSectionRailProviderTitle;

  /// No description provided for @sendMoneyExternalSectionRailProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose payout channel'**
  String get sendMoneyExternalSectionRailProviderSubtitle;

  /// No description provided for @sendMoneyProviderCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider Code'**
  String get sendMoneyProviderCodeLabel;

  /// No description provided for @sendMoneyProviderCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Example: NMB, MPESA, PAYPAL'**
  String get sendMoneyProviderCodeHint;

  /// No description provided for @sendMoneyProviderCodeRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter provider code'**
  String get sendMoneyProviderCodeRequiredMessage;

  /// No description provided for @sendMoneyExternalSectionDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Destination'**
  String get sendMoneyExternalSectionDestinationTitle;

  /// No description provided for @sendMoneyExternalSectionDestinationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where the money is going'**
  String get sendMoneyExternalSectionDestinationSubtitle;

  /// No description provided for @sendMoneyCardNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get sendMoneyCardNumberLabel;

  /// No description provided for @sendMoneyAccountAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Account / Address'**
  String get sendMoneyAccountAddressLabel;

  /// No description provided for @sendMoneyCardNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter card number'**
  String get sendMoneyCardNumberHint;

  /// No description provided for @sendMoneyDestinationAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter destination account'**
  String get sendMoneyDestinationAccountHint;

  /// No description provided for @sendMoneyCardNumberRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter card number'**
  String get sendMoneyCardNumberRequiredMessage;

  /// No description provided for @sendMoneyAccountAddressRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter account or address'**
  String get sendMoneyAccountAddressRequiredMessage;

  /// No description provided for @sendMoneyRecipientReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient Reference'**
  String get sendMoneyRecipientReferenceLabel;

  /// No description provided for @sendMoneyRecipientReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Target destination reference'**
  String get sendMoneyRecipientReferenceHint;

  /// No description provided for @sendMoneyRecipientReferenceRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient reference'**
  String get sendMoneyRecipientReferenceRequiredMessage;

  /// No description provided for @sendMoneyExternalSectionFundingTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Funding Source'**
  String get sendMoneyExternalSectionFundingTitle;

  /// No description provided for @sendMoneyExternalSectionFundingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick source type and wallet'**
  String get sendMoneyExternalSectionFundingSubtitle;

  /// No description provided for @sendMoneySourceWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Source Wallet'**
  String get sendMoneySourceWalletLabel;

  /// No description provided for @sendMoneySourceWalletHint.
  ///
  /// In en, this message translates to:
  /// **'Internal, External Mobile, External Bank'**
  String get sendMoneySourceWalletHint;

  /// No description provided for @sendMoneyBackendSourceWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend Source Wallet'**
  String get sendMoneyBackendSourceWalletLabel;

  /// No description provided for @sendMoneyLoadingWalletsHint.
  ///
  /// In en, this message translates to:
  /// **'Loading wallets...'**
  String get sendMoneyLoadingWalletsHint;

  /// No description provided for @sendMoneySelectLoadedWalletHint.
  ///
  /// In en, this message translates to:
  /// **'Select loaded wallet'**
  String get sendMoneySelectLoadedWalletHint;

  /// No description provided for @sendMoneySelectSourceWalletRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a source wallet from backend list'**
  String get sendMoneySelectSourceWalletRequiredMessage;

  /// No description provided for @sendMoneyExternalSectionAmountNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'4. Amount & Note'**
  String get sendMoneyExternalSectionAmountNoteTitle;

  /// No description provided for @sendMoneyBudgetCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget category'**
  String get sendMoneyBudgetCategoryLabel;

  /// No description provided for @sendMoneyBudgetCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Optional spending category'**
  String get sendMoneyBudgetCategoryHint;

  /// No description provided for @sendMoneyBudgetCategoryOptionalHelper.
  ///
  /// In en, this message translates to:
  /// **'Tag this transfer to a budget category for tracking and alerts.'**
  String get sendMoneyBudgetCategoryOptionalHelper;

  /// No description provided for @sendMoneyBudgetCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'No budget category'**
  String get sendMoneyBudgetCategoryNone;

  /// No description provided for @sendMoneyNoBudgetCategoriesMessage.
  ///
  /// In en, this message translates to:
  /// **'No budget categories available yet. Create one in Goals & Budget to tag transfers.'**
  String get sendMoneyNoBudgetCategoriesMessage;

  /// No description provided for @sendMoneyBudgetCategoriesLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load budget categories right now.'**
  String get sendMoneyBudgetCategoriesLoadFailedMessage;

  /// No description provided for @sendMoneyBudgetSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget: {name}'**
  String sendMoneyBudgetSummaryTitle(String name);

  /// No description provided for @sendMoneyBudgetSummaryBody.
  ///
  /// In en, this message translates to:
  /// **'Limit {budget} • Spent {spent} • Remaining {remaining}'**
  String sendMoneyBudgetSummaryBody(
    String budget,
    String spent,
    String remaining,
  );

  /// No description provided for @sendMoneyBudgetHardLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Hard limit • {period}'**
  String sendMoneyBudgetHardLimitLabel(String period);

  /// No description provided for @sendMoneyBudgetSoftLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Soft limit • {period}'**
  String sendMoneyBudgetSoftLimitLabel(String period);

  /// No description provided for @sendMoneyBudgetHardLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is under a hard limit. Only {remaining} remains, so this transfer cannot continue.'**
  String sendMoneyBudgetHardLimitMessage(String name, String remaining);

  /// No description provided for @sendMoneyBudgetSoftLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget warning'**
  String get sendMoneyBudgetSoftLimitTitle;

  /// No description provided for @sendMoneyBudgetSoftLimitBody.
  ///
  /// In en, this message translates to:
  /// **'{name} may be exceeded. Only {remaining} remains in this budget. Continue and rely on fallback funding if backend policy allows?'**
  String sendMoneyBudgetSoftLimitBody(String name, String remaining);

  /// No description provided for @sendMoneyBudgetSoftLimitContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue With Warning'**
  String get sendMoneyBudgetSoftLimitContinue;

  /// No description provided for @sendMoneyContinueExternalTransferLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue External Transfer'**
  String get sendMoneyContinueExternalTransferLabel;

  /// No description provided for @sendMoneyModeInternalTitle.
  ///
  /// In en, this message translates to:
  /// **'Internal P2P'**
  String get sendMoneyModeInternalTitle;

  /// No description provided for @sendMoneyModeInternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Orbi user to user'**
  String get sendMoneyModeInternalSubtitle;

  /// No description provided for @sendMoneyModeExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get sendMoneyModeExternalTitle;

  /// No description provided for @sendMoneyModeExternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bank, Mobile, PayPal, Crypto'**
  String get sendMoneyModeExternalSubtitle;

  /// No description provided for @sendMoneyRailBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get sendMoneyRailBank;

  /// No description provided for @sendMoneyRailMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile Wallet'**
  String get sendMoneyRailMobileWallet;

  /// No description provided for @sendMoneyRailPaypal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get sendMoneyRailPaypal;

  /// No description provided for @sendMoneyRailCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get sendMoneyRailCrypto;

  /// No description provided for @sendMoneySourceTypeInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get sendMoneySourceTypeInternal;

  /// No description provided for @sendMoneySourceTypeExternalMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'External Mobile Wallet'**
  String get sendMoneySourceTypeExternalMobileWallet;

  /// No description provided for @sendMoneySourceTypeExternalBank.
  ///
  /// In en, this message translates to:
  /// **'External Bank'**
  String get sendMoneySourceTypeExternalBank;

  /// No description provided for @sendMoneyRecipientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient ID'**
  String get sendMoneyRecipientIdLabel;

  /// No description provided for @sendMoneyFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get sendMoneyFullNameLabel;

  /// No description provided for @sendMoneyVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get sendMoneyVerifiedLabel;

  /// No description provided for @sendMoneyNotVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get sendMoneyNotVerifiedLabel;

  /// No description provided for @sendMoneyRecipientFallback.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get sendMoneyRecipientFallback;

  /// No description provided for @sendMoneyPreviewServiceFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get sendMoneyPreviewServiceFeeLabel;

  /// No description provided for @sendMoneyPreviewTotalToPayLabel.
  ///
  /// In en, this message translates to:
  /// **'Total to pay'**
  String get sendMoneyPreviewTotalToPayLabel;

  /// No description provided for @sendMoneyPreviewExchangeRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get sendMoneyPreviewExchangeRateLabel;

  /// No description provided for @sendMoneyPreviewFxFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'FX fee'**
  String get sendMoneyPreviewFxFeeLabel;

  /// No description provided for @sendMoneyPreviewRecipientGetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient gets'**
  String get sendMoneyPreviewRecipientGetsLabel;

  /// No description provided for @sendMoneyPreviewAvailableBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get sendMoneyPreviewAvailableBalanceLabel;

  /// No description provided for @sendMoneyInsufficientBalanceMessage.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance. Short by {amount}.'**
  String sendMoneyInsufficientBalanceMessage(String amount);

  /// No description provided for @sendMoneySecurityCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Security check: {status}'**
  String sendMoneySecurityCheckStatus(String status);

  /// No description provided for @otpCodeSentLabel.
  ///
  /// In en, this message translates to:
  /// **'Code sent to your phone'**
  String get otpCodeSentLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmLabel;

  /// No description provided for @pinCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get pinCurrentLabel;

  /// No description provided for @pinNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNewLabel;

  /// No description provided for @pinConfirmNewLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get pinConfirmNewLabel;

  /// No description provided for @passwordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get passwordNewLabel;

  /// No description provided for @passwordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get passwordConfirmLabel;

  /// No description provided for @settingsBiometricEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Biometric sign-in enabled'**
  String get settingsBiometricEnabledMessage;

  /// No description provided for @settingsBiometricEnableFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to enable biometric sign-in'**
  String get settingsBiometricEnableFailedMessage;

  /// No description provided for @settingsPinRequiredForBiometricMessage.
  ///
  /// In en, this message translates to:
  /// **'PIN setup is required to use biometric sign-in. Biometric sign-in disabled.'**
  String get settingsPinRequiredForBiometricMessage;

  /// No description provided for @settingsProfileUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get settingsProfileUpdatedMessage;

  /// No description provided for @settingsProfileUpdateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get settingsProfileUpdateFailedMessage;

  /// No description provided for @settingsPasswordUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get settingsPasswordUpdatedMessage;

  /// No description provided for @settingsPasswordUpdateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password.'**
  String get settingsPasswordUpdateFailedMessage;

  /// No description provided for @settingsProfilePhotoUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get settingsProfilePhotoUpdatedMessage;

  /// No description provided for @settingsProfilePhotoFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get settingsProfilePhotoFailedMessage;

  /// No description provided for @sessionExpiredLoginMessage.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get sessionExpiredLoginMessage;

  /// No description provided for @otpEnterCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP code'**
  String get otpEnterCodeLabel;

  /// No description provided for @otpAttemptHelper.
  ///
  /// In en, this message translates to:
  /// **'{helperText}\nAttempt {attempt}'**
  String otpAttemptHelper(String helperText, int attempt);

  /// No description provided for @enterpriseOperatingVaultThreshold.
  ///
  /// In en, this message translates to:
  /// **'Operating vault threshold ({currency})'**
  String enterpriseOperatingVaultThreshold(String currency);

  /// No description provided for @requestMoneyFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Request From'**
  String get requestMoneyFromLabel;

  /// No description provided for @requestMoneyAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get requestMoneyAmountLabel;

  /// No description provided for @requestMoneyReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get requestMoneyReasonLabel;

  /// No description provided for @requestMoneyFromHint.
  ///
  /// In en, this message translates to:
  /// **'Phone, email, or username'**
  String get requestMoneyFromHint;

  /// No description provided for @requestMoneyAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get requestMoneyAmountHint;

  /// No description provided for @requestMoneyReasonHint.
  ///
  /// In en, this message translates to:
  /// **'What is this request for?'**
  String get requestMoneyReasonHint;

  /// No description provided for @settingsKycRegisteredFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Registered Full Name'**
  String get settingsKycRegisteredFullNameLabel;

  /// No description provided for @settingsKycIdTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'ID Type'**
  String get settingsKycIdTypeLabel;

  /// No description provided for @settingsKycIdNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'ID Number'**
  String get settingsKycIdNumberLabel;

  /// No description provided for @requestMoneyIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a payment request and share it with another user.'**
  String get requestMoneyIntro;

  /// No description provided for @requestMoneyValidatorFrom.
  ///
  /// In en, this message translates to:
  /// **'Enter who to request from'**
  String get requestMoneyValidatorFrom;

  /// No description provided for @requestMoneyValidatorAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get requestMoneyValidatorAmount;

  /// No description provided for @settingsKycSubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit KYC information'**
  String get settingsKycSubmitFailedMessage;

  /// No description provided for @sendMoneyVerificationCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Transaction verification was cancelled. Please try again.'**
  String get sendMoneyVerificationCancelledMessage;

  /// No description provided for @otpInvalidCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again.'**
  String get otpInvalidCodeMessage;

  /// No description provided for @settingsProfileNameMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile name missing. Update profile first.'**
  String get settingsProfileNameMissingMessage;

  /// No description provided for @settingsUploadIdHoldingMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload a screenshot/photo while holding your ID'**
  String get settingsUploadIdHoldingMessage;

  /// No description provided for @settingsScanNameMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Scan name differs from profile name. Keep names matching your registered profile.'**
  String get settingsScanNameMismatchMessage;

  /// No description provided for @settingsScanSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'ID data extracted successfully.'**
  String get settingsScanSuccessMessage;

  /// No description provided for @settingsScanDobLabel.
  ///
  /// In en, this message translates to:
  /// **'DOB'**
  String get settingsScanDobLabel;

  /// No description provided for @settingsScanExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get settingsScanExpiryLabel;

  /// No description provided for @settingsServicePreferencesUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Service preferences updated'**
  String get settingsServicePreferencesUpdatedMessage;

  /// No description provided for @settingsServicePreferencesUpdateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update preferences'**
  String get settingsServicePreferencesUpdateFailedMessage;

  /// No description provided for @settingsAllPreferencesUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'All preferences updated successfully'**
  String get settingsAllPreferencesUpdatedMessage;

  /// No description provided for @settingsAppLanguageUpdatedServiceFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'App language updated, but service preferences failed'**
  String get settingsAppLanguageUpdatedServiceFailedMessage;

  /// No description provided for @settingsServiceUpdatedAppFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Service preferences updated, but app language failed'**
  String get settingsServiceUpdatedAppFailedMessage;

  /// No description provided for @settingsAllPreferencesUpdateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update any preferences'**
  String get settingsAllPreferencesUpdateFailedMessage;

  /// No description provided for @settingsAppLanguageUpdateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update app language'**
  String get settingsAppLanguageUpdateFailedMessage;

  /// No description provided for @settingsNoPreferencesSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'No preferences selected to apply'**
  String get settingsNoPreferencesSelectedMessage;

  /// No description provided for @settingsSecurityVerificationHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to your registered contact to approve this security action.'**
  String get settingsSecurityVerificationHelper;

  /// No description provided for @settingsKycVerificationRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC Verification Required'**
  String get settingsKycVerificationRequiredTitle;

  /// No description provided for @settingsKycVerificationRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Update your KYC information for more access, unlimited transaction limits, and more features from ORBI.'**
  String get settingsKycVerificationRequiredMessage;

  /// No description provided for @settingsKycUploadRequirementTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC upload requirement'**
  String get settingsKycUploadRequirementTitle;

  /// No description provided for @settingsKycUploadRequirementMessage.
  ///
  /// In en, this message translates to:
  /// **'• Upload a clear screenshot/photo while holding your ID\n• Your face and ID details must be readable\n• Use good lighting and avoid blur or cropped edges'**
  String get settingsKycUploadRequirementMessage;

  /// No description provided for @settingsIdTypeNationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get settingsIdTypeNationalId;

  /// No description provided for @settingsIdTypePassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get settingsIdTypePassport;

  /// No description provided for @settingsIdTypeDrivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving License'**
  String get settingsIdTypeDrivingLicense;

  /// No description provided for @settingsIdTypeVoterId.
  ///
  /// In en, this message translates to:
  /// **'Voter ID'**
  String get settingsIdTypeVoterId;

  /// No description provided for @settingsScanCouldNotExtractMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not extract data. Use a clear, well-lit ID image.'**
  String get settingsScanCouldNotExtractMessage;

  /// No description provided for @settingsKycRegisteredNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Name below is auto-filled from your registered profile and must match your ID.'**
  String get settingsKycRegisteredNameHelper;

  /// No description provided for @settingsFaceAndIdReadableMessage.
  ///
  /// In en, this message translates to:
  /// **'Ensure your face and ID text are clearly readable.'**
  String get settingsFaceAndIdReadableMessage;

  /// No description provided for @settingsAutoScanHelperMessage.
  ///
  /// In en, this message translates to:
  /// **'Auto-scan uses multimodal AI to extract full name, ID number, document type, DOB, and expiry date. Run scan after each new upload.'**
  String get settingsAutoScanHelperMessage;

  /// No description provided for @settingsScanningIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanning ID...'**
  String get settingsScanningIdLabel;

  /// No description provided for @settingsAutoFillFromIdScanLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill from ID scan'**
  String get settingsAutoFillFromIdScanLabel;

  /// No description provided for @settingsAutoScanVerifyFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Auto-scan could not verify this document. Try a clearer image.'**
  String get settingsAutoScanVerifyFailedMessage;

  /// No description provided for @settingsSubmitDisabledUntilScanMessage.
  ///
  /// In en, this message translates to:
  /// **'Submit is disabled until auto-scan returns a response.'**
  String get settingsSubmitDisabledUntilScanMessage;

  /// No description provided for @settingsSubmitKycLabel.
  ///
  /// In en, this message translates to:
  /// **'Submit KYC'**
  String get settingsSubmitKycLabel;

  /// No description provided for @settingsUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get settingsUserFallback;

  /// No description provided for @settingsNoEmailFallback.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get settingsNoEmailFallback;

  /// No description provided for @settingsUserInitialFallback.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get settingsUserInitialFallback;

  /// No description provided for @settingsCustomerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer ID: {customerId}'**
  String settingsCustomerIdLabel(String customerId);

  /// No description provided for @settingsKycStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'KYC: {status}'**
  String settingsKycStatusLabel(String status);

  /// No description provided for @settingsVerifyNowMessage.
  ///
  /// In en, this message translates to:
  /// **'Verify now to unlock full access'**
  String get settingsVerifyNowMessage;

  /// No description provided for @settingsAccountInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get settingsAccountInformationTitle;

  /// No description provided for @settingsAccountInformationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your profile details polished and up to date.'**
  String get settingsAccountInformationSubtitle;

  /// No description provided for @settingsFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get settingsFullNameLabel;

  /// No description provided for @settingsPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsPhoneLabel;

  /// No description provided for @settingsAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddressLabel;

  /// No description provided for @settingsCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrencyLabel;

  /// No description provided for @settingsSavingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get settingsSavingLabel;

  /// No description provided for @settingsSaveProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get settingsSaveProfileLabel;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strengthen sign-in and protect sensitive account access.'**
  String get settingsSecuritySubtitle;

  /// No description provided for @settingsUseBiometricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Use biometric sign-in'**
  String get settingsUseBiometricsTitle;

  /// No description provided for @settingsUseBiometricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your device biometrics for faster, secure sign-in.'**
  String get settingsUseBiometricsSubtitle;

  /// No description provided for @settingsEnableDeviceBiometricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add biometrics in your device settings to enable this option.'**
  String get settingsEnableDeviceBiometricsSubtitle;

  /// No description provided for @settingsBiometricUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric not available on this device'**
  String get settingsBiometricUnavailableTitle;

  /// No description provided for @settingsBiometricUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can still secure your account with password and OTP.'**
  String get settingsBiometricUnavailableSubtitle;

  /// No description provided for @settingsChangePinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the fallback PIN used for biometric sign-in'**
  String get settingsChangePinSubtitle;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsDeviceNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Notifications'**
  String get settingsDeviceNotificationsTitle;

  /// No description provided for @settingsDeviceNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control local notification channels on this device.'**
  String get settingsDeviceNotificationsSubtitle;

  /// No description provided for @settingsPushNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get settingsPushNotificationsTitle;

  /// No description provided for @settingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instant alerts for activity and security events.'**
  String get settingsPushNotificationsSubtitle;

  /// No description provided for @settingsEmailAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Alerts'**
  String get settingsEmailAlertsTitle;

  /// No description provided for @settingsEmailAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive summaries and important messages by email.'**
  String get settingsEmailAlertsSubtitle;

  /// No description provided for @settingsMarketingUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Occasional tips, launches, and offers from Orbi.'**
  String get settingsMarketingUpdatesSubtitle;

  /// No description provided for @settingsHelpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpSupportTitle;

  /// No description provided for @settingsHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contact the ORBI support team'**
  String get settingsHelpSupportSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About ORBI'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutVersionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0+1'**
  String get settingsAboutVersionSubtitle;

  /// No description provided for @chatSessionUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Secure chat is unavailable for this session. Please log in again.'**
  String get chatSessionUnavailableMessage;

  /// No description provided for @chatConnectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach Orbi AI. Check your connection and retry.'**
  String get chatConnectionFailedMessage;

  /// No description provided for @chatUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Orbi AI is temporarily unavailable. Please try again.'**
  String get chatUnavailableMessage;

  /// No description provided for @chatOpenSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open secure chat'**
  String get chatOpenSemantics;

  /// No description provided for @chatCloseSemantics.
  ///
  /// In en, this message translates to:
  /// **'Close secure chat'**
  String get chatCloseSemantics;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'ORBI AI'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure messaging assistant'**
  String get chatSubtitle;

  /// No description provided for @chatResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset chat'**
  String get chatResetTooltip;

  /// No description provided for @chatEncryptedLabel.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get chatEncryptedLabel;

  /// No description provided for @chatPrivateSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Private session'**
  String get chatPrivateSessionLabel;

  /// No description provided for @chatUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat unavailable'**
  String get chatUnavailableTitle;

  /// No description provided for @chatReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure chat ready'**
  String get chatReadyTitle;

  /// No description provided for @chatReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask about transfers, balances, transaction support, or account guidance.'**
  String get chatReadyMessage;

  /// No description provided for @chatTypingLabel.
  ///
  /// In en, this message translates to:
  /// **'ORBI AI is typing...'**
  String get chatTypingLabel;

  /// No description provided for @chatComposerCompactHint.
  ///
  /// In en, this message translates to:
  /// **'Message ORBI AI'**
  String get chatComposerCompactHint;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message about balances, transfers, or account help'**
  String get chatComposerHint;

  /// No description provided for @enterpriseOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get enterpriseOrganizationTitle;

  /// No description provided for @enterpriseNoOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'No organization linked.'**
  String get enterpriseNoOrganizationTitle;

  /// No description provided for @enterpriseNoOrganizationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is not attached to an enterprise tenant.'**
  String get enterpriseNoOrganizationMessage;

  /// No description provided for @enterpriseBudgetAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Alerts'**
  String get enterpriseBudgetAlertsTitle;

  /// No description provided for @enterpriseTreasuryGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Treasury Goals'**
  String get enterpriseTreasuryGoalsTitle;

  /// No description provided for @enterprisePendingApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get enterprisePendingApprovalsTitle;

  /// No description provided for @enterpriseLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get enterpriseLoadingTitle;

  /// No description provided for @enterpriseFetchingOrganizationMessage.
  ///
  /// In en, this message translates to:
  /// **'Fetching organization details.'**
  String get enterpriseFetchingOrganizationMessage;

  /// No description provided for @enterpriseOrganizationFallback.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get enterpriseOrganizationFallback;

  /// No description provided for @enterpriseRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String enterpriseRoleLabel(String role);

  /// No description provided for @enterpriseBaseCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Base currency: {currency}'**
  String enterpriseBaseCurrencyLabel(String currency);

  /// No description provided for @enterpriseNoTreasuryGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'No treasury goals'**
  String get enterpriseNoTreasuryGoalsTitle;

  /// No description provided for @enterpriseNoTreasuryGoalsMessage.
  ///
  /// In en, this message translates to:
  /// **'No corporate goals configured.'**
  String get enterpriseNoTreasuryGoalsMessage;

  /// No description provided for @enterpriseTreasuryGoalFallback.
  ///
  /// In en, this message translates to:
  /// **'Treasury Goal'**
  String get enterpriseTreasuryGoalFallback;

  /// No description provided for @moneyStateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get moneyStateAvailable;

  /// No description provided for @moneyStateBudgeted.
  ///
  /// In en, this message translates to:
  /// **'Budgeted'**
  String get moneyStateBudgeted;

  /// No description provided for @moneyStateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get moneyStateSaved;

  /// No description provided for @moneyStateLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get moneyStateLocked;

  /// No description provided for @moneyStateSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get moneyStateSpent;

  /// No description provided for @moneyStateAllocated.
  ///
  /// In en, this message translates to:
  /// **'Allocated'**
  String get moneyStateAllocated;

  /// No description provided for @enterpriseAutoSweepEnabledStatus.
  ///
  /// In en, this message translates to:
  /// **'Auto-sweep enabled{thresholdPart}'**
  String enterpriseAutoSweepEnabledStatus(String thresholdPart);

  /// No description provided for @enterpriseThresholdSuffix.
  ///
  /// In en, this message translates to:
  /// **' • Threshold {threshold}'**
  String enterpriseThresholdSuffix(String threshold);

  /// No description provided for @enterpriseAutoSweepDisabledStatus.
  ///
  /// In en, this message translates to:
  /// **'Auto-sweep disabled'**
  String get enterpriseAutoSweepDisabledStatus;

  /// No description provided for @enterpriseAutoSweepConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-sweep configuration'**
  String get enterpriseAutoSweepConfigurationTitle;

  /// No description provided for @enterpriseAllClearTitle.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get enterpriseAllClearTitle;

  /// No description provided for @enterpriseNoBudgetAlertsMessage.
  ///
  /// In en, this message translates to:
  /// **'No budget alerts right now.'**
  String get enterpriseNoBudgetAlertsMessage;

  /// No description provided for @enterpriseBudgetAlertFallback.
  ///
  /// In en, this message translates to:
  /// **'Budget alert'**
  String get enterpriseBudgetAlertFallback;

  /// No description provided for @enterpriseBudgetAlertUpper.
  ///
  /// In en, this message translates to:
  /// **'BUDGET ALERT'**
  String get enterpriseBudgetAlertUpper;

  /// No description provided for @enterpriseNoApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'No approvals'**
  String get enterpriseNoApprovalsTitle;

  /// No description provided for @enterpriseNothingPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing pending right now.'**
  String get enterpriseNothingPendingMessage;

  /// No description provided for @enterpriseTreasuryApprovalFallback.
  ///
  /// In en, this message translates to:
  /// **'Treasury approval'**
  String get enterpriseTreasuryApprovalFallback;

  /// No description provided for @enterpriseIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String enterpriseIdLabel(String id);

  /// No description provided for @wealthSharedPotsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load shared pots.'**
  String get wealthSharedPotsLoadError;

  /// No description provided for @wealthNewSharedPot.
  ///
  /// In en, this message translates to:
  /// **'New shared pot'**
  String get wealthNewSharedPot;

  /// No description provided for @wealthSharedGoalShort.
  ///
  /// In en, this message translates to:
  /// **'Keep money together for one shared goal.'**
  String get wealthSharedGoalShort;

  /// No description provided for @wealthPotName.
  ///
  /// In en, this message translates to:
  /// **'Pot name'**
  String get wealthPotName;

  /// No description provided for @wealthPotNameHint.
  ///
  /// In en, this message translates to:
  /// **'Example School fees'**
  String get wealthPotNameHint;

  /// No description provided for @wealthPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get wealthPurpose;

  /// No description provided for @wealthPurposeHint.
  ///
  /// In en, this message translates to:
  /// **'Family, team, business'**
  String get wealthPurposeHint;

  /// No description provided for @wealthTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get wealthTargetAmount;

  /// No description provided for @wealthAccessModel.
  ///
  /// In en, this message translates to:
  /// **'Access model'**
  String get wealthAccessModel;

  /// No description provided for @wealthEnterPotNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter the pot name first.'**
  String get wealthEnterPotNameFirst;

  /// No description provided for @wealthCreateSharedPotError.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the shared pot.'**
  String get wealthCreateSharedPotError;

  /// No description provided for @wealthSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get wealthSaving;

  /// No description provided for @wealthSavePot.
  ///
  /// In en, this message translates to:
  /// **'Save pot'**
  String get wealthSavePot;

  /// No description provided for @wealthSharedPotCreated.
  ///
  /// In en, this message translates to:
  /// **'Shared pot created.'**
  String get wealthSharedPotCreated;

  /// No description provided for @wealthEditSharedPot.
  ///
  /// In en, this message translates to:
  /// **'Edit shared pot'**
  String get wealthEditSharedPot;

  /// No description provided for @wealthUpdateSharedPotError.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the shared pot.'**
  String get wealthUpdateSharedPotError;

  /// No description provided for @wealthSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get wealthSaveChanges;

  /// No description provided for @wealthSharedPotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shared pot updated.'**
  String get wealthSharedPotUpdated;

  /// No description provided for @wealthContributeToSharedPot.
  ///
  /// In en, this message translates to:
  /// **'Contribute to shared pot'**
  String get wealthContributeToSharedPot;

  /// No description provided for @wealthContributeToPotHelp.
  ///
  /// In en, this message translates to:
  /// **'Add money from your wallet into this pot.'**
  String get wealthContributeToPotHelp;

  /// No description provided for @wealthAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get wealthAmount;

  /// No description provided for @wealthEnterAmountFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount first.'**
  String get wealthEnterAmountFirst;

  /// No description provided for @wealthContributeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to add the contribution.'**
  String get wealthContributeError;

  /// No description provided for @wealthContributeNow.
  ///
  /// In en, this message translates to:
  /// **'Contribute now'**
  String get wealthContributeNow;

  /// No description provided for @wealthContributionAdded.
  ///
  /// In en, this message translates to:
  /// **'Contribution added.'**
  String get wealthContributionAdded;

  /// No description provided for @wealthWithdrawFromSharedPot.
  ///
  /// In en, this message translates to:
  /// **'Withdraw from shared pot'**
  String get wealthWithdrawFromSharedPot;

  /// No description provided for @wealthWithdrawFromPotHelp.
  ///
  /// In en, this message translates to:
  /// **'Move money from this pot back to your wallet.'**
  String get wealthWithdrawFromPotHelp;

  /// No description provided for @wealthWithdrawError.
  ///
  /// In en, this message translates to:
  /// **'Unable to withdraw from the shared pot.'**
  String get wealthWithdrawError;

  /// No description provided for @wealthWithdrawNow.
  ///
  /// In en, this message translates to:
  /// **'Withdraw now'**
  String get wealthWithdrawNow;

  /// No description provided for @wealthFundsWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Funds withdrawn.'**
  String get wealthFundsWithdrawn;

  /// No description provided for @wealthInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite member'**
  String get wealthInviteMember;

  /// No description provided for @wealthInviteMemberHelp.
  ///
  /// In en, this message translates to:
  /// **'Send an invitation using the member\'s ORBI phone number or email.'**
  String get wealthInviteMemberHelp;

  /// No description provided for @wealthPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone or email'**
  String get wealthPhoneOrEmail;

  /// No description provided for @wealthRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get wealthRole;

  /// No description provided for @wealthEnterPhoneOrEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter phone or email first.'**
  String get wealthEnterPhoneOrEmailFirst;

  /// No description provided for @wealthInviteError.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the invitation.'**
  String get wealthInviteError;

  /// No description provided for @wealthSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get wealthSendInvite;

  /// No description provided for @wealthInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent.'**
  String get wealthInviteSent;

  /// No description provided for @wealthLoadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading members...'**
  String get wealthLoadingMembers;

  /// No description provided for @wealthPotMembers.
  ///
  /// In en, this message translates to:
  /// **'Pot members'**
  String get wealthPotMembers;

  /// No description provided for @wealthPotMembersHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone with access to this pot.'**
  String get wealthPotMembersHelp;

  /// No description provided for @wealthNoMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get wealthNoMembersYet;

  /// No description provided for @wealthSendFirstInvite.
  ///
  /// In en, this message translates to:
  /// **'Send the first invitation for this pot.'**
  String get wealthSendFirstInvite;

  /// No description provided for @wealthUpdatingStatus.
  ///
  /// In en, this message translates to:
  /// **'Updating status...'**
  String get wealthUpdatingStatus;

  /// No description provided for @wealthPotStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Pot status updated.'**
  String get wealthPotStatusUpdated;

  /// No description provided for @wealthSharedPotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared Pots'**
  String get wealthSharedPotsTitle;

  /// No description provided for @wealthNewPot.
  ///
  /// In en, this message translates to:
  /// **'New pot'**
  String get wealthNewPot;

  /// No description provided for @wealthSharedMoneyOrganized.
  ///
  /// In en, this message translates to:
  /// **'Shared money, clearly organised'**
  String get wealthSharedMoneyOrganized;

  /// No description provided for @wealthSharedMoneyHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep money together for one shared goal. Example: family, school fees, or a business team.'**
  String get wealthSharedMoneyHelp;

  /// No description provided for @wealthSharedPotsLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared pots could not be loaded'**
  String get wealthSharedPotsLoadTitle;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @wealthNoSharedPotYet.
  ///
  /// In en, this message translates to:
  /// **'No shared pot yet'**
  String get wealthNoSharedPotYet;

  /// No description provided for @wealthNoSharedPotMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a pot for family, school fees, or your business team.'**
  String get wealthNoSharedPotMessage;

  /// No description provided for @wealthCreatePot.
  ///
  /// In en, this message translates to:
  /// **'Create pot'**
  String get wealthCreatePot;

  /// No description provided for @wealthContribute.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get wealthContribute;

  /// No description provided for @wealthMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get wealthMembers;

  /// No description provided for @wealthWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get wealthWithdraw;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get commonActivate;

  /// No description provided for @commonArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commonArchive;

  /// No description provided for @wealthContributedLabel.
  ///
  /// In en, this message translates to:
  /// **'Contributed {value}'**
  String wealthContributedLabel(String value);

  /// No description provided for @wealthContributedTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Contributed {contributed} / Target {target}'**
  String wealthContributedTargetLabel(String contributed, String target);

  /// No description provided for @wealthTargetChip.
  ///
  /// In en, this message translates to:
  /// **'Target {value}'**
  String wealthTargetChip(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
