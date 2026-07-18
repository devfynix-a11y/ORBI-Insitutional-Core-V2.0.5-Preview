import 'package:flutter/foundation.dart';

import '../../../core/state/app_runtime_cache.dart';
import '../../../core/utils/user_facing_error.dart';
import '../data/goals_service.dart';

class GoalsController extends ChangeNotifier {
  GoalsController({GoalsService? service})
    : _service = service ?? GoalsService();

  final GoalsService _service;

  List<Map<String, dynamic>> _goals = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _tasks = const [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get goals => _goals;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll(String token, {bool notify = true}) async {
    _isLoading = true;
    _error = null;
    if (notify) notifyListeners();

    try {
      final cachedGoals = AppRuntimeCache.goals;
      final cachedCategories = AppRuntimeCache.categories;
      final cachedTasks = AppRuntimeCache.tasks;
      if (cachedGoals != null ||
          cachedCategories != null ||
          cachedTasks != null) {
        _goals = _sortGoals(cachedGoals ?? const <Map<String, dynamic>>[]);
        _categories = _sortCategories(
          cachedCategories ?? const <Map<String, dynamic>>[],
        );
        _tasks = _sortTasks(cachedTasks ?? const <Map<String, dynamic>>[]);
        _isLoading = false;
        _error = null;
        if (notify) notifyListeners();
        return;
      }

      final results = await Future.wait<_LoadResult>([
        _loadCollection(() => _service.fetchGoals(token), fallback: 'goals'),
        _loadCollection(
          () => _service.fetchCategories(token),
          fallback: 'budgets',
        ),
        _loadCollection(() => _service.fetchTasks(token), fallback: 'tasks'),
      ]);
      final goalsResult = results[0];
      final categoriesResult = results[1];
      final tasksResult = results[2];

      _goals = _sortGoals(goalsResult.items);
      _categories = _sortCategories(categoriesResult.items);
      _tasks = _sortTasks(tasksResult.items);

      final failures = [
        goalsResult.error,
        categoriesResult.error,
        tasksResult.error,
      ].whereType<String>().toList();

      if (failures.isNotEmpty) {
        _error = failures.first;
      }
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load your goals and budgets right now.',
      );
    } finally {
      _isLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<_LoadResult> _loadCollection(
    Future<List<Map<String, dynamic>>> Function() loader, {
    required String fallback,
  }) async {
    try {
      final items = await loader().timeout(const Duration(seconds: 8));
      return _LoadResult(items: items);
    } catch (e) {
      return _LoadResult(
        items: const [],
        error: UserFacingError.from(
          e,
          fallback: 'Unable to load $fallback right now.',
        ),
      );
    }
  }

  Future<void> createGoal(String token, Map<String, dynamic> payload) async {
    await _service.createGoal(token, payload);
    await _refreshGoals(token);
    notifyListeners();
  }

  Future<void> updateGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    await _service.updateGoal(token, goalId, payload);
    await _refreshGoals(token);
    notifyListeners();
  }

  Future<void> allocateGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    await _service.allocateGoal(token, goalId, payload);
    await _refreshGoals(token);
    notifyListeners();
  }

  Future<void> withdrawGoal(
    String token,
    String goalId,
    Map<String, dynamic> payload,
  ) async {
    await _service.withdrawGoal(token, goalId, payload);
    await _refreshGoals(token);
    notifyListeners();
  }

  Future<void> deleteGoal(String token, String goalId) async {
    await _service.deleteGoal(token, goalId);
    _goals = _goals.where((goal) => _readId(goal) != goalId).toList();
    notifyListeners();
  }

  Future<void> createCategory(
    String token,
    Map<String, dynamic> payload,
  ) async {
    await _service.createCategory(token, payload);
    await _refreshCategories(token);
    notifyListeners();
  }

  Future<void> updateCategory(
    String token,
    String categoryId,
    Map<String, dynamic> payload,
  ) async {
    await _service.updateCategory(token, categoryId, payload);
    await _refreshCategories(token);
    notifyListeners();
  }

  Future<void> deleteCategory(String token, String categoryId) async {
    await _service.deleteCategory(token, categoryId);
    _categories = _categories
        .where((category) => _readId(category) != categoryId)
        .toList();
    notifyListeners();
  }

  Future<void> createTask(String token, Map<String, dynamic> payload) async {
    await _service.createTask(token, payload);
    await _refreshTasks(token);
    notifyListeners();
  }

  Future<void> updateTask(
    String token,
    String taskId,
    Map<String, dynamic> payload,
  ) async {
    await _service.updateTask(token, taskId, payload);
    await _refreshTasks(token);
    notifyListeners();
  }

  Future<void> deleteTask(String token, String taskId) async {
    await _service.deleteTask(token, taskId);
    _tasks = _tasks.where((task) => _readId(task) != taskId).toList();
    notifyListeners();
  }

  List<Map<String, dynamic>> _sortGoals(List<Map<String, dynamic>> items) {
    final copy = [...items];
    copy.sort((a, b) => _readName(a).compareTo(_readName(b)));
    return copy;
  }

  List<Map<String, dynamic>> _sortCategories(List<Map<String, dynamic>> items) {
    final copy = [...items];
    copy.sort((a, b) => _readName(a).compareTo(_readName(b)));
    return copy;
  }

  List<Map<String, dynamic>> _sortTasks(List<Map<String, dynamic>> items) {
    final copy = [...items];
    copy.sort((a, b) {
      final aCompleted = _readBool(a, ['completed']);
      final bCompleted = _readBool(b, ['completed']);
      if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
      return _readTaskText(a).compareTo(_readTaskText(b));
    });
    return copy;
  }

  String _readName(Map<String, dynamic> item) {
    return (item['name'] ?? '').toString().toLowerCase();
  }

  String _readTaskText(Map<String, dynamic> item) {
    return (item['text'] ?? item['title'] ?? '').toString().toLowerCase();
  }

  bool _readBool(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return false;
  }

  String _readId(Map<String, dynamic> item) {
    return (item['id'] ??
            item['goalId'] ??
            item['goal_id'] ??
            item['categoryId'] ??
            item['category_id'] ??
            item['taskId'] ??
            item['task_id'] ??
            '')
        .toString();
  }

  Future<void> _refreshGoals(String token) async {
    _goals = _sortGoals(await _service.fetchGoals(token));
    _error = null;
  }

  Future<void> _refreshCategories(String token) async {
    _categories = _sortCategories(await _service.fetchCategories(token));
    _error = null;
  }

  Future<void> _refreshTasks(String token) async {
    _tasks = _sortTasks(await _service.fetchTasks(token));
    _error = null;
  }
}

class _LoadResult {
  const _LoadResult({required this.items, this.error});

  final List<Map<String, dynamic>> items;
  final String? error;
}
