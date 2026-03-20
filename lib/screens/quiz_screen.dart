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
  // MCQ:          choiceId as string e.g. "42"
  // TF:           "True" or "False"
  // IDENT/ESSAY/CODING: answer text
  final Map<String, String> _answers = {};

  // Track text controllers so they persist across question navigation
  final Map<String, TextEditingController> _controllers = {};

  List<QuestionModel> get questions => widget.questions;
  QuestionModel get currentQuestion  => questions[_currentIndex];
  bool get isLastQuestion => _currentIndex == questions.length - 1;
  bool get hasAnswer => _answers.containsKey(currentQuestion.id.toString());

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String key) {
    return _controllers.putIfAbsent(key, () =>
        TextEditingController(text: _answers[key] ?? ''));
  }

  void _goNext() { if (!isLastQuestion) setState(() => _currentIndex++); }
  void _goPrev() { if (_currentIndex > 0) setState(() => _currentIndex--); }

  void _skipToUnanswered(bool forward) {
    int start = _currentIndex;
    for (int i = 1; i < questions.length; i++) {
      int next = forward
          ? (start + i) % questions.length
          : (start - i + questions.length) % questions.length;
      if (!_answers.containsKey(questions[next].id.toString())) {
        setState(() => _currentIndex = next);
        return;
      }
    }
  }

  void _setAnswer(String answer) {
    setState(() => _answers[currentQuestion.id.toString()] = answer);
  }

  Future<void> _submitQuiz() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submit Quiz?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('You answered ${_answers.length} of ${questions.length} questions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await ApiService.submitAttempt(widget.quiz.id, _answers);
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: List.generate(questions.length, (i) {
            final isAnswered = _answers.containsKey(questions[i].id.toString());
            final isCurrent  = i == _currentIndex;
            return GestureDetector(
              onTap: () { setState(() => _currentIndex = i); Navigator.pop(ctx); },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? AppColors.primary : isAnswered ? AppColors.correct : Colors.grey.shade200,
                ),
                child: Center(child: Text('${i + 1}',
                    style: TextStyle(color: isCurrent || isAnswered ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
              ),
            );
          })),
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
    Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: textColor ?? Colors.grey.shade600)),
  ]);

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(backgroundColor: AppColors.background,
          body: const Center(child: Text('No questions found.')));
    }

    final progress = (_currentIndex + 1) / questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.close, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
            Expanded(
              child: GestureDetector(
                onTap: _showNavigator,
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                  ),
                  const SizedBox(height: 4),
                  Text('${_currentIndex + 1} / ${questions.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ),
            IconButton(icon: const Icon(Icons.grid_view_rounded, color: AppColors.textDark), onPressed: _showNavigator),
          ]),
        ),

        // Question body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(_typeLabel(currentQuestion.type), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              Text(currentQuestion.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.4)),
              const SizedBox(height: 24),
              _buildAnswerWidget(),
              const SizedBox(height: 24),
            ]),
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconButton(
              onPressed: _currentIndex > 0 ? () => _skipToUnanswered(false) : null,
              icon: Icon(Icons.arrow_back_ios, color: _currentIndex > 0 ? AppColors.primary : Colors.grey),
            ),
            const Spacer(),
            isLastQuestion
                ? ElevatedButton.icon(
              onPressed: _submitQuiz,
              icon: const Icon(Icons.send),
              label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.confirm, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            )
                : ElevatedButton(
              onPressed: _goNext,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Spacer(),
            IconButton(
              onPressed: !isLastQuestion ? () => _skipToUnanswered(true) : null,
              icon: Icon(Icons.arrow_forward_ios, color: !isLastQuestion ? AppColors.primary : Colors.grey),
            ),
          ]),
        ),
      ])),
    );
  }

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

  Widget _buildAnswerWidget() {
    final q   = currentQuestion;
    final qId = q.id.toString();
    final currentAnswer = _answers[qId];

    switch (q.type) {
      case 'MCQ':
      // Sends choiceId as string to match AttemptService MCQ case
        return Column(children: q.choices.map((choice) {
          final isSelected = currentAnswer == choice.id.toString();
          return GestureDetector(
            onTap: () => _setAnswer(choice.id.toString()),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.grey.shade400, width: 2), color: isSelected ? Colors.white : Colors.transparent),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: AppColors.primary) : null,
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(choice.text,
                    style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
              ]),
            ),
          );
        }).toList());

      case 'TF':
      // Sends "True" or "False" to match AttemptService TF case
        return Row(children: ['True', 'False'].map((option) {
          final isSelected = currentAnswer == option;
          return Expanded(child: GestureDetector(
            onTap: () => _setAnswer(option),
            child: Container(
              margin: EdgeInsets.only(right: option == 'True' ? 8 : 0, left: option == 'False' ? 8 : 0),
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? (option == 'True' ? AppColors.correct : AppColors.wrong) : AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(option,
                  style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18))),
            ),
          ));
        }).toList());

      case 'IDENT':
        final ctrl = _controllerFor(qId);
        return TextField(
          controller: ctrl,
          onChanged: (val) => _answers[qId] = val,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            filled: true, fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.all(16),
          ),
        );

      case 'ESSAY':
        final ctrl = _controllerFor(qId);
        return TextField(
          controller: ctrl,
          maxLines: 6,
          onChanged: (val) => _answers[qId] = val,
          decoration: InputDecoration(
            hintText: 'Write your answer here...',
            filled: true, fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.all(16),
          ),
        );

      case 'CODING':
        final ctrl = _controllerFor(qId);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(14)),
            child: Text(q.text, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 8,
            onChanged: (val) => _answers[qId] = val,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: '// Write your code here...',
              filled: true, fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ]);

      default:
        return const SizedBox();
    }
  }
}