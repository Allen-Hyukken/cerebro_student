import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final Map<String, dynamic> attemptData;
  const ReviewScreen({super.key, required this.attemptData});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String _filter = 'all'; // all, wrong, correct, skipped

  List<dynamic> get _answers => widget.attemptData['answers'] ?? [];

  List<dynamic> get _filtered {
    switch (_filter) {
      case 'wrong':
        return _answers.where((a) =>
        (a['givenText'] != null || a['choiceId'] != null) && a['correct'] == false
        ).toList();
      case 'correct':
        return _answers.where((a) => a['correct'] == true).toList();
      case 'skipped':
        return _answers.where((a) =>
        a['givenText'] == null && a['choiceId'] == null
        ).toList();
      default:
        return _answers;
    }
  }

  int get _correctCount  => _answers.where((a) => a['correct'] == true).length;
  int get _wrongCount    => _answers.where((a) =>
  (a['givenText'] != null || a['choiceId'] != null) && a['correct'] == false).length;
  int get _skippedCount  => _answers.where((a) =>
  a['givenText'] == null && a['choiceId'] == null).length;

  @override
  Widget build(BuildContext context) {
    final quizTitle = widget.attemptData['quizTitle'] ?? 'Quiz';

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back, color: TC.text(context)),
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(child: Text('Review Answers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TC.text(context)))),
            ]),
          ),

          // ── Quiz title ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.darkCard],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(quizTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  _MiniBadge(label: '✅ $_correctCount Correct',  color: AppColors.correct),
                  const SizedBox(width: 8),
                  _MiniBadge(label: '❌ $_wrongCount Wrong',      color: AppColors.wrong),
                  const SizedBox(width: 8),
                  _MiniBadge(label: '⏭ $_skippedCount Skipped',  color: Colors.orange),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── Filter tabs ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _FilterTab(label: 'All',     value: 'all',     selected: _filter, onTap: (v) => setState(() => _filter = v), count: _answers.length),
              const SizedBox(width: 8),
              _FilterTab(label: 'Wrong',   value: 'wrong',   selected: _filter, onTap: (v) => setState(() => _filter = v), count: _wrongCount,   color: AppColors.wrong),
              const SizedBox(width: 8),
              _FilterTab(label: 'Correct', value: 'correct', selected: _filter, onTap: (v) => setState(() => _filter = v), count: _correctCount, color: AppColors.correct),
              const SizedBox(width: 8),
              _FilterTab(label: 'Skipped', value: 'skipped', selected: _filter, onTap: (v) => setState(() => _filter = v), count: _skippedCount, color: Colors.orange),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Answer list ────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🎉', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                  _filter == 'wrong'   ? 'No wrong answers!' :
                  _filter == 'correct' ? 'No correct answers' :
                  _filter == 'skipped' ? 'No skipped questions!' :
                  'No answers yet',
                  style: TextStyle(color: TC.subText(context), fontSize: 16)),
            ]))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final answer = _filtered[index];
                return _AnswerCard(answer: answer, number: _answers.indexOf(answer) + 1);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Answer card ───────────────────────────────────────────────────────────────
class _AnswerCard extends StatefulWidget {
  final dynamic answer;
  final int number;
  const _AnswerCard({required this.answer, required this.number});

  @override
  State<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<_AnswerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final answer     = widget.answer;
    final isCorrect  = answer['correct'] == true;
    final isSkipped  = answer['givenText'] == null && answer['choiceId'] == null;
    final givenText  = answer['givenText'] as String?;
    final questionText = answer['questionText'] as String? ?? 'Question ${widget.number}';
    final essayScore = answer['essayScore'];

    Color cardColor;
    IconData icon;
    String statusLabel;

    if (isSkipped) {
      cardColor   = Colors.orange;
      icon        = Icons.skip_next;
      statusLabel = 'Skipped';
    } else if (isCorrect) {
      cardColor   = AppColors.correct;
      icon        = Icons.check_circle;
      statusLabel = 'Correct';
    } else {
      cardColor   = AppColors.wrong;
      icon        = Icons.cancel;
      statusLabel = 'Wrong';
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: TC.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cardColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.2 : 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Number badge
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Center(child: Text('${widget.number}',
                    style: TextStyle(color: cardColor, fontSize: 12, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(questionText,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context), height: 1.3),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: cardColor, size: 14),
                  const SizedBox(width: 4),
                  Text(statusLabel, style: TextStyle(color: cardColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // ── Expanded details ──────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: TC.divider(context)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Your answer
                if (!isSkipped) ...[
                  Text('Your Answer', style: TextStyle(fontSize: 11, color: TC.subText(context), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.correct.withValues(alpha: 0.08)
                            : AppColors.wrong.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isCorrect
                                ? AppColors.correct.withValues(alpha: 0.3)
                                : AppColors.wrong.withValues(alpha: 0.3))),
                    child: Text(
                        givenText ?? '(no text answer)',
                        style: TextStyle(
                            fontSize: 14,
                            color: isCorrect ? AppColors.correct : AppColors.wrong,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Essay score if available
                if (essayScore != null) ...[
                  Text('Essay Score', style: TextStyle(fontSize: 11, color: TC.subText(context), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$essayScore pts',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Skipped message
                if (isSkipped)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                    child: const Text('You skipped this question.',
                        style: TextStyle(color: Colors.orange, fontSize: 13)),
                  ),
              ]),
            ),
          ],

          // Tap to expand hint
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: TC.subText(context), size: 16),
              const SizedBox(width: 4),
              Text(_expanded ? 'Tap to collapse' : 'Tap to see details',
                  style: TextStyle(fontSize: 11, color: TC.subText(context))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────
class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _FilterTab extends StatelessWidget {
  final String label, value, selected;
  final int count;
  final Color? color;
  final void Function(String) onTap;
  const _FilterTab({required this.label, required this.value, required this.selected, required this.onTap, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final tabColor   = color ?? AppColors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: isSelected ? tabColor : TC.card(context),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$count', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : TC.text(context))),
            Text(label, style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : TC.subText(context))),
          ]),
        ),
      ),
    );
  }
}