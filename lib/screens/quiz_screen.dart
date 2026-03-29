import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/result_screen.dart';
import 'package:quiz_app/services/sound_service.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  final List<QuestionModel> questions;

  const QuizScreen({super.key, required this.quiz, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _submitting = false;

  // ── Global timer ─────────────────────────────────────────────────────────
  Timer? _globalTimer;
  int  _globalSecondsLeft = 0;
  bool _warningAt60Fired  = false;
  bool _warningAt30Fired  = false;

  bool get _hasTimer => widget.quiz.timeLimitMinutes != null;

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<QuestionModel> get questions       => widget.questions;
  QuestionModel       get currentQuestion => questions[_currentIndex];
  bool get isLastQuestion  => _currentIndex == questions.length - 1;
  bool get isFirstQuestion => _currentIndex == 0;

  bool _isAnswered(int index) {
    final val = _answers[questions[index].id.toString()];
    return val != null && val.trim().isNotEmpty;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
    if (_hasTimer) {
      _globalSecondsLeft = widget.quiz.timeLimitMinutes! * 60;
      _startGlobalTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitFullscreen();
    _globalTimer?.cancel();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  // ── Fullscreen ────────────────────────────────────────────────────────────

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  // ── App lifecycle (Home / Recents / phone call) ───────────────────────────
  // Android fires these states:
  //   inactive → phone call overlay, notification shade, OR Recents opened
  //   paused   → app fully in background (Home pressed, switched via Recents)
  //
  // We use a flag so _exitAndSubmit only runs ONCE even if both fire.
  bool _lifecycleSubmitFired = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!_lifecycleSubmitFired && !_submitting) {
        _lifecycleSubmitFired = true;
        _exitAndSubmit();
      }
    } else if (state == AppLifecycleState.resumed) {
      // If somehow they come back (submit may still be in-flight), re-lock screen
      _lifecycleSubmitFired = false;
      _enterFullscreen();
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startGlobalTimer() {
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_globalSecondsLeft > 0) {
          _globalSecondsLeft--;
          if (_globalSecondsLeft == 60 && !_warningAt60Fired) {
            _warningAt60Fired = true;
            SoundService().playWarning();
          }
          if (_globalSecondsLeft == 30 && !_warningAt30Fired) {
            _warningAt30Fired = true;
            SoundService().playWarning();
          }
        } else {
          t.cancel();
          _onTimeExpired();
        }
      });
    });
  }

  void _onTimeExpired() {
    if (_submitting) return;
    SoundService().playWarning();
    _autoSubmit();
  }

  Future<void> _autoSubmit() async {
    if (_submitting || !mounted) return;
    setState(() => _submitting = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.timer_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text("Time's up! Submitting your quiz..."),
        ]),
        backgroundColor: Colors.deepOrange,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    }
    await _doSubmit();
  }

  String get _timerDisplay {
    final m = _globalSecondsLeft ~/ 60;
    final s = _globalSecondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_globalSecondsLeft <= 30)  return AppColors.wrong;
    if (_globalSecondsLeft <= 120) return Colors.orange;
    return AppColors.correct;
  }

  bool get _isCritical => _globalSecondsLeft <= 30;

  // ── Navigation ─────────────────────────────────────────────────────────────
  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: _answers[key] ?? ''));

  void _goTo(int index) => setState(() => _currentIndex = index);

  void _goNext() {
    if (!isLastQuestion) {
      SoundService().playNext();
      setState(() => _currentIndex++);
    }
  }

  void _goPrev() {
    if (!isFirstQuestion) {
      SoundService().playNext();
      setState(() => _currentIndex--);
    }
  }

  void _skipToUnanswered(bool forward) {
    for (int i = 1; i < questions.length; i++) {
      final next = forward
          ? (_currentIndex + i) % questions.length
          : (_currentIndex - i + questions.length) % questions.length;
      if (!_isAnswered(next)) {
        setState(() => _currentIndex = next);
        return;
      }
    }
  }

  void _setAnswer(String answer) {
    setState(() => _answers[currentQuestion.id.toString()] = answer);
    SoundService().playSelect();
  }

  // ── Submission ─────────────────────────────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_submitting) return;
    final answeredCount = questions
        .where((q) => _isAnswered(questions.indexOf(q)))
        .length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submit Quiz?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('You answered $answeredCount of ${questions.length} questions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    SoundService().playSubmit();
    await _doSubmit();
  }

  /// Called when user presses back button, Home, or Recents.
  /// Silently submits whatever answers exist so far.
  Future<void> _exitAndSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _globalTimer?.cancel();
    _exitFullscreen();
    final submittable = Map<String, String>.fromEntries(
      _answers.entries.where((e) => e.value.trim().isNotEmpty),
    );
    try {
      final result = await ApiService.submitAttempt(widget.quiz.id, submittable);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ResultScreen(quiz: widget.quiz, attemptData: result),
      ));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _doSubmit() async {
    _globalTimer?.cancel();
    _exitFullscreen();
    final submittable = Map<String, String>.fromEntries(
      _answers.entries.where((e) => e.value.trim().isNotEmpty),
    );
    try {
      final result = await ApiService.submitAttempt(widget.quiz.id, submittable);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ResultScreen(quiz: widget.quiz, attemptData: result),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Submit failed: $e'),
        backgroundColor: AppColors.wrong,
      ));
    }
  }

  void _showNavigator() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: List.generate(questions.length, (i) {
              final answered  = _isAnswered(i);
              final isCurrent = i == _currentIndex;
              return GestureDetector(
                onTap: () { Navigator.pop(ctx); _goTo(i); },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? AppColors.primary
                        : answered
                        ? AppColors.correct
                        : Colors.grey.shade200,
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: TextStyle(
                        color: (isCurrent || answered) ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ))),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(AppColors.primary, 'Current'),
            const SizedBox(width: 16),
            _legend(AppColors.correct, 'Answered'),
            const SizedBox(width: 16),
            _legend(Colors.grey.shade200, 'Unanswered', textColor: Colors.grey),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _legend(Color color, String label, {Color? textColor}) => Row(children: [
    Container(width: 14, height: 14,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: textColor ?? Colors.grey.shade600)),
  ]);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
          backgroundColor: TC.bg(context),
          body: const Center(child: Text('No questions found.')));
    }

    final progress      = (_currentIndex + 1) / questions.length;
    final answeredSoFar = questions
        .where((q) => _isAnswered(questions.indexOf(q)))
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exitAndSubmit();
      },
      child: Scaffold(
        backgroundColor: TC.bg(context),
        body: SafeArea(child: Column(children: [

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textDark),
                onPressed: _exitAndSubmit,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _showNavigator,
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress, minHeight: 8,
                        backgroundColor: TC.card(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} / ${questions.length}  ·  $answeredSoFar answered',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: AppColors.textDark),
                onPressed: _showNavigator,
              ),
            ]),
          ),

          // ── Timer bar ─────────────────────────────────────────────────────
          if (_hasTimer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTimerBar(),
            ),
          if (_hasTimer) const SizedBox(height: 8),

          // ── Question body ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(currentQuestion.type)
                          .withValues(alpha: TC.isDark(context) ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_typeLabel(currentQuestion.type),
                        style: TextStyle(
                            color: _typeColor(currentQuestion.type),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                          alpha: TC.isDark(context) ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        '${currentQuestion.points} '
                            'pt${currentQuestion.points == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(currentQuestion.text,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: TC.text(context), height: 1.4)),
                const SizedBox(height: 24),
                _buildAnswerWidget(),
                const SizedBox(height: 24),
              ]),
            ),
          ),

          // ── Navigation bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (!isFirstQuestion)
                  TextButton.icon(
                    onPressed: () => _skipToUnanswered(false),
                    icon: const Icon(Icons.skip_previous, size: 14),
                    label: const Text('Prev', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  )
                else
                  const SizedBox(),
                if (!isLastQuestion)
                  TextButton.icon(
                    onPressed: () => _skipToUnanswered(true),
                    icon: const Icon(Icons.skip_next, size: 14),
                    label: const Text('Skip', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  )
                else
                  const SizedBox(),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _NavButton(
                    icon: Icons.arrow_back_ios,
                    enabled: !isFirstQuestion,
                    onTap: _goPrev),
                const SizedBox(width: 12),
                Expanded(
                  child: isLastQuestion
                      ? ElevatedButton(
                    onPressed: _submitting ? null : _submitQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.confirm,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Quiz',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                      : ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Next',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                _NavButton(
                    icon: Icons.arrow_forward_ios,
                    enabled: !isLastQuestion,
                    onTap: _goNext),
              ]),
            ]),
          ),
        ])),
      ), // Scaffold
    ); // PopScope
  }

  // ── Timer bar ─────────────────────────────────────────────────────────────
  Widget _buildTimerBar() {
    final totalSec = widget.quiz.timeLimitMinutes! * 60;
    final progress = (_globalSecondsLeft / totalSec).clamp(0.0, 1.0);
    final color    = _timerColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isCritical
            ? AppColors.wrong.withValues(alpha: 0.10)
            : _globalSecondsLeft <= 120
            ? Colors.orange.withValues(alpha: 0.08)
            : AppColors.correct.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(children: [
        _isCritical
            ? _PulsingIcon(color: color)
            : Icon(Icons.hourglass_bottom_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress, minHeight: 6,
              backgroundColor: TC.card(context),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: _isCritical ? 17 : 15,
            fontWeight: FontWeight.bold,
            color: color, fontFamily: 'monospace',
          ),
          child: Text(_timerDisplay),
        ),
        const SizedBox(width: 6),
        Text('left', style: TextStyle(fontSize: 11, color: TC.subText(context))),
      ]),
    );
  }

  // ── Question type helpers ─────────────────────────────────────────────────
  String _typeLabel(String type) {
    switch (type) {
      case 'MCQ':    return 'Multiple Choice';
      case 'TF':     return 'True or False';
      case 'IDENT':  return 'Identification';
      case 'ESSAY':  return 'Essay';
      case 'CODING': return 'Coding';
      default:       return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'MCQ':    return AppColors.primary;
      case 'TF':     return Colors.teal;
      case 'IDENT':  return Colors.orange;
      case 'ESSAY':  return Colors.indigo;
      case 'CODING': return Colors.greenAccent.shade400; // visible in both modes
      default:       return AppColors.primary;
    }
  }

  // ── Answer widgets ────────────────────────────────────────────────────────
  Widget _buildAnswerWidget() {
    final q             = currentQuestion;
    final qId           = q.id.toString();
    final currentAnswer = _answers[qId];

    switch (q.type) {

      case 'MCQ':
        if (q.choices.isEmpty) return const _EmptyChoicesHint();
        return Column(
          children: q.choices.map((choice) {
            final isSelected = currentAnswer == choice.id.toString();
            return GestureDetector(
              onTap: () => _setAnswer(choice.id.toString()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : TC.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : TC.divider(context),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? Colors.white : Colors.grey.shade400,
                          width: 2),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(choice.text,
                      style: TextStyle(
                        color: isSelected ? Colors.white : TC.text(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 15,
                      ))),
                ]),
              ),
            );
          }).toList(),
        );

      case 'TF':
        return Row(
          children: ['True', 'False'].map((option) {
            final isSelected = currentAnswer == option;
            final color = option == 'True' ? AppColors.correct : AppColors.wrong;
            return Expanded(
              child: GestureDetector(
                onTap: () => _setAnswer(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                      right: option == 'True' ? 8 : 0,
                      left:  option == 'False' ? 8 : 0),
                  height: 72,
                  decoration: BoxDecoration(
                    color: isSelected ? color : TC.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected ? color : TC.divider(context), width: 2),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.3),
                        blurRadius: 8, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                        option == 'True'
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: isSelected ? Colors.white : color,
                        size: 22),
                    const SizedBox(height: 4),
                    Text(option, style: TextStyle(
                      color: isSelected ? Colors.white : TC.text(context),
                      fontWeight: FontWeight.bold, fontSize: 16,
                    )),
                  ]),
                ),
              ),
            );
          }).toList(),
        );

      case 'IDENT':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Type your answer below:',
              style: TextStyle(
                  fontSize: 13, color: TC.subText(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: TC.text(context)),
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Your answer...',
              hintStyle: TextStyle(color: TC.subText(context)),
              filled: true, fillColor: TC.input(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: currentAnswer != null && currentAnswer.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    ctrl.clear();
                    setState(() => _answers.remove(qId));
                  })
                  : null,
            ),
          ),
        ]);

      case 'ESSAY':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Write your answer below:',
              style: TextStyle(
                  fontSize: 13, color: TC.subText(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: TC.text(context)),
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Write your answer here...',
              hintStyle: TextStyle(color: TC.subText(context)),
              filled: true, fillColor: TC.input(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.all(16),
              alignLabelWithHint: true,
            ),
          ),
          if (currentAnswer != null && currentAnswer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                    '${currentAnswer.trim().split(RegExp(r'\s+')).length} words',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
        ]);

      case 'CODING':
        return _CodingEditor(
          qId:           qId,
          initialValue:  _answers[qId] ?? '',
          onChanged:     (val) => setState(() => _answers[qId] = val),
          onClear:       () => setState(() => _answers.remove(qId)),
        );

      default:
        return const SizedBox();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CODING EDITOR WIDGET
// Proper code editor with:
//   • Dark background (#0D1117) regardless of app theme
//   • Live line numbers
//   • Tab key → inserts 4 spaces
//   • Monospace font throughout
//   • Line / character counter footer
// ═══════════════════════════════════════════════════════════════════════════════

class _CodingEditor extends StatefulWidget {
  final String   qId;
  final String   initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback         onClear;

  const _CodingEditor({
    required this.qId,
    required this.initialValue,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_CodingEditor> createState() => _CodingEditorState();
}

class _CodingEditorState extends State<_CodingEditor> {
  late TextEditingController _ctrl;
  late ScrollController       _lineScrollCtrl;
  late ScrollController       _editorScrollCtrl;

  // Editor colours (always dark — code editors should be dark)
  static const Color _editorBg      = Color(0xFF0D1117);   // GitHub-dark style
  static const Color _lineNumBg     = Color(0xFF161B22);
  static const Color _lineNumColor  = Color(0xFF6E7681);
  static const Color _codeColor     = Color(0xFFE6EDF3);   // near-white
  static const Color _headerBg      = Color(0xFF21262D);
  static const Color _borderColor   = Color(0xFF30363D);
  static const Color _footerBg      = Color(0xFF161B22);

  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _ctrl              = TextEditingController(text: widget.initialValue);
    _lineScrollCtrl    = ScrollController();
    _editorScrollCtrl  = ScrollController();
    _lineCount         = _countLines(_ctrl.text);

    _ctrl.addListener(() {
      final lines = _countLines(_ctrl.text);
      if (lines != _lineCount) setState(() => _lineCount = lines);
      // Sync line number scroll to editor scroll
      if (_editorScrollCtrl.hasClients && _lineScrollCtrl.hasClients) {
        _lineScrollCtrl.jumpTo(_editorScrollCtrl.offset);
      }
    });

    _editorScrollCtrl.addListener(() {
      if (_lineScrollCtrl.hasClients) {
        _lineScrollCtrl.jumpTo(_editorScrollCtrl.offset);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lineScrollCtrl.dispose();
    _editorScrollCtrl.dispose();
    super.dispose();
  }

  int _countLines(String text) {
    if (text.isEmpty) return 1;
    return '\n'.allMatches(text).length + 1;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasCode  = _ctrl.text.trim().isNotEmpty;
    final lineCount = _lineCount;
    final charCount = _ctrl.text.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Header bar ─────────────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: _headerBg,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          border: Border(
            top:   BorderSide(color: _borderColor),
            left:  BorderSide(color: _borderColor),
            right: BorderSide(color: _borderColor),
          ),
        ),
        child: Row(children: [
          // Traffic light dots
          _dot(const Color(0xFFFF5F57)),
          const SizedBox(width: 6),
          _dot(const Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          _dot(const Color(0xFF28C840)),
          const SizedBox(width: 12),
          const Icon(Icons.code, color: Colors.greenAccent, size: 14),
          const SizedBox(width: 6),
          const Text(
            'Code Editor',
            style: TextStyle(
              color: Colors.greenAccent, fontFamily: 'monospace',
              fontSize: 12, fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (hasCode)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onClear();
              },
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
            ),
        ]),
      ),

      // ── Editor area (line numbers + code) ──────────────────────────────────
      Container(
        decoration: const BoxDecoration(
          color: _editorBg,
          border: Border.symmetric(
            vertical: BorderSide(color: _borderColor),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 200, maxHeight: 320),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Line numbers column
          Container(
            width: 40,
            color: _lineNumBg,
            child: SingleChildScrollView(
              controller: _lineScrollCtrl,
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(lineCount, (i) => SizedBox(
                    height: 20, // must match line height below
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: _lineNumColor,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.0,
                        ),
                      ),
                    ),
                  )),
                ),
              ),
            ),
          ),

          // Code input
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                // Tab → insert 4 spaces
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  final text     = _ctrl.text;
                  final sel      = _ctrl.selection;
                  final newText  = text.replaceRange(sel.start, sel.end, '    ');
                  _ctrl.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: sel.start + 4),
                  );
                  widget.onChanged(newText);
                }
              },
              child: SingleChildScrollView(
                controller: _editorScrollCtrl,
                child: IntrinsicHeight(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: _codeColor,
                      height: 1.54,   // ~20 px per line at 13 px font size
                    ),
                    onChanged: widget.onChanged,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '// Write your code here...',
                      hintStyle: TextStyle(
                        fontFamily: 'monospace', color: _lineNumColor, fontSize: 13,
                      ),
                      filled: true,
                      fillColor: _editorBg,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),

      // ── Footer bar ─────────────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(
          color: _footerBg,
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
          border: Border(
            bottom: BorderSide(color: _borderColor),
            left:   BorderSide(color: _borderColor),
            right:  BorderSide(color: _borderColor),
          ),
        ),
        child: Row(children: [
          if (hasCode) ...[
            const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
            const SizedBox(width: 5),
            Text(
              '$lineCount line${lineCount == 1 ? '' : 's'}  ·  $charCount char${charCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: _lineNumColor,
              ),
            ),
          ] else ...[
            const Icon(Icons.info_outline, size: 12, color: _lineNumColor),
            const SizedBox(width: 5),
            const Text(
              'Start typing your solution…',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _lineNumColor),
            ),
          ],
          const Spacer(),
          const Text(
            'Tab = 4 spaces',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _lineNumColor),
          ),
        ]),
      ),

      // ── Note below editor ──────────────────────────────────────────────────
      const SizedBox(height: 8),
      Row(children: const [
        Icon(Icons.lightbulb_outline, size: 13, color: Colors.amber),
        SizedBox(width: 5),
        Flexible(child: Text(
          'Whitespace, indentation, and comments are ignored during grading.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        )),
      ]),
    ]);
  }

  Widget _dot(Color color) => Container(
    width: 11, height: 11,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Icon(Icons.timer_off_rounded, color: widget.color, size: 20),
  );
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool     enabled;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.12)
            : TC.card(context),
      ),
      child: Icon(icon, size: 18,
          color: enabled ? AppColors.primary : TC.subText(context)),
    ),
  );
}

class _EmptyChoicesHint extends StatelessWidget {
  const _EmptyChoicesHint();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14)),
    child: const Row(children: [
      Icon(Icons.warning_amber_rounded, color: Colors.orange),
      SizedBox(width: 10),
      Text('No choices available for this question.',
          style: TextStyle(color: Colors.grey)),
    ]),
  );
}