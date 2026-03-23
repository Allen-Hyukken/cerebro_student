import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/screens/home_screen.dart';
import 'package:quiz_app/screens/review_screen.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/xp_service.dart';
import 'package:quiz_app/widgets/xp_popup.dart';
import 'package:quiz_app/services/sound_service.dart';

class ResultScreen extends StatefulWidget {
  final QuizModel quiz;
  final Map<String, dynamic> attemptData;
  const ResultScreen({super.key, required this.quiz, required this.attemptData});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scoreAnimController;
  late AnimationController _cardAnimController;
  late Animation<double> _scoreAnim;
  late Animation<double> _cardFadeAnim;
  late Animation<Offset>  _cardSlideAnim;

  @override
  void initState() {
    super.initState();

    _confettiController  = ConfettiController(duration: const Duration(seconds: 4));
    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardAnimController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scoreAnim     = CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutCubic);
    _cardFadeAnim  = CurvedAnimation(parent: _cardAnimController,  curve: Curves.easeIn);
    _cardSlideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _cardAnimController.forward(); });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _scoreAnimController.forward(); });
    // Play finish sound
    SoundService().stopBackground();
    if (widget.attemptData['offline'] != true) SoundService().playFinish();

    final isOffline   = widget.attemptData['offline'] == true;
    final score       = (widget.attemptData['score']       ?? 0).toDouble();
    final totalPoints = (widget.attemptData['totalPoints'] ?? 0).toDouble();
    final percent     = totalPoints > 0 ? (score / totalPoints * 100) : 0;

    // Fire confetti if score >= 50%
    if (!isOffline && percent >= 50) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _confettiController.play();
      });
    }

    // Show XP popup after 1.5s
    if (isOffline != true) {
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (!mounted) return;
        final uid       = ApiService.userId ?? 0;
        final xpService = XpService();
        final newXp     = await xpService.getXp(uid);
        final xpEarned  = xpService.calculateQuizXp(score, totalPoints);
        final oldXp     = (newXp - xpEarned).clamp(0, newXp);
        if (mounted) {
          await XpPopup.show(context,
              xpEarned: xpEarned, oldXp: oldXp, newXp: newXp);
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scoreAnimController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = widget.attemptData['offline'] == true;
    final int totalQuestions = widget.attemptData['totalQuestions'] ?? 0;
    final int answeredCount  = widget.attemptData['answeredCount']  ?? 0;
    final int skippedCount   = widget.attemptData['skippedCount']   ?? 0;
    final double score       = (widget.attemptData['score']       ?? 0).toDouble();
    final double totalPoints = (widget.attemptData['totalPoints'] ?? 0).toDouble();

    final List<dynamic> answers = widget.attemptData['answers'] ?? [];
    final int correctCount = answers.where((a) => a['correct'] == true).length;
    final int wrongCount   = answers.where((a) =>
    (a['givenText'] != null || a['choiceId'] != null) && a['correct'] == false).length;

    final int percent = totalPoints > 0
        ? (score / totalPoints * 100).round()
        : totalQuestions > 0 ? (answeredCount / totalQuestions * 100).round() : 0;

    final Color mainColor = isOffline
        ? const Color(0xFFE65100)
        : percent >= 75 ? AppColors.correct
        : percent >= 50 ? Colors.orange
        : AppColors.wrong;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: Stack(children: [

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.3,
            colors: const [AppColors.primary, AppColors.correct, AppColors.confirm,
              Colors.orange, Colors.yellow, AppColors.primaryLight],
            createParticlePath: (size) {
              final path = Path();
              final r  = size.width / 2;
              final rn = r * 0.4;
              for (int i = 0; i < 5; i++) {
                final angle      = (i * 4 * pi / 5) - pi / 2;
                final innerAngle = angle + 2 * pi / 10;
                if (i == 0) path.moveTo(r + r * cos(angle), r + r * sin(angle));
                else        path.lineTo(r + r * cos(angle), r + r * sin(angle));
                path.lineTo(r + rn * cos(innerAngle), r + rn * sin(innerAngle));
              }
              path.close();
              return path;
            },
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _cardFadeAnim,
              child: SlideTransition(
                position: _cardSlideAnim,
                child: Column(children: [
                  const SizedBox(height: 16),

                  // Offline notice
                  if (isOffline)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFB74D))),
                      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.cloud_upload_outlined, color: Color(0xFFE65100), size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                            'Saved offline. Your answers will sync automatically when you reconnect.',
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 12, height: 1.5))),
                      ]),
                    ),

                  // Emoji + title
                  Text(
                      isOffline ? '📤' : percent >= 90 ? '🏆' : percent >= 75 ? '🎉' : percent >= 50 ? '👍' : '💪',
                      style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                      isOffline ? 'Saved Offline!'
                          : percent >= 90 ? 'Outstanding!'
                          : percent >= 75 ? 'Great Job!'
                          : percent >= 50 ? 'Good Effort!'
                          : 'Keep Practicing!',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: TC.text(context))),
                  const SizedBox(height: 6),
                  Text(widget.quiz.title,
                      style: TextStyle(fontSize: 15, color: TC.subText(context)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),

                  // Stats
                  answers.isNotEmpty
                      ? Row(children: [
                    Expanded(child: _StatCard(label: 'Correct', value: '$correctCount', color: AppColors.correct)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(label: 'Wrong',   value: '$wrongCount',   color: AppColors.wrong)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(label: 'Skipped', value: '$skippedCount', color: const Color(0xFFFF7043))),
                  ])
                      : Row(children: [
                    Expanded(child: _StatCard(label: 'Total',    value: '$totalQuestions', color: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Answered', value: '$answeredCount',  color: AppColors.correct)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Skipped',  value: '$skippedCount',   color: const Color(0xFFFF7043))),
                  ]),
                  const SizedBox(height: 20),

                  // Score card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: TC.surface(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.2 : 0.05),
                            blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(children: [

                      if (!isOffline && totalPoints > 0) ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Score', style: TextStyle(fontSize: 14, color: TC.subText(context))),
                          AnimatedBuilder(
                            animation: _scoreAnim,
                            builder: (_, __) => Text(
                                '${(score * _scoreAnim.value).toStringAsFixed(1)} / ${totalPoints.toStringAsFixed(1)} pts',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TC.text(context))),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: totalPoints > 0 ? (score / totalPoints) * _scoreAnim.value : 0,
                                minHeight: 10,
                                backgroundColor: TC.card(context),
                                valueColor: AlwaysStoppedAnimation<Color>(mainColor)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(height: 1, color: TC.divider(context)),
                        const SizedBox(height: 24),
                      ],

                      // Ring
                      Text(
                          isOffline ? 'Completion' : totalPoints > 0 ? 'Score' : 'Completion',
                          style: TextStyle(fontSize: 14, color: TC.subText(context))),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 150, height: 150,
                        child: AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => CustomPaint(
                            painter: _RingPainter(
                              progress: isOffline
                                  ? (totalQuestions > 0 ? (answeredCount / totalQuestions) * _scoreAnim.value : 0)
                                  : totalPoints > 0
                                  ? (score / totalPoints) * _scoreAnim.value
                                  : (totalQuestions > 0 ? (answeredCount / totalQuestions) * _scoreAnim.value : 0),
                              trackColor:    TC.card(context),
                              progressColor: mainColor,
                              strokeWidth:   14,
                            ),
                            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('$percent%', style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold, color: mainColor)),
                              Text(isOffline ? 'done' : totalPoints > 0 ? 'score' : 'done',
                                  style: TextStyle(fontSize: 12, color: mainColor.withValues(alpha: 0.7))),
                            ])),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: mainColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            isOffline ? '⏳ Will sync when back online'
                                : answers.isNotEmpty
                                ? '$correctCount correct · $wrongCount wrong · $skippedCount skipped'
                                : skippedCount == 0 ? '🎉 All questions answered!'
                                : '$skippedCount question${skippedCount > 1 ? 's' : ''} unanswered',
                            style: TextStyle(fontSize: 13, color: mainColor, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 28),

                  // Review button
                  if (isOffline != true) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Map<String, dynamic> reviewData = widget.attemptData;
                          if (answers.isEmpty) {
                            try {
                              final id = widget.attemptData['attemptId'] ?? widget.attemptData['id'];
                              if (id != null && id != -1) {
                                reviewData = await ApiService.getAttempt(id);
                              }
                            } catch (_) {}
                          }
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ReviewScreen(attemptData: reviewData)));
                        },
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Review Answers',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Back to home
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                      child: const Text('Back to Home',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
    ]),
  );
}

class _RingPainter extends CustomPainter {
  final double progress, strokeWidth;
  final Color trackColor, progressColor;
  _RingPainter({required this.progress, required this.trackColor,
    required this.progressColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint  = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          -pi / 2, 2 * pi * progress, false, paint..color = progressColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}