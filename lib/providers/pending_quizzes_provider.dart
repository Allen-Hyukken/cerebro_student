import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/db_service.dart';

// ── Pending quiz model ────────────────────────────────────────────────────────

class PendingQuiz {
  final QuizModel quiz;
  final String    classroomName;

  const PendingQuiz({required this.quiz, required this.classroomName});
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PendingQuizzesNotifier
    extends AsyncNotifier<List<PendingQuiz>> {
  @override
  Future<List<PendingQuiz>> build() => _fetch();

  Future<List<PendingQuiz>> _fetch() async {
    final userId = ApiService.userId;
    if (userId == null) return [];

    // Load all classrooms from local cache (works offline too)
    final classrooms = await DbService.getClassrooms();
    final pending    = <PendingQuiz>[];

    for (final c in classrooms) {
      final classroomId   = c['id'] as int;
      final classroomName = (c['name'] as String?) ?? '';
      final quizRows      = await DbService.getQuizzes(classroomId);

      for (final q in quizRows) {
        final quizId    = q['id'] as int;
        final published = (q['published'] ?? 0) == 1;
        if (!published) continue;

        // Skip already-submitted quizzes
        final submitted = await DbService.isQuizSubmitted(quizId, userId);
        if (submitted) continue;

        // Build QuizModel from the SQLite row
        final quiz = QuizModel(
          id:               quizId,
          title:            (q['title'] as String?) ?? '',
          description:      q['description'] as String?,
          classRoomId:      classroomId,
          classRoomName:    classroomName,
          teacherName:      q['teacherName'] as String?,
          questionCount:    (q['questionCount'] as int?) ?? 0,
          totalPoints:      ((q['totalPoints'] ?? 0) as num).toDouble(),
          createdAt:        q['createdAt'] as String?,
          timeLimitMinutes: q['timeLimitMinutes'] as int?,
          deadline:         q['deadline'] as String?,
          showAnswers:      (q['showAnswers'] ?? 0) == 1,
        );

        // Skip if deadline has passed
        if (quiz.isDeadlinePassed) continue;

        pending.add(PendingQuiz(quiz: quiz, classroomName: classroomName));
      }
    }

    return pending;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final pendingQuizzesProvider =
AsyncNotifierProvider<PendingQuizzesNotifier, List<PendingQuiz>>(
  PendingQuizzesNotifier.new,
);