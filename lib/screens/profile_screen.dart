import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/providers/auth_provider.dart';
import 'package:quiz_app/providers/xp_provider.dart';
import 'package:quiz_app/providers/theme_provider.dart';
import 'package:quiz_app/services/xp_service.dart';
import 'package:quiz_app/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final xpState   = ref.watch(xpProvider);
    final isDark    = ref.watch(themeProvider);

    final user  = authState.user;
    final name  = user?.name  ?? 'Student';
    final email = user?.email ?? '';
    final role  = user?.role  ?? 'STUDENT';

    final level       = xpState.level;
    final levelName   = xpState.levelName;
    final progress    = xpState.levelProgress;
    final xpThisLevel = xpState.xp - xpState.xpForLevel;
    final xpNextLevel = xpState.xpForNext - xpState.xpForLevel;

    Color levelColor;
    if      (level >= 18) levelColor = const Color(0xFFFF6B6B);
    else if (level >= 15) levelColor = const Color(0xFFFF9500);
    else if (level >= 10) levelColor = const Color(0xFFFFD700);
    else if (level >= 5)  levelColor = AppColors.primary;
    else                  levelColor = AppColors.correct;

    if (xpState.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: TC.text(context)),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text('Profile',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: TC.text(context),
                  )),
              const Spacer(),
              const SizedBox(width: 48),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [

                // ── Avatar ─────────────────────────────────────────────────
                Stack(alignment: Alignment.bottomRight, children: [
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context, ref, xpState.avatarIndex),
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary, width: 3),
                        boxShadow: [BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20, offset: const Offset(0, 8),
                        )],
                      ),
                      child: Center(child: Text(
                        xpState.emoji,
                        style: const TextStyle(fontSize: 52),
                      )),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context, ref, xpState.avatarIndex),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: TC.bg(context), width: 2),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // ── Name + role ────────────────────────────────────────────
                Text(name,
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      color: TC.text(context),
                    )),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(role,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                ),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(fontSize: 13, color: TC.subText(context))),

                const SizedBox(height: 20),

                // ── XP & Level card ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [levelColor, levelColor.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: levelColor.withValues(alpha: 0.35),
                      blurRadius: 16, offset: const Offset(0, 6),
                    )],
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        child: Center(child: Text(
                          '$level',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $level · $levelName',
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${xpState.xp} XP total',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 13,
                            ),
                          ),
                        ],
                      )),
                      Text(
                        level >= 18 ? '🔥' :
                        level >= 15 ? '⚡' :
                        level >= 10 ? '🌟' :
                        level >= 5  ? '💎' : '🎯',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('$xpThisLevel XP',
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 11,
                          )),
                      Text('Next level: $xpNextLevel XP',
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 11,
                          )),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress, minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      level >= 20
                          ? '🎉 Max Level Reached!'
                          : '${((1 - progress) * xpNextLevel).round()} XP to Level ${level + 1}',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Info card ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: TC.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(
                        alpha: TC.isDark(context) ? 0.2 : 0.05,
                      ),
                      blurRadius: 10, offset: const Offset(0, 4),
                    )],
                  ),
                  child: Column(children: [
                    _InfoRow(icon: Icons.person_outline,  label: 'Full Name', value: name),
                    Divider(height: 1, indent: 56, color: TC.divider(context)),
                    _InfoRow(icon: Icons.email_outlined,  label: 'Email',     value: email),
                    Divider(height: 1, indent: 56, color: TC.divider(context)),
                    _InfoRow(icon: Icons.school_outlined, label: 'Role',      value: role),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Settings card ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: TC.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(
                        alpha: TC.isDark(context) ? 0.2 : 0.05,
                      ),
                      blurRadius: 10, offset: const Offset(0, 4),
                    )],
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4,
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: AppColors.primary, size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 15, color: TC.text(context),
                            fontWeight: FontWeight.w500,
                          ),
                        )),
                        Switch(
                          value: isDark,
                          onChanged: (val) =>
                              ref.read(themeProvider.notifier).setDark(val),
                          activeColor: AppColors.primary,
                        ),
                      ]),
                    ),
                    Divider(height: 1, indent: 56, color: TC.divider(context)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16,
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.info_outline,
                              color: Colors.grey, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(
                          'App Version',
                          style: TextStyle(
                            fontSize: 15, color: TC.text(context),
                            fontWeight: FontWeight.w500,
                          ),
                        )),
                        Text('3.2.31',
                            style: TextStyle(
                              fontSize: 14, color: TC.subText(context),
                            )),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Logout ─────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────

  void _showAvatarPicker(
      BuildContext context,
      WidgetRef ref,
      int currentIndex,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose Avatar',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold,
            color: TC.text(context),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Consumer(builder: (_, ref2, __) {
            final selectedIndex = ref2.watch(
              xpProvider.select((s) => s.avatarIndex),
            );
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: XpService.avatarEmojis.length,
              itemBuilder: (_, i) {
                final isSelected = i == selectedIndex;
                return GestureDetector(
                  onTap: () async {
                    await ref.read(xpProvider.notifier).setAvatarIndex(i);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : TC.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(child: Text(
                      XpService.avatarEmojis[i],
                      style: const TextStyle(fontSize: 26),
                    )),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Logout confirm ────────────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?',
            style: TextStyle(
              fontWeight: FontWeight.bold, color: TC.text(context),
            )),
        content: Text('Are you sure?',
            style: TextStyle(color: TC.subText(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: TC.subText(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wrong, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    }
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
              fontSize: 11, color: TC.subText(context),
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 15, color: TC.text(context),
              fontWeight: FontWeight.w500,
            )),
      ])),
    ]),
  );
}