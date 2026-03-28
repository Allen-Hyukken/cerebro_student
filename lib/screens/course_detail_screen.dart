import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/providers/quizzes_provider.dart';
import 'package:quiz_app/screens/quiz_intro_screen.dart';

class CourseDetailScreen extends ConsumerWidget {
  final ClassroomModel classroom;
  const CourseDetailScreen({super.key, required this.classroom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(classroomQuizzesProvider(classroom.id));

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: TC.text(context)),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: TC.surface(context),
                ),
                child: ClipOval(child: Image.asset(
                  'assets/icons/logo.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.psychology, size: 20, color: AppColors.primary,
                  ),
                )),
              ),
              const SizedBox(width: 12),
            ]),
          ),

          // ── Classroom header card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 10, offset: const Offset(0, 4),
                )],
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final half = constraints.maxWidth / 2;
                return Row(children: [
                  SizedBox(
                    width: half,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            classroom.name,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold, fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Icon(Icons.tag, size: 14,
                                color: TC.subText(context)),
                            const SizedBox(width: 4),
                            Text(
                              'Code: ${classroom.code}',
                              style: TextStyle(
                                color: TC.subText(context), fontSize: 13,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 5),
                          Row(children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(child: Text(
                              'Teacher: ${classroom.teacherName ?? ""}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13, fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: classroom.hasBanner && ApiService.token != null
                        ? Image.network(
                      ApiService.getBannerUrlSync(classroom.id),
                      width: half, height: 150, fit: BoxFit.cover,
                      headers: {
                        'Authorization': 'Bearer ${ApiService.token}',
                      },
                      errorBuilder: (_, __, ___) =>
                          _gradientBox(half),
                    )
                        : _gradientBox(half),
                  ),
                ]);
              }),
            ),
          ),

          const SizedBox(height: 16),

          // ── Quiz grid ─────────────────────────────────────────────────────
          Expanded(
            child: quizzesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: TC.subText(context), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load quizzes.',
                      style: TextStyle(color: TC.subText(context)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(classroomQuizzesProvider(classroom.id).notifier)
                          .reload(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (allQuizzes) {
                // ── Filter: students only see ACTIVE quizzes ───────────────
                // Flask already returns only ACTIVE quizzes, but we guard
                // here too in case a cached/offline response slips through.
                final quizzes = allQuizzes
                    .where((q) => q.isActive)
                    .toList();

                if (quizzes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.quiz_outlined,
                            color: TC.subText(context), size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No quizzes available yet.',
                          style: TextStyle(
                            color: TC.subText(context), fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your teacher hasn\'t deployed any quizzes.',
                          style: TextStyle(
                            color: TC.subText(context), fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(classroomQuizzesProvider(classroom.id).notifier)
                      .reload(),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: quizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = quizzes[index];
                      return _QuizCard(
                        quiz: quiz,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizIntroScreen(quiz: quiz),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _gradientBox(double width) => Container(
    width: width, height: 150,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.darkCard],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.school, color: Colors.white54, size: 60),
  );
}

// ── Quiz card ─────────────────────────────────────────────────────────────────

class _QuizCard extends StatelessWidget {
  final QuizModel    quiz;
  final VoidCallback onTap;
  const _QuizCard({required this.quiz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Only ACTIVE quizzes reach here, but guard anyway
    final isAvailable = quiz.isActive && !quiz.isDeadlinePassed;

    return GestureDetector(
      onTap: isAvailable ? onTap : () => _showUnavailableSnack(context),
      child: Container(
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(14),
          border: quiz.isDeadlinePassed
              ? Border.all(color: AppColors.wrong.withValues(alpha: 0.4))
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Deadline expired badge ─────────────────────────────────────
            if (quiz.isDeadlinePassed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.wrong.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_clock, size: 11, color: AppColors.wrong),
                  SizedBox(width: 4),
                  Text('Closed', style: TextStyle(
                    fontSize: 10, color: AppColors.wrong, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),

            Text(
              quiz.title,
              style: TextStyle(
                color: quiz.isDeadlinePassed
                    ? TC.subText(context)
                    : AppColors.primary,
                fontWeight: FontWeight.bold, fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis, maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.quiz_outlined, size: 14, color: TC.subText(context)),
              const SizedBox(width: 4),
              Text(
                '${quiz.questionCount} Questions',
                style: TextStyle(color: TC.subText(context), fontSize: 12),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.star_outline, size: 14, color: TC.subText(context)),
              const SizedBox(width: 4),
              Text(
                '${quiz.totalPoints} pts',
                style: TextStyle(color: TC.subText(context), fontSize: 12),
              ),
            ]),

            // ── Deadline badge ─────────────────────────────────────────────
            if (quiz.deadlineDateTime != null && !quiz.isDeadlinePassed) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: Colors.orange.shade400),
                const SizedBox(width: 3),
                Flexible(child: Text(
                  _formatDeadline(quiz.deadlineDateTime!),
                  style: TextStyle(
                    fontSize: 10, color: Colors.orange.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime dt) {
    final now  = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'Due ${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showUnavailableSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('This quiz is no longer available.'),
      backgroundColor: AppColors.wrong,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }
}