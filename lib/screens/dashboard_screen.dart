// lib/screens/dashboard_screen.dart
//
// This is what "Home" in the drawer navigates to.
// It shows a personal overview: greeting, XP, stats, streak, recent quizzes.
// "My Classrooms" stays on HomeScreen (the classroom list).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/xp_service.dart';
import 'package:quiz_app/providers/classrooms_provider.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/providers/pending_quizzes_provider.dart';
import 'package:quiz_app/screens/quiz_intro_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsProvider);
    final userId = ApiService.userId ?? 0;
    final userName = ApiService.name ?? 'Student';

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
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text('Dashboard',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: TC.text(context))),
            ]),
          ),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(classroomsProvider.notifier).syncAndReload();
                await ref.read(pendingQuizzesProvider.notifier).reload();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 4),

                  // ── Pending Quizzes ────────────────────────────────────
                  _PendingQuizzesSection(
                    onQuizTap: (QuizModel quiz) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizIntroScreen(quiz: quiz),
                        ),
                      ).then((_) =>
                          ref.read(pendingQuizzesProvider.notifier).reload());
                    },
                  ),

                  // ── Greeting ───────────────────────────────────────────
                  _GreetingCard(userName: userName),
                  const SizedBox(height: 16),

                  // ── XP & Level ─────────────────────────────────────────
                  _XpCard(userId: userId),
                  const SizedBox(height: 16),

                  // ── Quick stats ────────────────────────────────────────
                  _QuickStats(classroomsAsync: classroomsAsync),
                  const SizedBox(height: 16),

                  // ── Weekly streak ──────────────────────────────────────
                  _WeeklyStreak(userId: userId),
                  const SizedBox(height: 16),

                  // ── Recent activity ────────────────────────────────────
                  _RecentActivity(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Greeting card ─────────────────────────────────────────────────────────────
class _GreetingCard extends StatelessWidget {
  final String userName;
  const _GreetingCard({required this.userName});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _tip {
    final tips = [
      'Consistency beats perfection. Take one quiz today!',
      'Review your wrong answers — that\'s where growth happens.',
      'Short study sessions are more effective than long cramming.',
      'Every quiz you finish is a step toward mastery.',
      'Check if any quizzes have upcoming deadlines!',
    ];
    return tips[DateTime.now().day % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.darkCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('👋', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_greeting, ${userName.split(' ').first}!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline,
                color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tip,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── XP & Level card ───────────────────────────────────────────────────────────
class _XpCard extends StatefulWidget {
  final int userId;
  const _XpCard({required this.userId});

  @override
  State<_XpCard> createState() => _XpCardState();
}

class _XpCardState extends State<_XpCard> {
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    XpService().getXp(widget.userId).then((xp) {
      if (mounted) setState(() => _xp = xp);
    });
  }

  @override
  Widget build(BuildContext context) {
    final xpService  = XpService();
    final level      = xpService.getLevelFromXp(_xp);
    final levelName  = xpService.getLevelName(level);
    final progress   = xpService.levelProgress(_xp);
    final levelStart = xpService.xpForLevel(level);
    final levelEnd   = xpService.xpForNextLevel(level);
    final xpInLevel  = _xp - levelStart;
    final xpNeeded   = levelEnd - levelStart;

    Color levelColor;
    String levelIcon;
    if (level >= 18)      { levelColor = const Color(0xFFFF6B6B); levelIcon = '🔥'; }
    else if (level >= 15) { levelColor = const Color(0xFFFF9500); levelIcon = '⚡'; }
    else if (level >= 10) { levelColor = const Color(0xFFFFD700); levelIcon = '🌟'; }
    else if (level >= 5)  { levelColor = AppColors.primary;        levelIcon = '💎'; }
    else                  { levelColor = AppColors.correct;         levelIcon = '🎯'; }

    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(levelIcon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('Level $level · $levelName',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: TC.text(context))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: levelColor.withValues(alpha: 0.4)),
            ),
            child: Text('$_xp XP',
                style: TextStyle(
                    color: levelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: TC.card(context),
            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$xpInLevel / $xpNeeded XP',
              style: TextStyle(fontSize: 11, color: TC.subText(context))),
          Text(
            level >= 20 ? 'Max Level! 🎉' : 'to Level ${level + 1}',
            style: TextStyle(fontSize: 11, color: TC.subText(context)),
          ),
        ]),
      ]),
    );
  }
}

// ── Quick stats ───────────────────────────────────────────────────────────────
class _QuickStats extends StatefulWidget {
  final AsyncValue classroomsAsync;
  const _QuickStats({required this.classroomsAsync});

  @override
  State<_QuickStats> createState() => _QuickStatsState();
}

class _QuickStatsState extends State<_QuickStats> {
  int    _quizzesDone = 0;
  int    _avgPercent  = 0;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    try {
      final attempts = await ApiService.getMyAttempts();
      double totalScore = 0, totalPoints = 0;
      for (final a in attempts) {
        totalScore  += (a['score']       ?? 0).toDouble();
        totalPoints += (a['totalPoints'] ?? 0).toDouble();
      }
      if (mounted) {
        setState(() {
          _quizzesDone = attempts.length;
          _avgPercent  = totalPoints > 0
              ? (totalScore / totalPoints * 100).round()
              : 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final classroomCount = widget.classroomsAsync.valueOrNull?.length ?? 0;

    return Row(children: [
      Expanded(child: _StatBox(
        icon: Icons.school_outlined,
        label: 'Classrooms',
        value: '$classroomCount',
        color: AppColors.primary,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatBox(
        icon: Icons.quiz_outlined,
        label: 'Quizzes Done',
        value: '$_quizzesDone',
        color: AppColors.correct,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatBox(
        icon: Icons.percent,
        label: 'Avg Score',
        value: '$_avgPercent%',
        color: _avgPercent >= 75
            ? AppColors.correct
            : _avgPercent >= 50
            ? Colors.orange
            : _avgPercent == 0
            ? AppColors.primary
            : AppColors.wrong,
      )),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: TC.surface(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: TC.isDark(context) ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2))
      ],
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 10, color: TC.subText(context)),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Weekly streak ─────────────────────────────────────────────────────────────
class _WeeklyStreak extends StatefulWidget {
  final int userId;
  const _WeeklyStreak({required this.userId});

  @override
  State<_WeeklyStreak> createState() => _WeeklyStreakState();
}

class _WeeklyStreakState extends State<_WeeklyStreak> {
  // Which weekday indices (Mon=0 … Sun=6) had a submission this week
  final Set<int> _activeDays = {};
  int _streakCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final attempts = await ApiService.getMyAttempts();
      final now      = DateTime.now();
      // Monday of this week
      final monday   = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonday = DateTime(monday.year, monday.month, monday.day);

      final active = <int>{};
      for (final a in attempts) {
        try {
          final dt = DateTime.parse(a['submittedAt']).toLocal();
          if (dt.isAfter(startOfMonday)) {
            // weekday: Mon=1 … Sun=7 → index Mon=0 … Sun=6
            active.add(dt.weekday - 1);
          }
        } catch (_) {}
      }

      // Count consecutive streak ending today
      int streak = 0;
      for (int d = now.weekday - 1; d >= 0; d--) {
        if (active.contains(d)) streak++;
        else break;
      }

      if (mounted) setState(() { _activeDays.addAll(active); _streakCount = streak; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIndex = DateTime.now().weekday - 1; // Mon=0

    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
            _streakCount > 0 ? '🔥 $_streakCount-day streak!' : '📅 This week',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: TC.text(context)),
          ),
          const Spacer(),
          Text('Keep it going!',
              style: TextStyle(fontSize: 11, color: TC.subText(context))),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final isToday   = i == todayIndex;
            final isDone    = _activeDays.contains(i) && !isToday;
            final isActive  = _activeDays.contains(i) && isToday;
            final isFuture  = i > todayIndex;

            Color bgColor;
            Color textColor;
            if (isActive)       { bgColor = AppColors.primary; textColor = Colors.white; }
            else if (isDone)    { bgColor = AppColors.correct;  textColor = Colors.white; }
            else if (isFuture)  { bgColor = TC.card(context);   textColor = TC.subText(context); }
            else                { bgColor = AppColors.wrong.withValues(alpha: 0.12); textColor = AppColors.wrong; }

            return Column(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: isActive || isDone
                      ? Icon(Icons.check, color: Colors.white, size: 16)
                      : isFuture
                      ? Text(days[i][0],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor))
                      : Icon(Icons.close,
                      color: AppColors.wrong, size: 14),
                ),
              ),
              const SizedBox(height: 4),
              Text(days[i],
                  style: TextStyle(
                      fontSize: 9,
                      color: isToday
                          ? AppColors.primary
                          : TC.subText(context),
                      fontWeight:
                      isToday ? FontWeight.bold : FontWeight.normal)),
            ]);
          }),
        ),
      ]),
    );
  }
}

// ── Recent activity ───────────────────────────────────────────────────────────
class _RecentActivity extends StatefulWidget {
  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  List<dynamic> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ApiService.getMyAttempts();
      // Sort by submittedAt descending, take top 3
      all.sort((a, b) {
        try {
          return DateTime.parse(b['submittedAt'])
              .compareTo(DateTime.parse(a['submittedAt']));
        } catch (_) { return 0; }
      });
      if (mounted) setState(() => _recent = all.take(3).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Recent Activity',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: TC.text(context))),
      ),
      if (_recent.isEmpty)
        _SectionCard(
          child: Row(children: [
            Icon(Icons.history_edu, color: TC.subText(context), size: 28),
            const SizedBox(width: 12),
            Text('No quizzes taken yet.',
                style: TextStyle(color: TC.subText(context), fontSize: 13)),
          ]),
        )
      else
        _SectionCard(
          child: Column(
            children: _recent.asMap().entries.map((entry) {
              final i       = entry.key;
              final attempt = entry.value;
              final score   = (attempt['score']       ?? 0).toDouble();
              final total   = (attempt['totalPoints'] ?? 0).toDouble();
              final percent = total > 0 ? (score / total * 100).round() : 0;
              final title   = attempt['quizTitle'] ?? 'Quiz';
              final isOffline = (attempt['attemptId'] ?? attempt['id']) == -1;

              String dateStr = '';
              try {
                final dt = DateTime.parse(attempt['submittedAt']).toLocal();
                final diff = DateTime.now().difference(dt);
                if (diff.inDays == 0)      dateStr = 'Today';
                else if (diff.inDays == 1) dateStr = 'Yesterday';
                else                       dateStr = '${diff.inDays}d ago';
              } catch (_) {}

              final Color scoreColor = isOffline
                  ? Colors.orange
                  : percent >= 75
                  ? AppColors.correct
                  : percent >= 50
                  ? Colors.orange
                  : AppColors.wrong;

              return Column(children: [
                if (i > 0)
                  Divider(height: 1, color: TC.divider(context)),
                if (i > 0) const SizedBox(height: 10),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: scoreColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: TC.text(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(dateStr,
                              style: TextStyle(
                                  fontSize: 11, color: TC.subText(context))),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOffline ? 'Pending' : '$percent%',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: scoreColor),
                  ),
                ]),
                if (i < _recent.length - 1) const SizedBox(height: 10),
              ]);
            }).toList(),
          ),
        ),
    ]);
  }
}

// ── Pending Quizzes Section ───────────────────────────────────────────────────

class _PendingQuizzesSection extends ConsumerWidget {
  final void Function(QuizModel quiz) onQuizTap;
  const _PendingQuizzesSection({required this.onQuizTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingQuizzesProvider);

    return pendingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pending) {
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.confirm.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.confirm, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pending.length} Pending',
                    style: const TextStyle(
                      color: AppColors.confirm,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Text('Quizzes',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: TC.text(context),
                  )),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pending.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = pending[index];
                  return _PendingQuizCard(
                    item: item,
                    onTap: () => onQuizTap(item.quiz),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _PendingQuizCard extends StatelessWidget {
  final PendingQuiz  item;
  final VoidCallback onTap;
  const _PendingQuizCard({required this.item, required this.onTap});

  String _formatDeadline(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inHours < 1)  return 'Due in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    if (diff.inDays == 1)  return 'Due tomorrow';
    return 'Due in ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final deadline = item.quiz.deadlineDateTime;
    final isUrgent = deadline != null &&
        deadline.difference(DateTime.now()).inHours < 24;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [AppColors.confirm.withValues(alpha: 0.85),
              AppColors.confirm.withValues(alpha: 0.55)]
                : [AppColors.primary, AppColors.darkCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: (isUrgent ? AppColors.confirm : AppColors.primary)
                .withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 4),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.quiz.title,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(item.classroomName,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
            Row(children: [
              const Icon(Icons.quiz_outlined, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${item.quiz.questionCount} Qs',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              if (deadline != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_formatDeadline(deadline),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
                      )),
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white54),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TC.surface(context),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: Colors.black
                .withValues(alpha: TC.isDark(context) ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3))
      ],
    ),
    child: child,
  );
}