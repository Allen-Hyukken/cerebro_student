import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/quiz_screen.dart';

class QuizIntroScreen extends StatefulWidget {
  final QuizModel quiz;
  const QuizIntroScreen({super.key, required this.quiz});

  @override
  State<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends State<QuizIntroScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _countdownController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  bool _isStarting = false;
  int _countdown   = 3;

  List<QuestionModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuiz();

    _fadeController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
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
  }

  Future<void> _loadQuiz() async {
    try {
      // Check if already submitted (anti-cheat lock)
      final alreadySubmitted = await ApiService.hasSubmittedQuiz(widget.quiz.id);
      if (alreadySubmitted && mounted) {
        _showAlreadySubmittedDialog();
        setState(() => _isLoading = false);
        return;
      }
      final data = await ApiService.getQuizDetail(widget.quiz.id);
      final questions = (data['questions'] as List).map((q) => QuestionModel.fromJson(q)).toList();
      setState(() { _questions = questions; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAlreadySubmittedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 48),
          title: const Text('Already Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'You have already submitted this quiz. Each quiz can only be taken once.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    });
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
    if (_isStarting || _isLoading) return;
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
      pageBuilder: (_, animation, __) => QuizScreen(quiz: widget.quiz, questions: _questions),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context))),
        const SizedBox(height: 20),
        // Banner
        Container(
          width: double.infinity, height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.darkCard], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Stack(children: [
            Positioned(top: -30, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)))),
            Positioned(bottom: -40, left: -10, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.quiz.classRoomName ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
                const SizedBox(height: 8),
                Text(widget.quiz.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('by ${widget.quiz.teacherName ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        // Stats
        Row(children: [
          _StatChip(icon: Icons.quiz_outlined, label: '${widget.quiz.questionCount} Questions'),
          const SizedBox(width: 12),
          _StatChip(icon: Icons.star_outline, label: '${widget.quiz.totalPoints} Points'),
          const SizedBox(width: 12),
          _StatChip(icon: Icons.redo_outlined, label: 'Skippable'),
        ]),
        const SizedBox(height: 24),
        // Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
            const SizedBox(height: 14),
            _InstructionRow(icon: Icons.skip_next_outlined, text: 'Skip and return to any question using the arrows.'),
            const SizedBox(height: 10),
            _InstructionRow(icon: Icons.grid_view_outlined, text: 'Tap the question counter to jump to any question.'),
            const SizedBox(height: 10),
            _InstructionRow(icon: Icons.send_outlined, text: 'Submit on the last question when ready.'),
            const SizedBox(height: 10),
            _InstructionRow(icon: Icons.edit_outlined, text: 'MCQ, True/False, Essay, Identification & Coding.'),
          ]),
        ),
        const Spacer(),
        // Start button
        _isLoading
            ? const CircularProgressIndicator(color: AppColors.primary)
            : AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
          child: GestureDetector(
            onTap: _onStart,
            child: Container(
              width: double.infinity, height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.darkCard], begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Text('Start Quiz', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ]),
    );
  }

  Widget _buildCountdown() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_countdown == 0 ? 'Get Ready!' : 'Starting in...', style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      const SizedBox(height: 32),
      AnimatedBuilder(
        animation: _countdownController,
        builder: (_, __) {
          final scale   = Tween<double>(begin: 1.3, end: 0.8).evaluate(CurvedAnimation(parent: _countdownController, curve: Curves.easeInOut));
          final opacity = Tween<double>(begin: 1.0, end: 0.0).evaluate(CurvedAnimation(parent: _countdownController, curve: Curves.easeIn));
          return Opacity(
            opacity: _countdownController.isAnimating ? opacity : 1.0,
            child: Transform.scale(
              scale: _countdownController.isAnimating ? scale : 1.0,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _countdownColor.withOpacity(0.12), border: Border.all(color: _countdownColor, width: 4)),
                child: Center(child: Text(_countdown == 0 ? 'GO!' : '$_countdown',
                    style: TextStyle(fontSize: _countdown == 0 ? 42 : 64, fontWeight: FontWeight.bold, color: _countdownColor))),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 40),
      Text(widget.quiz.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 8),
      Text('${widget.quiz.questionCount} questions', style: const TextStyle(fontSize: 14, color: Colors.grey)),
    ]));
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ));
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4))),
    ]);
  }
}