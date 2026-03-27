import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';

// ── Async notifier ────────────────────────────────────────────────────────────

class ClassroomsNotifier extends AsyncNotifier<List<ClassroomModel>> {
  @override
  Future<List<ClassroomModel>> build() => _fetch();

  Future<List<ClassroomModel>> _fetch() async {
    final data = await ApiService.getMyClassrooms();
    return data.map((j) => ClassroomModel.fromJson(j)).toList();
  }

  /// Hard reload — shows loading indicator.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Sync pending offline attempts then reload classrooms.
  Future<void> syncAndReload() async {
    try { await ApiService.syncPendingAttempts(); } catch (_) {}
    await reload();
  }
}

// ── Search state ──────────────────────────────────────────────────────────────

/// Raw search query typed in the HomeScreen search bar.
final classroomSearchProvider = StateProvider<String>((ref) => '');

// ── Providers ─────────────────────────────────────────────────────────────────

final classroomsProvider =
AsyncNotifierProvider<ClassroomsNotifier, List<ClassroomModel>>(
  ClassroomsNotifier.new,
);

/// Derived filtered classroom list — combine list + search query.
final filteredClassroomsProvider = Provider<List<ClassroomModel>>((ref) {
  final classroomsAsync = ref.watch(classroomsProvider);
  final query           = ref.watch(classroomSearchProvider).toLowerCase();

  return classroomsAsync.when(
    data: (classrooms) {
      if (query.isEmpty) return classrooms;
      return classrooms.where((c) =>
      c.name.toLowerCase().contains(query)  ||
          c.code.toLowerCase().contains(query)  ||
          (c.teacherName?.toLowerCase().contains(query) ?? false)
      ).toList();
    },
    loading: () => [],
    error:   (_, __) => [],
  );
});