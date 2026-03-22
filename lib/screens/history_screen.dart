import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _attempts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadAttempts(); }

  Future<void> _loadAttempts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getMyAttempts();
      setState(() => _attempts = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back, color: TC.text(context)),
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Text('Quiz History', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: TC.text(context))),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _loadAttempts),
            ]),
          ),

          // ── Summary stats ─────────────────────────────────────────────────
          if (!_isLoading && _error == null && _attempts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SummaryCard(attempts: _attempts),
            ),

          const SizedBox(height: 12),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wifi_off, color: TC.subText(context), size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: TC.subText(context)), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadAttempts,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Retry')),
            ]))
                : _attempts.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history_edu, color: TC.subText(context), size: 72),
              const SizedBox(height: 16),
              Text('No quiz history yet.', style: TextStyle(color: TC.subText(context), fontSize: 16)),
              const SizedBox(height: 8),
              Text('Your submitted quizzes will appear here.',
                  style: TextStyle(color: TC.subText(context), fontSize: 13), textAlign: TextAlign.center),
            ]))
                : RefreshIndicator(
              onRefresh: _loadAttempts,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _attempts.length,
                itemBuilder: (context, index) =>
                    _AttemptCard(attempt: _attempts[index]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final List<dynamic> attempts;
  const _SummaryCard({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final total = attempts.length;
    double totalScore = 0, totalPoints = 0;
    for (final a in attempts) {
      totalScore  += (a['score']       ?? 0).toDouble();
      totalPoints += (a['totalPoints'] ?? 0).toDouble();
    }
    final avgPercent = totalPoints > 0 ? (totalScore / totalPoints * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.darkCard],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Expanded(child: _SumStat(label: 'Quizzes\nTaken', value: '$total')),
        Container(width: 1, height: 40, color: Colors.white24),
        Expanded(child: _SumStat(label: 'Total\nScore', value: '${totalScore.toStringAsFixed(0)}')),
        Container(width: 1, height: 40, color: Colors.white24),
        Expanded(child: _SumStat(label: 'Average\nScore', value: '$avgPercent%')),
      ]),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label, value;
  const _SumStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
  ]);
}

// ── Attempt card ──────────────────────────────────────────────────────────────
class _AttemptCard extends StatelessWidget {
  final dynamic attempt;
  const _AttemptCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final score        = (attempt['score']          ?? 0).toDouble();
    final totalPoints  = (attempt['totalPoints']    ?? 0).toDouble();
    final totalQ       = attempt['totalQuestions']  ?? 0;
    final answeredQ    = attempt['answeredCount']   ?? 0;
    final skippedQ     = attempt['skippedCount']    ?? 0;
    final quizTitle    = attempt['quizTitle']       ?? 'Quiz';
    final submittedAt  = attempt['submittedAt']     ?? '';
    final percent      = totalPoints > 0 ? (score / totalPoints * 100).round() : 0;
    final isOffline    = (attempt['attemptId'] ?? attempt['id']) == -1;

    String dateStr = '';
    try {
      final dt = DateTime.parse(submittedAt).toLocal();
      dateStr = '${dt.month}/${dt.day}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { dateStr = submittedAt; }

    Color scoreColor = isOffline ? Colors.orange
        : percent >= 75 ? AppColors.correct
        : percent >= 50 ? Colors.orange
        : AppColors.wrong;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: TC.surface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.2 : 0.05),
              blurRadius: 8, offset: const Offset(0, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Title + score badge
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(quizTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TC.text(context)),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.4))),
                child: Text(
                    isOffline ? 'Pending' : '$percent%',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 14))),
          ]),

          const SizedBox(height: 12),

          // Score bar
          if (!isOffline && totalPoints > 0) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${score.toStringAsFixed(1)} / ${totalPoints.toStringAsFixed(1)} pts',
                  style: TextStyle(fontSize: 12, color: TC.subText(context))),
              Text('$answeredQ/$totalQ answered',
                  style: TextStyle(fontSize: 12, color: TC.subText(context))),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: totalPoints > 0 ? score / totalPoints : 0,
                    minHeight: 6,
                    backgroundColor: TC.card(context),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor))),
            const SizedBox(height: 12),
          ],

          // Stats row
          Row(children: [
            _MiniStat(icon: Icons.quiz_outlined,  label: '$totalQ Qs',        color: AppColors.primary),
            const SizedBox(width: 16),
            _MiniStat(icon: Icons.check_outlined, label: '$answeredQ Done',   color: AppColors.correct),
            const SizedBox(width: 16),
            _MiniStat(icon: Icons.skip_next,      label: '$skippedQ Skipped', color: Colors.orange),
            const Spacer(),
            if (isOffline)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.wifi_off, size: 11, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('Offline', style: TextStyle(fontSize: 10, color: Colors.orange)),
                  ])),
          ]),

          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: TC.divider(context)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 13, color: TC.subText(context)),
              const SizedBox(width: 4),
              Text(dateStr, style: TextStyle(fontSize: 11, color: TC.subText(context))),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
  ]);
}