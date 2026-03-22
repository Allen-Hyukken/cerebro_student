import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _controllers = {};

  // ── Timer state ───────────────────────────────────────────────────────────
  Timer? _timer;
  int _secondsLeft = 30;
  bool _timeWarning = false; // true when <= 10 seconds left
  bool _timeExpired = false; // true when timer hits 0

  // Timer durations per question type (in seconds)
  static const Map<String, int> _timerDurations = {
    'MCQ':    30,
    'TF':     20,
    'IDENT':  60,
    'ESSAY':  180,  // 3 min
    'CODING': 300,  // 5 min
  };

  List<QuestionModel> get questions      => widget.questions;
  QuestionModel       get currentQuestion => questions[_currentIndex];
  bool get isLastQuestion  => _currentIndex == questions.length - 1;
  bool get isFirstQuestion => _currentIndex == 0;

  bool _isAnswered(int index) {
    final val = _answers[questions[index].id.toString()];
    return val != null && val.trim().isNotEmpty;
  }

  bool get currentHasAnswer => _isAnswered(_currentIndex);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  // ── Timer logic ───────────────────────────────────────────────────────────

  int _getDuration(String type) => _timerDurations[type] ?? 60;

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft  = _getDuration(currentQuestion.type);
      _timeWarning  = false;
      _timeExpired  = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
          _timeWarning = _secondsLeft <= 10 && _secondsLeft > 0;
          if (_secondsLeft == 10) SoundService().playWarning();
        } else {
          _timeExpired = true;
          _timeWarning = false;
          t.cancel();
          _onTimeExpired();
        }
      });
    });
  }

  void _onTimeExpired() {
    // Just show warning — do NOT auto-submit
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [
          Icon(Icons.timer_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Time\'s up! You can still answer.'),
        ]),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Format seconds as MM:SS
  String get _timerDisplay {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return m > 0
        ? '$m:${s.toString().padLeft(2, '0')}'
        : '$_secondsLeft';
  }

  Color get _timerColor {
    if (_timeExpired) return Colors.grey;
    if (_timeWarning) return AppColors.wrong;
    if (_secondsLeft <= 20) return Colors.orange;
    return AppColors.correct;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: _answers[key] ?? ''));

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    _startTimer();
  }

  void _goNext() {
    if (!isLastQuestion) {
      SoundService().playNext();
      setState(() => _currentIndex++);
      _startTimer();
    }
  }

  void _goPrev() {
    if (!isFirstQuestion) {
      SoundService().playNext();
      setState(() => _currentIndex--);
      _startTimer();
    }
  }

  void _skipToUnanswered(bool forward) {
    for (int i = 1; i < questions.length; i++) {
      final next = forward
          ? (_currentIndex + i) % questions.length
          : (_currentIndex - i + questions.length) % questions.length;
      if (!_isAnswered(next)) {
        setState(() => _currentIndex = next);
        _startTimer();
        return;
      }
    }
  }

  void _setAnswer(String answer) {
    setState(() => _answers[currentQuestion.id.toString()] = answer);
    SoundService().playSelect();
  }

  Future<void> _submitQuiz() async {
    final answeredCount = questions.where((q) => _isAnswered(questions.indexOf(q))).length;
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

    _timer?.cancel();
    SoundService().playSubmit();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e'), backgroundColor: AppColors.wrong),
      );
    }
  }

  void _showNavigator() {
    _timer?.cancel(); // pause timer while navigator is open
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      color: isCurrent ? AppColors.primary : answered ? AppColors.correct : Colors.grey.shade200,
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
      ),
    ).then((_) => _startTimer()); // resume timer when closed
  }

  Widget _legend(Color color, String label, {Color? textColor}) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: textColor ?? Colors.grey.shade600)),
  ]);

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: TC.bg(context),
        body: const Center(child: Text('No questions found.')),
      );
    }

    final progress       = (_currentIndex + 1) / questions.length;
    final answeredSoFar  = questions.where((q) => _isAnswered(questions.indexOf(q))).length;
    final totalDuration  = _getDuration(currentQuestion.type);
    final timerProgress  = _secondsLeft / totalDuration;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: Stack(children: [
        SafeArea(child: Column(children: [

          // ── Header ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
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

          // ── Timer bar ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _timeExpired
                    ? Colors.grey.shade100
                    : _timeWarning
                    ? AppColors.wrong.withValues(alpha: 0.08)
                    : AppColors.correct.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _timeExpired
                      ? Colors.grey.shade300
                      : _timeWarning
                      ? AppColors.wrong.withValues(alpha: 0.4)
                      : AppColors.correct.withValues(alpha: 0.3),
                ),
              ),
              child: Row(children: [
                // Timer icon — pulses when warning
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _timeExpired ? Icons.timer_off : Icons.timer_outlined,
                    key: ValueKey(_timeExpired),
                    color: _timerColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),

                // Progress bar
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _timeExpired ? 0 : timerProgress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Time display
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: _timeWarning ? 17 : 15,
                    fontWeight: FontWeight.bold,
                    color: _timerColor,
                    fontFamily: 'monospace',
                  ),
                  child: Text(
                    _timeExpired ? 'Time\'s up!' : _timerDisplay,
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 8),

          // ── Question body ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),

                // Type badge + points
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(currentQuestion.type).withValues(alpha: TC.isDark(context) ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _typeLabel(currentQuestion.type),
                      style: TextStyle(color: _typeColor(currentQuestion.type), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: TC.isDark(context) ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${currentQuestion.points} pt${currentQuestion.points == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),

                // Question text
                Text(
                  currentQuestion.text,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.4),
                ),

                const SizedBox(height: 24),

                // Answer widget
                _buildAnswerWidget(),

                const SizedBox(height: 24),
              ]),
            ),
          ),

          // ── Navigation bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: [
              // Top row: skip buttons
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (!isFirstQuestion)
                  TextButton.icon(
                    onPressed: () => _skipToUnanswered(false),
                    icon: const Icon(Icons.skip_previous, size: 14),
                    label: const Text('Prev', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  const SizedBox(width: 60),
                const SizedBox(),
                if (!isLastQuestion)
                  TextButton.icon(
                    onPressed: () => _skipToUnanswered(true),
                    icon: const Icon(Icons.skip_next, size: 14),
                    label: const Text('Next', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  const SizedBox(width: 60),
              ]),
              const SizedBox(height: 4),
              // Bottom row: prev arrow + main button + next arrow
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _NavButton(icon: Icons.arrow_back_ios, enabled: !isFirstQuestion, onTap: _goPrev),
                if (isLastQuestion)
                  ElevatedButton.icon(
                    onPressed: _submitQuiz,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.confirm, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                _NavButton(icon: Icons.arrow_forward_ios, enabled: !isLastQuestion, onTap: _goNext),
              ]),
            ]),
          ),
        ])),

      ]), // end Stack
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
      case 'CODING': return AppColors.codeCard;
      default:       return AppColors.primary;
    }
  }

  // ── Answer widgets ────────────────────────────────────────────────────────

  Widget _buildAnswerWidget() {
    final q           = currentQuestion;
    final qId         = q.id.toString();
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
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.white : Colors.grey.shade400, width: 2),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 14, color: AppColors.primary) : null,
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
                  margin: EdgeInsets.only(right: option == 'True' ? 8 : 0, left: option == 'False' ? 8 : 0),
                  height: 72,
                  decoration: BoxDecoration(
                    color: isSelected ? color : TC.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? color : TC.divider(context), width: 2),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(option == 'True' ? Icons.check_circle_outline : Icons.cancel_outlined,
                        color: isSelected ? Colors.white : color, size: 22),
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
          const Text('Type your answer below:',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Your answer...',
              filled: true, fillColor: TC.input(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: currentAnswer != null && currentAnswer.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () { ctrl.clear(); setState(() => _answers.remove(qId)); })
                  : null,
            ),
          ),
        ]);

      case 'ESSAY':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Write your answer below:',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Write your answer here...',
              filled: true, fillColor: TC.input(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
                Text('${currentAnswer.trim().split(RegExp(r'\s+')).length} words',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
        ]);

      case 'CODING':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.codeCard,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(children: const [
              Icon(Icons.code, color: Colors.greenAccent, size: 16),
              SizedBox(width: 8),
              Text('Code Editor', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          TextField(
            controller: ctrl,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textDark),
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: '// Write your code here...',
              hintStyle: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 13),
              filled: true, fillColor: TC.isDark(context) ? const Color(0xFF1A1A2E) : const Color(0xFFF4F4FB),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          if (currentAnswer != null && currentAnswer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 13, color: AppColors.correct),
                const SizedBox(width: 4),
                Text(
                  '${currentAnswer.trim().split('\n').length} line${currentAnswer.trim().split('\n').length == 1 ? '' : 's'} written',
                  style: const TextStyle(fontSize: 12, color: AppColors.correct),
                ),
              ]),
            ),
        ]);

      default:
        return const SizedBox();
    }
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.primary : Colors.grey.shade300),
      ),
    );
  }
}

class _EmptyChoicesHint extends StatelessWidget {
  const _EmptyChoicesHint();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14)),
    child: const Row(children: [
      Icon(Icons.warning_amber_rounded, color: Colors.orange),
      SizedBox(width: 10),
      Text('No choices available for this question.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}