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
    final bool isOffline     = attemptData['offline'] == true;
    final int totalQuestions = attemptData['totalQuestions'] ?? 0;
    final int answeredCount  = attemptData['answeredCount']  ?? 0;
    final int skippedCount   = attemptData['skippedCount']   ?? 0;
    final double score       = (attemptData['score']       ?? 0).toDouble();
    final double totalPoints = (attemptData['totalPoints'] ?? 0).toDouble();
    final int percent        = totalQuestions > 0
        ? (answeredCount / totalQuestions * 100).round() : 0;

    final Color mainColor = isOffline ? const Color(0xFFE65100) : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),

            // ── Offline notice ─────────────────────────────────────────────
            if (isOffline)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Saved offline. Your answers will automatically sync to the server when you reconnect.',
                      style: TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ]),
              ),

            // ── Icon ──────────────────────────────────────────────────────
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mainColor.withValues(alpha: 0.12),
                border: Border.all(color: mainColor, width: 2.5),
              ),
              child: Icon(
                isOffline ? Icons.cloud_done_outlined : Icons.check_circle_outline,
                color: mainColor,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              isOffline ? 'Saved Offline!' : 'Quiz Submitted!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(quiz.title,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── Stats row ─────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _StatCard(label: 'Total',    value: '$totalQuestions', color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Answered', value: '$answeredCount',  color: AppColors.correct)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Skipped',  value: '$skippedCount',   color: const Color(0xFFFF7043))),
            ]),
            const SizedBox(height: 20),

            // ── Score + completion card ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [

                // Score row (only show if online and has points)
                if (!isOffline && totalPoints > 0) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Score', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      '${score.toStringAsFixed(1)} / ${totalPoints.toStringAsFixed(1)} pts',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalPoints > 0 ? score / totalPoints : 0,
                      minHeight: 8,
                      backgroundColor: AppColors.cardBg,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                ],

                // Completion ring
                const Text('Completion Rate',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 150, height: 150,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress:      totalQuestions > 0 ? answeredCount / totalQuestions : 0,
                      trackColor:    AppColors.cardBg,
                      progressColor: mainColor,
                      strokeWidth:   14,
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$percent%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            )),
                        Text('done',
                            style: TextStyle(
                              fontSize: 12,
                              color: mainColor.withValues(alpha: 0.7),
                            )),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOffline
                        ? '⏳ Will sync when back online'
                        : skippedCount == 0
                        ? '🎉 All questions answered!'
                        : '$skippedCount question${skippedCount > 1 ? 's' : ''} unanswered',
                    style: TextStyle(
                      fontSize: 13,
                      color: mainColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Back to Home ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text('Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress, strokeWidth;
  final Color trackColor, progressColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint  = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        paint..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}