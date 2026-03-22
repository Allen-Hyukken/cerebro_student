import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/services/xp_service.dart';

class XpPopup extends StatefulWidget {
  final int xpEarned;
  final int totalXp;
  final bool leveledUp;
  final int newLevel;
  final String levelName;

  const XpPopup({
    super.key,
    required this.xpEarned,
    required this.totalXp,
    required this.leveledUp,
    required this.newLevel,
    required this.levelName,
  });

  /// Show the XP popup over any screen
  static Future<void> show(BuildContext context, {
    required int xpEarned,
    required int oldXp,
    required int newXp,
  }) async {
    final xpService = XpService();
    final oldLevel  = xpService.getLevelFromXp(oldXp);
    final newLevel  = xpService.getLevelFromXp(newXp);
    final leveledUp = newLevel > oldLevel;
    final levelName = xpService.getLevelName(newLevel);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.center,
        child: XpPopup(
          xpEarned:  xpEarned,
          totalXp:   newXp,
          leveledUp: leveledUp,
          newLevel:  newLevel,
          levelName: levelName,
        ),
      ),
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<XpPopup> createState() => _XpPopupState();
}

class _XpPopupState extends State<XpPopup> with TickerProviderStateMixin {
  late AnimationController _barController;
  late AnimationController _countController;
  late Animation<double> _barAnim;
  late Animation<int>    _countAnim;

  @override
  void initState() {
    super.initState();
    final xpService  = XpService();
    final level      = widget.newLevel;
    final oldXp      = widget.totalXp - widget.xpEarned;
    final levelStart = xpService.xpForLevel(level);
    final levelEnd   = xpService.xpForNextLevel(level);
    final oldProg    = levelEnd > levelStart
        ? ((oldXp - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0) : 0.0;
    final newProg    = xpService.levelProgress(widget.totalXp);

    _barController   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _countController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _barAnim   = Tween<double>(begin: oldProg, end: newProg)
        .animate(CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic));
    _countAnim = IntTween(begin: 0, end: widget.xpEarned)
        .animate(CurvedAnimation(parent: _countController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) { _countController.forward(); _barController.forward(); }
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _barController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Color get _color {
    final l = widget.newLevel;
    if (l >= 18) return const Color(0xFFFF6B6B);
    if (l >= 15) return const Color(0xFFFF9500);
    if (l >= 10) return const Color(0xFFFFD700);
    if (l >= 5)  return AppColors.primary;
    return AppColors.correct;
  }

  String get _icon {
    final l = widget.newLevel;
    if (l >= 18) return '🔥';
    if (l >= 15) return '⚡';
    if (l >= 10) return '🌟';
    if (l >= 5)  return '💎';
    return '🎯';
  }

  @override
  Widget build(BuildContext context) {
    final xpService  = XpService();
    final level      = widget.newLevel;
    final levelStart = xpService.xpForLevel(level);
    final levelEnd   = xpService.xpForNextLevel(level);
    final xpInLevel  = widget.totalXp - levelStart;
    final xpNeeded   = levelEnd - levelStart;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: TC.surface(context),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Level up banner
                if (widget.leveledUp) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.6)]),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      const Text('🎊 LEVEL UP! 🎊',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text('You are now Level ${widget.newLevel} · ${widget.levelName}!',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Icon
                Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _color.withValues(alpha: 0.12),
                        border: Border.all(color: _color, width: 2.5)),
                    child: Center(child: Text(_icon, style: const TextStyle(fontSize: 34)))),
                const SizedBox(height: 16),

                // XP counter
                AnimatedBuilder(
                    animation: _countAnim,
                    builder: (_, __) => Text('+${_countAnim.value} XP',
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: _color))),
                const SizedBox(height: 4),
                Text('Quiz completed!',
                    style: TextStyle(fontSize: 14, color: TC.subText(context))),

                const SizedBox(height: 20),

                // Level info
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Level $level · ${widget.levelName}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TC.text(context))),
                  Text('${widget.totalXp} XP',
                      style: TextStyle(fontSize: 12, color: TC.subText(context))),
                ]),
                const SizedBox(height: 8),

                // Animated XP bar
                AnimatedBuilder(
                  animation: _barAnim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: _barAnim.value, minHeight: 12,
                        backgroundColor: TC.card(context),
                        valueColor: AlwaysStoppedAnimation<Color>(_color)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$xpInLevel / $xpNeeded XP',
                      style: TextStyle(fontSize: 11, color: TC.subText(context))),
                  Text(level >= 20 ? 'Max Level!' : 'to Level ${level + 1}',
                      style: TextStyle(fontSize: 11, color: TC.subText(context))),
                ]),

                const SizedBox(height: 20),
                Text('Tap anywhere to continue',
                    style: TextStyle(fontSize: 11, color: TC.subText(context))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}