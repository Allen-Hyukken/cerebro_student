import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/screens/home_screen.dart';

class ResultScreen extends StatelessWidget {
  final QuizModel quiz;
  final Map<String, dynamic> attemptData;

  const ResultScreen({super.key, required this.quiz, required this.attemptData});

  @override
  Widget build(BuildContext context) {
    final int totalQuestions  = attemptData['totalQuestions'] ?? 0;
    final int answeredCount   = attemptData['answeredCount']  ?? 0;
    final int skippedCount    = attemptData['skippedCount']   ?? 0;
    final double score        = (attemptData['score'] ?? 0).toDouble();
    final double totalPoints  = (attemptData['totalPoints'] ?? 0).toDouble();
    final int percent         = totalQuestions > 0 ? (answeredCount / totalQuestions * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 30),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.15), border: Border.all(color: AppColors.primary, width: 2)),
              child: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Quiz Submitted!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(quiz.title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            // Stats
            Row(children: [
              Expanded(child: _StatCard(label: 'Total',    value: '$totalQuestions', color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Answered', value: '$answeredCount',  color: AppColors.correct)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Skipped',  value: '$skippedCount',   color: AppColors.confirm)),
            ]),
            const SizedBox(height: 24),
            // Score + completion rate
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                // Score
                if (totalPoints > 0) ...[
                  Text('Score', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('${score.toStringAsFixed(1)} / ${totalPoints.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                ],
                // Completion circle
                const Text('Completion Rate', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 140, height: 140,
                  child: CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: totalQuestions > 0 ? answeredCount / totalQuestions : 0,
                      trackColor: AppColors.cardBg,
                      progressColor: AppColors.primary,
                      strokeWidth: 12,
                    ),
                    child: Center(child: Text('$percent%',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary))),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  skippedCount == 0 ? '🎉 You answered all questions!' : '$skippedCount question${skippedCount > 1 ? 's' : ''} unanswered',
                  style: TextStyle(fontSize: 13, color: skippedCount == 0 ? AppColors.correct : Colors.orange, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor, progressColor;
  final double strokeWidth;

  _CircleProgressPainter({required this.progress, required this.trackColor, required this.progressColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(center, radius, Paint()..color = trackColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()..color = progressColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}