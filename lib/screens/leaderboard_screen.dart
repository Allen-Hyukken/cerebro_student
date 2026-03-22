import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final QuizModel quiz;
  const LeaderboardScreen({super.key, required this.quiz});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getQuizLeaderboard(widget.quiz.id);
      setState(() => _entries = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int get _myRank {
    for (final e in _entries) {
      if (e['userId'] == ApiService.userId) return e['rank'] as int;
    }
    return -1;
  }

  String _rankEmoji(int r) {
    if (r == 1) return '🥇';
    if (r == 2) return '🥈';
    if (r == 3) return '🥉';
    if (r <= 10) return '🏅';
    return '#$r';
  }

  @override
  Widget build(BuildContext context) {
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Leaderboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TC.text(context))),
                Text(widget.quiz.title,
                    style: TextStyle(fontSize: 12, color: TC.subText(context)),
                    overflow: TextOverflow.ellipsis),
              ])),
              IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _load),
            ]),
          ),

          // ── Quiz info card ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.darkCard],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.leaderboard, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.quiz.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  Text('${widget.quiz.totalPoints} pts total · ${_entries.length} students submitted',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                if (_myRank > 0)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('You: #$_myRank',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── Top 3 podium ───────────────────────────────────────────────
          if (!_isLoading && _error == null && _entries.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Podium(entries: _entries, totalPoints: widget.quiz.totalPoints),
            ),

          const SizedBox(height: 12),

          // ── Full list ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: TC.subText(context)), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Retry')),
            ]))
                : _entries.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('No submissions yet.',
                  style: TextStyle(color: TC.subText(context), fontSize: 16)),
              const SizedBox(height: 8),
              Text('Be the first to complete this quiz!',
                  style: TextStyle(color: TC.subText(context), fontSize: 13)),
            ]))
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final isMe  = entry['userId'] == ApiService.userId;
                  return _LeaderboardRow(
                      entry: entry, isMe: isMe,
                      totalPoints: widget.quiz.totalPoints);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List<dynamic> entries;
  final double totalPoints;
  const _Podium({required this.entries, required this.totalPoints});

  @override
  Widget build(BuildContext context) {
    final first  = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1  ? entries[1] : null;
    final third  = entries.length > 2  ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: TC.surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.2 : 0.05),
              blurRadius: 8, offset: const Offset(0, 3))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (second != null)
          Expanded(child: _PodiumSlot(entry: second, height: 80,
              medal: '🥈', color: Colors.grey.shade400, totalPoints: totalPoints)),
        const SizedBox(width: 8),
        if (first != null)
          Expanded(child: _PodiumSlot(entry: first, height: 110,
              medal: '🥇', color: const Color(0xFFFFD700), totalPoints: totalPoints)),
        const SizedBox(width: 8),
        if (third != null)
          Expanded(child: _PodiumSlot(entry: third, height: 65,
              medal: '🥉', color: const Color(0xFFCD7F32), totalPoints: totalPoints)),
      ]),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final dynamic entry;
  final double height, totalPoints;
  final String medal;
  final Color color;
  const _PodiumSlot({required this.entry, required this.height,
    required this.medal, required this.color, required this.totalPoints});

  String get _initials {
    final parts = (entry['name'] as String? ?? '?').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isMe  = entry['userId'] == ApiService.userId;
    final score = (entry['score'] ?? 0).toDouble();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(medal, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: isMe ? Border.all(color: AppColors.primary, width: 3) : null,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]),
          child: Center(child: Text(_initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
      const SizedBox(height: 6),
      Text(entry['name'] as String? ?? '',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: isMe ? AppColors.primary : TC.text(context)),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text('${score.toStringAsFixed(1)} pts',
          style: TextStyle(fontSize: 11, color: TC.subText(context))),
      const SizedBox(height: 8),
      Container(
          height: height,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              border: Border(
                  top:   BorderSide(color: color, width: 2),
                  left:  BorderSide(color: color.withValues(alpha: 0.4)),
                  right: BorderSide(color: color.withValues(alpha: 0.4)))),
          child: Center(child: Text('#${entry['rank']}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)))),
    ]);
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final dynamic entry;
  final bool isMe;
  final double totalPoints;
  const _LeaderboardRow({required this.entry, required this.isMe, required this.totalPoints});

  String get _initials {
    final parts = (entry['name'] as String? ?? '?').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Color get _avatarColor {
    final colors = [AppColors.primary, AppColors.correct, AppColors.wrong,
      Colors.orange, Colors.purple, Colors.teal, Colors.indigo];
    return colors[(entry['rank'] as int) % colors.length];
  }

  String _rankLabel(int r) {
    if (r == 1) return '🥇';
    if (r == 2) return '🥈';
    if (r == 3) return '🥉';
    return '#$r';
  }

  @override
  Widget build(BuildContext context) {
    final rank    = entry['rank'] as int;
    final score   = (entry['score'] ?? 0).toDouble();
    final percent = entry['percent'] ?? 0;

    // Format date
    String dateStr = '';
    try {
      final dt = DateTime.parse(entry['submittedAt']).toLocal();
      dateStr = '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {}

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withValues(alpha: TC.isDark(context) ? 0.25 : 0.08)
              : TC.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: isMe ? Border.all(color: AppColors.primary, width: 2) : null,
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.15 : 0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        SizedBox(width: 36,
            child: Text(_rankLabel(rank),
                style: TextStyle(
                    fontSize: rank <= 3 ? 22 : 14,
                    fontWeight: FontWeight.bold,
                    color: TC.text(context)),
                textAlign: TextAlign.center)),
        const SizedBox(width: 12),

        // Avatar
        Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _avatarColor,
                boxShadow: [BoxShadow(color: _avatarColor.withValues(alpha: 0.3), blurRadius: 6)]),
            child: Center(child: Text(_initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
        const SizedBox(width: 12),

        // Name + bar
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? '${entry['name']} (You)' : entry['name'] as String? ?? '',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: isMe ? AppColors.primary : TC.text(context)),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalPoints > 0 ? score / totalPoints : 0,
              minHeight: 4,
              backgroundColor: TC.card(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                  rank == 1 ? const Color(0xFFFFD700)
                      : rank == 2 ? Colors.grey.shade400
                      : rank == 3 ? const Color(0xFFCD7F32)
                      : AppColors.primary),
            ),
          ),
          const SizedBox(height: 2),
          Text('$percent% · $dateStr',
              style: TextStyle(fontSize: 11, color: TC.subText(context))),
        ])),

        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(score.toStringAsFixed(1),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: isMe ? AppColors.primary : TC.text(context))),
          Text('pts', style: TextStyle(fontSize: 10, color: TC.subText(context))),
        ]),
      ]),
    );
  }
}