import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/quiz_screen.dart';
import 'package:quiz_app/screens/leaderboard_screen.dart';

class QuizIntroScreen extends StatefulWidget {
  final QuizModel quiz;
  const QuizIntroScreen({super.key, required this.quiz});

  @override
  State<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends State<QuizIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _countdownController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  bool _isStarting       = false;
  int  _countdown        = 3;
  bool _alreadySubmitted = false;
  bool _deadlinePassed   = false;
  List<QuestionModel> _questions = [];
  bool _isLoading = true;

  // Student's score when already submitted
  double? _myScore;
  double? _myTotalPoints;

  @override
  void initState() {
    super.initState();

    _fadeController      = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _countdownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _fadeAnim  = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });

    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final deadlinePassed = widget.quiz.isDeadlinePassed;

      // ── Check already submitted + fetch the student's score ───────────
      bool alreadySubmitted = false;
      double? myScore;
      double? myTotalPoints;

      try {
        final attempts = await ApiService.getMyAttempts();
        // Find the attempt that matches this quiz
        Map<String, dynamic>? match;
        for (final a in attempts) {
          final id = a['quizId'] ?? a['quiz_id'];
          if (id != null && id.toString() == widget.quiz.id.toString()) {
            match = a;
            break;
          }
        }
        if (match != null) {
          alreadySubmitted = true;
          myScore       = (match['score']       ?? 0).toDouble();
          myTotalPoints = (match['totalPoints'] ?? widget.quiz.totalPoints).toDouble();
          if (ApiService.userId != null) {
            await ApiService.markSubmittedLocally(widget.quiz.id, ApiService.userId!);
          }
        }
      } catch (_) {
        // Server unreachable — fall back to local lock
        alreadySubmitted = await ApiService.hasSubmittedQuiz(widget.quiz.id);
      }

      // ── Load questions ────────────────────────────────────────────────
      final data      = await ApiService.getQuizDetail(widget.quiz.id);
      final questions = (data['questions'] as List? ?? [])
          .map((q) => QuestionModel.fromJson(q))
          .toList();

      if (!mounted) return;
      setState(() {
        _alreadySubmitted = alreadySubmitted;
        _deadlinePassed   = deadlinePassed;
        _myScore          = myScore;
        _myTotalPoints    = myTotalPoints ?? widget.quiz.totalPoints;
        _questions        = questions;
        _isLoading        = false;
      });
    } catch (e) {
      if (!mounted) return;
      final alreadySubmitted = await ApiService.hasSubmittedQuiz(widget.quiz.id);
      setState(() {
        _alreadySubmitted = alreadySubmitted;
        _deadlinePassed   = widget.quiz.isDeadlinePassed;
        _isLoading        = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _onStart() async {
    if (_isStarting || _isLoading || _questions.isEmpty) return;
    setState(() => _isStarting = true);
    _pulseController.stop();

    for (int i = 3; i >= 0; i--) {
      setState(() => _countdown = i);
      await _countdownController.forward(from: 0);
      if (i > 0) await Future.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) return;
    await _slideController.reverse();
    await _fadeController.reverse();
    if (!mounted) return;

    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) =>
          QuizScreen(quiz: widget.quiz, questions: _questions),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  Color get _countdownColor {
    if (_countdown == 0) return AppColors.correct;
    if (_countdown == 1) return AppColors.confirm;
    if (_countdown == 2) return Colors.orange;
    return AppColors.primary;
  }

  String _formatDeadline(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 0)    return 'Due in ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0)   return 'Due in ${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return 'Due in ${diff.inMinutes} min';
    return 'Due very soon!';
  }

  /// Formats a double cleanly — removes trailing .0
  /// 18.0 → "18",  14.5 → "14.5"
  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _isStarting ? _buildCountdown() : _buildIntro(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final quiz     = widget.quiz;
    final deadline = quiz.deadlineDateTime;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(children: [

            // ── Top bar ──────────────────────────────────────────────────
            Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: TC.text(context)),
                  onPressed: () => Navigator.pop(context)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.leaderboard, color: AppColors.primary),
                  tooltip: 'Leaderboard',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LeaderboardScreen(quiz: quiz)))),
            ]),

            const SizedBox(height: 20),

            // ── Banner ────────────────────────────────────────────────────
            Container(
              width: double.infinity, height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.darkCard],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Stack(children: [
                Positioned(top: -30, right: -20,
                    child: Container(width: 120, height: 120,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07)))),
                Positioned(bottom: -40, left: -10,
                    child: Container(width: 140, height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05)))),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(quiz.classRoomName ?? '',
                            style: const TextStyle(color: Colors.white70,
                                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 8),
                      Text(quiz.title,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('by ${quiz.teacherName ?? ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Stats chips ────────────────────────────────────────────────
            // Points: uses filled star icon + amber colour + clean number (no .0)
            Row(children: [
              _StatChip(
                  icon: Icons.quiz_outlined,
                  label: '${quiz.questionCount} Questions'),
              const SizedBox(width: 12),
              _StatChip(
                  icon: Icons.star_rounded,
                  label: '${_fmt(quiz.totalPoints)} pts',
                  color: Colors.amber.shade600),
              const SizedBox(width: 12),
              quiz.timeLimitMinutes != null
                  ? _StatChip(
                  icon: Icons.timer_outlined,
                  label: '${quiz.timeLimitMinutes} min',
                  color: Colors.orange)
                  : const _StatChip(
                  icon: Icons.redo_outlined, label: 'No Limit'),
            ]),

            // ── Score card (only when student already submitted) ───────────
            if (_alreadySubmitted && _myScore != null) ...[
              const SizedBox(height: 12),
              _buildScoreCard(),
            ],

            // ── Deadline banner ────────────────────────────────────────────
            if (deadline != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _deadlinePassed
                      ? AppColors.wrong.withValues(alpha: 0.1)
                      : deadline.difference(DateTime.now()).inHours < 2
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _deadlinePassed
                        ? AppColors.wrong.withValues(alpha: 0.4)
                        : deadline.difference(DateTime.now()).inHours < 2
                        ? Colors.orange.withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    _deadlinePassed ? Icons.timer_off : Icons.calendar_today,
                    size: 16,
                    color: _deadlinePassed ? AppColors.wrong : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _deadlinePassed
                            ? 'Deadline has passed'
                            : _formatDeadline(deadline),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _deadlinePassed ? AppColors.wrong : TC.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deadline.month.toString().padLeft(2, '0')}/'
                            '${deadline.day.toString().padLeft(2, '0')}/'
                            '${deadline.year}  '
                            '${deadline.hour.toString().padLeft(2, '0')}:'
                            '${deadline.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: TC.subText(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Instructions card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: TC.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(
                          alpha: TC.isDark(context) ? 0.0 : 0.04),
                      blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Instructions', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: TC.text(context))),
                const SizedBox(height: 14),
                _InstructionRow(
                    icon: Icons.skip_next_outlined,
                    text: 'Skip and return to any question using the arrows.'),
                const SizedBox(height: 10),
                _InstructionRow(
                    icon: Icons.grid_view_outlined,
                    text: 'Tap the question counter to jump to any question.'),
                const SizedBox(height: 10),
                _InstructionRow(
                    icon: Icons.send_outlined,
                    text: 'Submit on the last question when ready.'),
                const SizedBox(height: 10),

                if (quiz.timeLimitMinutes != null) ...[
                  const SizedBox(height: 10),
                  _InstructionRow(
                      icon: Icons.timer_outlined,
                      text: 'You have ${quiz.timeLimitMinutes} minutes from when you '
                          'start. The quiz submits automatically when time runs out.',
                      color: Colors.orange),
                ],
              ]),
            ),

            const SizedBox(height: 28),

            // ── Action button ──────────────────────────────────────────────
            _buildActionButton(),

            const SizedBox(height: 28),
          ]),
        ),
      ),
    );
  }

  // ── Score card shown when student already submitted ────────────────────────
  Widget _buildScoreCard() {
    final score   = _myScore ?? 0;
    final total   = _myTotalPoints ?? widget.quiz.totalPoints;
    final percent = total > 0 ? (score / total * 100).round() : 0;

    final Color color = percent >= 75
        ? AppColors.correct
        : percent >= 50
        ? Colors.orange
        : AppColors.wrong;

    final IconData trophy = percent >= 75
        ? Icons.emoji_events_rounded
        : percent >= 50
        ? Icons.thumb_up_rounded
        : Icons.sentiment_neutral_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [

        // Percentage circle
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text('$percent%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ),

        const SizedBox(width: 16),

        // Score text + bar
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your Score',
                style: TextStyle(
                    fontSize: 12,
                    color: TC.subText(context),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            // e.g.  "14 / 18 pts"
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: _fmt(score),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                TextSpan(
                  text: ' / ${_fmt(total)} pts',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: TC.subText(context)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? (score / total).clamp(0.0, 1.0) : 0,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ]),
        ),

        const SizedBox(width: 12),

        // Trophy / result icon
        Icon(trophy, color: color, size: 32),
      ]),
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return Column(children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 8),
        Text('Checking status...',
            style: TextStyle(fontSize: 12, color: TC.subText(context))),
      ]);
    }

    if (_alreadySubmitted) {
      return _statusButton(
        icon: Icons.check_circle_outline,
        label: 'Already Taken',
        color: Colors.grey.shade500,
      );
    }

    if (_deadlinePassed) {
      return _statusButton(
        icon: Icons.timer_off,
        label: 'Deadline Passed',
        color: AppColors.wrong,
      );
    }

    if (_questions.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton.icon(
          onPressed: _loadQuiz,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Loading',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: GestureDetector(
        onTap: _onStart,
        child: Container(
          width: double.infinity, height: 58,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.darkCard],
                  begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16, offset: const Offset(0, 6))]),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            SizedBox(width: 8),
            Text('Start Quiz',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _statusButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildCountdown() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_countdown == 0 ? 'Get Ready!' : 'Starting in...',
              style: TextStyle(
                  fontSize: 18,
                  color: TC.subText(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _countdownController,
            builder: (_, __) {
              final scale = Tween<double>(begin: 1.3, end: 0.8).evaluate(
                  CurvedAnimation(
                      parent: _countdownController, curve: Curves.easeInOut));
              final opacity = Tween<double>(begin: 1.0, end: 0.0).evaluate(
                  CurvedAnimation(
                      parent: _countdownController, curve: Curves.easeIn));
              return Opacity(
                opacity: _countdownController.isAnimating ? opacity : 1.0,
                child: Transform.scale(
                  scale: _countdownController.isAnimating ? scale : 1.0,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _countdownColor.withValues(alpha: 0.12),
                        border: Border.all(color: _countdownColor, width: 4)),
                    child: Center(child: Text(
                        _countdown == 0 ? 'GO!' : '$_countdown',
                        style: TextStyle(
                            fontSize: _countdown == 0 ? 42 : 64,
                            fontWeight: FontWeight.bold,
                            color: _countdownColor))),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(widget.quiz.title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TC.text(context)),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Text('${widget.quiz.questionCount} questions',
              style: TextStyle(fontSize: 14, color: TC.subText(context))),
          if (widget.quiz.timeLimitMinutes != null) ...[
            const SizedBox(height: 6),
            Text('${widget.quiz.timeLimitMinutes} minute time limit',
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: c.withValues(alpha: TC.isDark(context) ? 0.2 : 0.10),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: c, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InstructionRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: c.withValues(alpha: TC.isDark(context) ? 0.2 : 0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: c, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: TextStyle(
              fontSize: 13, color: TC.subText(context), height: 1.4))),
    ]);
  }
}