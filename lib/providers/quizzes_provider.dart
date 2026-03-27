import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';

// ── Notifier ──────────────────────────────────────────────────────────────────

class QuizzesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<QuizModel>, int> {
  @override
  Future<List<QuizModel>> build(int classroomId) => _fetch(classroomId);

  Future<List<QuizModel>> _fetch(int classroomId) async {
    final data = await ApiService.getClassroomQuizzes(classroomId);
    return data.map((j) => QuizModel.fromJson(j)).toList();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Usage: `ref.watch(classroomQuizzesProvider(classroom.id))`
/// Auto-disposes when CourseDetailScreen is popped.
final classroomQuizzesProvider = AsyncNotifierProvider.autoDispose
    .family<QuizzesNotifier, List<QuizModel>, int>(QuizzesNotifier.new);