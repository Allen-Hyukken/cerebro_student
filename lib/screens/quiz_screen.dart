import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/result_screen.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  final List<QuestionModel> questions;

  const QuizScreen({super.key, required this.quiz, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;

  // answers: questionId (as string) → answer value (string)
  //   MCQ   → choiceId as string, e.g. "42"
  //   TF    → "True" or "False"
  //   IDENT / ESSAY / CODING → free-text answer
  final Map<String, String> _answers = {};

  // Persistent text controllers so content survives question navigation
  final Map<String, TextEditingController> _controllers = {};

  List<QuestionModel> get questions     => widget.questions;
  QuestionModel       get currentQuestion => questions[_currentIndex];
  bool get isLastQuestion => _currentIndex == questions.length - 1;
  bool get isFirstQuestion => _currentIndex == 0;

  // FIX: a question counts as answered only when it has a non-empty value
  bool _isAnswered(int index) {
    final val = _answers[questions[index].id.toString()];
    return val != null && val.trim().isNotEmpty;
  }

  bool get currentHasAnswer => _isAnswered(_currentIndex);

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: _answers[key] ?? ''));

  void _goTo(int index) => setState(() => _currentIndex = index);
  void _goNext() { if (!isLastQuestion) setState(() => _currentIndex++); }
  void _goPrev() { if (!isFirstQuestion) setState(() => _currentIndex--); }

  // Jump to the nearest unanswered question in a given direction
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

  // FIX: always call setState so answered-dot updates immediately in the navigator
  void _setAnswer(String answer) {
    setState(() => _answers[currentQuestion.id.toString()] = answer);
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

    // Build the answers map — only include non-empty entries
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: List.generate(questions.length, (i) {
                final answered = _isAnswered(i);
                final isCurrent = i == _currentIndex;
                return GestureDetector(
                  onTap: () { _goTo(i); Navigator.pop(ctx); },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent ? AppColors.primary : answered ? AppColors.correct : Colors.grey.shade200,
                    ),
                    child: Center(child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: (isCurrent || answered) ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
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
    );
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
        backgroundColor: AppColors.background,
        body: const Center(child: Text('No questions found.')),
      );
    }

    final progress = (_currentIndex + 1) / questions.length;
    final answeredSoFar = questions.where((q) => _isAnswered(questions.indexOf(q))).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [

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
                      backgroundColor: Colors.grey.shade200,
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

        // ── Question body ─────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),

              // Type badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor(currentQuestion.type).withOpacity(0.12),
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
                    color: AppColors.primary.withOpacity(0.08),
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

              // Answer widget (type-specific)
              _buildAnswerWidget(),

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // ── Navigation bar ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            // Previous
            _NavButton(
              icon: Icons.arrow_back_ios,
              enabled: !isFirstQuestion,
              onTap: _goPrev,
            ),

            const Spacer(),

            // Skip back to unanswered
            if (!isFirstQuestion)
              TextButton.icon(
                onPressed: () => _skipToUnanswered(false),
                icon: const Icon(Icons.skip_previous, size: 16),
                label: const Text('Prev Unanswered', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),

            const Spacer(),

            // Submit / Next
            if (isLastQuestion)
              ElevatedButton.icon(
                onPressed: _submitQuiz,
                icon: const Icon(Icons.send),
                label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.confirm, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              )
            else
              ElevatedButton(
                onPressed: _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

            const Spacer(),

            // Skip forward to unanswered
            if (!isLastQuestion)
              TextButton.icon(
                onPressed: () => _skipToUnanswered(true),
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('Next Unanswered', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),

            const Spacer(),

            // Next arrow
            _NavButton(
              icon: Icons.arrow_forward_ios,
              enabled: !isLastQuestion,
              onTap: _goNext,
            ),
          ]),
        ),
      ])),
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
    final q   = currentQuestion;
    final qId = q.id.toString();
    final currentAnswer = _answers[qId];

    switch (q.type) {

    // ── Multiple Choice ───────────────────────────────────────────────────
      case 'MCQ':
        if (q.choices.isEmpty) {
          return const _EmptyChoicesHint();
        }
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
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))]
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
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(
                    choice.text,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 15,
                    ),
                  )),
                ]),
              ),
            );
          }).toList(),
        );

    // ── True / False ──────────────────────────────────────────────────────
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
                    left:  option == 'False' ? 8 : 0,
                  ),
                  height: 72,
                  decoration: BoxDecoration(
                    color: isSelected ? color : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade200,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      option == 'True' ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: isSelected ? Colors.white : color,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        );

    // ── Identification ────────────────────────────────────────────────────
      case 'IDENT':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Type your answer below:',
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.sentences,
            // FIX: call setState so the answered-dot lights up immediately
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Your answer...',
              filled: true, fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: currentAnswer != null && currentAnswer.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () {
                  ctrl.clear();
                  setState(() => _answers.remove(qId));
                },
              )
                  : null,
            ),
          ),
        ]);

    // ── Essay ─────────────────────────────────────────────────────────────
      case 'ESSAY':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Write your answer below:',
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            // FIX: call setState so the answered-dot lights up immediately
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: 'Write your answer here...',
              filled: true, fillColor: AppColors.white,
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
                Text(
                  '${currentAnswer.trim().split(RegExp(r'\s+')).length} words',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ]),
            ),
        ]);

    // ── Coding ────────────────────────────────────────────────────────────
      case 'CODING':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Instructions header
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
          // FIX: removed duplicate question text display from the dark box.
          //      The question text is already shown in the main question area above.
          //      The code editor now starts directly for input.
          TextField(
            controller: ctrl,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textDark),
            // FIX: call setState so the answered-dot lights up immediately
            onChanged: (val) => setState(() => _answers[qId] = val),
            decoration: InputDecoration(
              hintText: '// Write your code here...',
              hintStyle: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF4F4FB),
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

// ── Helper widgets ────────────────────────────────────────────────────────────

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
          color: enabled ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
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