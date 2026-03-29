import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/providers/auth_provider.dart';
import 'package:quiz_app/providers/classrooms_provider.dart';
import 'package:quiz_app/providers/theme_provider.dart';
import 'package:quiz_app/providers/sound_provider.dart';
import 'package:quiz_app/services/sound_service.dart';
import 'package:quiz_app/screens/course_detail_screen.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/history_screen.dart';
import 'package:quiz_app/widgets/user_avatar.dart';
import 'package:quiz_app/screens/memory_game_screen.dart';
import 'package:quiz_app/screens/profile_screen.dart';
import 'package:quiz_app/screens/dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(classroomsProvider.notifier).syncAndReload();
    }
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  void _showJoinClassDialog() {
    final codeController = TextEditingController();
    bool    joining  = false;
    bool    success  = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final isDark = TC.isDark(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: TC.surface(context),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: success
                ? _JoinSuccessBody(onDone: () {
              Navigator.pop(ctx);
              ref.read(classroomsProvider.notifier).reload();
            })
                : _JoinFormBody(
              controller: codeController,
              isDark: isDark,
              errorMsg: errorMsg,
              joining: joining,
              onCancel: () => Navigator.pop(ctx),
              onJoin: () async {
                final code = codeController.text.trim();
                if (code.length < 4) {
                  setS(() => errorMsg = 'Enter a valid class code.');
                  return;
                }
                setS(() { joining = true; errorMsg = null; });
                try {
                  await ApiService.joinClassroom(code);
                  setS(() { joining = false; success = true; });
                } catch (e) {
                  setS(() {
                    joining  = false;
                    errorMsg = e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
              onErrorChanged: (_) {
                if (errorMsg != null) setS(() => errorMsg = null);
              },
            ),
          ),
        );
      }),
    );
  }

  // ── Music picker — only Default and LOCK-IN ───────────────────────────────
  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('Choose Music',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: TC.text(context),
              )),
          const SizedBox(height: 16),
          ...MusicTrack.values.map((track) {
            final current = ref.read(soundProvider).track;
            final isSelected = current == track;
            return GestureDetector(
              onTap: () async {
                await ref.read(soundProvider.notifier).setTrack(track);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : TC.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(children: [
                  Text(track.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(track.label,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : TC.text(context),
                      ))),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);
    final filteredList    = ref.watch(filteredClassroomsProvider);
    final isDark          = ref.watch(themeProvider);
    final sound           = ref.watch(soundProvider);
    final authState       = ref.watch(authProvider);

    final userName  = authState.user?.name  ?? 'Student';
    final userEmail = authState.user?.email ?? '';

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Stack(children: [

          // ── Main content ──────────────────────────────────────────────────
          Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.menu, color: TC.text(context)),
                  onPressed: () => setState(() => _drawerOpen = true),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: TC.text(context)),
                  onPressed: _showJoinClassDialog,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (q) =>
                    ref.read(classroomSearchProvider.notifier).state = q,
                    onClear: () {
                      _searchController.clear();
                      ref.read(classroomSearchProvider.notifier).state = '';
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _AppLogoCircle(),
              ]),
            ),

            Expanded(
              child: classroomsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => _ErrorBody(
                  message: err.toString().replaceAll('Exception: ', ''),
                  onRetry: () =>
                      ref.read(classroomsProvider.notifier).syncAndReload(),
                ),
                data: (_) => filteredList.isEmpty
                    ? _EmptyClassroomsBody()
                    : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(classroomsProvider.notifier).syncAndReload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final c = filteredList[index];
                      return _ClassroomCard(
                        classroom: c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(classroom: c),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ]),

          // ── Drawer ────────────────────────────────────────────────────────
          if (_drawerOpen)
            GestureDetector(
              onTap: _closeDrawer,
              child: Container(
                color: Colors.black54,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.only(
                          topRight:    Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: SafeArea(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: _closeDrawer,
                              ),
                              const SizedBox(width: 8),
                              const Text('Settings',
                                  style: TextStyle(
                                    color: Colors.white, fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ]),
                          ),

                          // User info
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(children: [
                              const UserAvatar(size: 56, borderColor: Colors.white),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(userEmail,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              )),
                            ]),
                          ),

                          const _DrawerDivider(),
                          const SizedBox(height: 8),

                          Flexible(child: SingleChildScrollView(child: Column(children: [

                            // ── Home → Dashboard ──────────────────────────
                            _DrawerItem(Icons.home_outlined, 'Home', () {
                              _closeDrawer();
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const DashboardScreen(),
                              ));
                            }),

                            // ── My Classrooms → stay here ─────────────────
                            _DrawerItem(Icons.book_outlined, 'My Classrooms', () {
                              _closeDrawer();
                              ref.read(classroomsProvider.notifier).reload();
                            }),

                            _DrawerItem(Icons.history_edu, 'Quiz History', () {
                              _closeDrawer();
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const HistoryScreen(),
                              ));
                            }),
                            _DrawerItem(Icons.person_outline, 'Profile', () {
                              _closeDrawer();
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ));
                            }),
                            _DrawerItem(Icons.add_circle_outline, 'Join a Class', () {
                              _closeDrawer();
                              _showJoinClassDialog();
                            }),
                            _DrawerItem(Icons.games_outlined, 'Cortisol Reset', () {
                              _closeDrawer();
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const MemoryGameScreen(),
                              ));
                            }),
                            _DrawerItem(Icons.sync_outlined, 'Sync Now', () async {
                              _closeDrawer();
                              await ref.read(classroomsProvider.notifier).syncAndReload();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Synced!'),
                                    backgroundColor: AppColors.correct,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }),

                            const _DrawerDivider(),

                            // Dark Mode toggle
                            _DrawerToggle(
                              icon: isDark ? Icons.dark_mode : Icons.light_mode,
                              label: 'Dark Mode',
                              value: isDark,
                              onChanged: (val) =>
                                  ref.read(themeProvider.notifier).setDark(val),
                            ),

                            // Music toggle + picker
                            _DrawerMusicRow(
                              enabled: sound.enabled,
                              onToggle: () =>
                                  ref.read(soundProvider.notifier).toggle(),
                              onPickTrack: sound.enabled ? _showMusicPicker : null,
                              currentTrackLabel: sound.track.label,
                            ),

                            _DrawerItem(Icons.info_outline, 'About', () {
                              _closeDrawer();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: TC.surface(context),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: Text('Cerebro Metron',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: TC.text(context))),
                                  content: Text(
                                      'A quiz app for students.\nVersion 3.2.31',
                                      style: TextStyle(color: TC.subText(context))),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK')),
                                  ],
                                ),
                              );
                            }),
                          ]))),

                          // Logout
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: GestureDetector(
                              onTap: _logout,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.logout, color: Colors.white, size: 22),
                                  SizedBox(width: 14),
                                  Text('Log Out',
                                      style: TextStyle(
                                        color: Colors.white, fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      )),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Drawer helpers ────────────────────────────────────────────────────────────

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();
  @override
  Widget build(BuildContext context) => const Divider(
    color: Colors.white24, thickness: 1, indent: 20, endIndent: 20,
  );
}

class _DrawerItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _DrawerItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Colors.white70, size: 22),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
    onTap: onTap,
    horizontalTitleGap: 8,
  );
}

class _DrawerToggle extends StatelessWidget {
  final IconData           icon;
  final String             label;
  final bool               value;
  final ValueChanged<bool> onChanged;
  const _DrawerToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      Icon(icon, color: Colors.white70, size: 22),
      const SizedBox(width: 16),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 15))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.darkCard,
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: Colors.white24,
      ),
    ]),
  );
}

class _DrawerMusicRow extends StatelessWidget {
  final bool          enabled;
  final VoidCallback  onToggle;
  final VoidCallback? onPickTrack;
  final String        currentTrackLabel;
  const _DrawerMusicRow({
    required this.enabled,
    required this.onToggle,
    required this.currentTrackLabel,
    this.onPickTrack,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      const Icon(Icons.music_note, color: Colors.white70, size: 22),
      const SizedBox(width: 16),
      Expanded(
        child: GestureDetector(
          onTap: onPickTrack,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Music',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            if (enabled)
              Text(currentTrackLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ),
      ),
      if (enabled)
        GestureDetector(
          onTap: onPickTrack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Change',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ),
      Switch(
        value: enabled,
        onChanged: (_) => onToggle(),
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.darkCard,
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: Colors.white24,
      ),
    ]),
  );
}

// ── Join class dialog bodies ──────────────────────────────────────────────────

class _JoinSuccessBody extends StatelessWidget {
  final VoidCallback onDone;
  const _JoinSuccessBody({required this.onDone});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
            color: AppColors.correct.withValues(alpha: 0.12),
            shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, color: AppColors.correct, size: 44),
      ),
      const SizedBox(height: 20),
      Text("You've joined the class!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: TC.text(context)),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('The class has been added to your list.',
          style: TextStyle(fontSize: 13, color: TC.subText(context)),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );
}

class _JoinFormBody extends StatelessWidget {
  final TextEditingController    controller;
  final bool                     isDark;
  final String?                  errorMsg;
  final bool                     joining;
  final VoidCallback             onCancel;
  final VoidCallback             onJoin;
  final ValueChanged<String>     onErrorChanged;
  const _JoinFormBody({
    required this.controller, required this.isDark,
    required this.errorMsg,   required this.joining,
    required this.onCancel,   required this.onJoin,
    required this.onErrorChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text('Join a Class',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: TC.text(context)))),
        IconButton(
          onPressed: onCancel,
          icon: Icon(Icons.close, color: TC.subText(context)),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
      const SizedBox(height: 6),
      Text('Enter the class code from your teacher.',
          style: TextStyle(color: TC.subText(context), fontSize: 13)),
      const SizedBox(height: 20),
      TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        maxLength: 8,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 22,
            fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primary),
        onChanged: onErrorChanged,
        decoration: InputDecoration(
          counterText: '', hintText: 'ABC123',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkSubText : Colors.grey.shade300,
            fontFamily: 'monospace', fontSize: 22,
            letterSpacing: 6, fontWeight: FontWeight.bold,
          ),
          filled: true, fillColor: TC.bg(context),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
      if (errorMsg != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.error_outline, color: AppColors.wrong, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(errorMsg!,
              style: const TextStyle(color: AppColors.wrong, fontSize: 12))),
        ]),
      ],
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: joining ? null : onJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          ),
          child: joining
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Join Class',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )),
      ]),
    ],
  );
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _AppLogoCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primary, width: 2),
      color: TC.surface(context),
    ),
    child: ClipOval(child: Image.asset('assets/icons/icon.png', fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.psychology, size: 22, color: AppColors.primary))),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  final VoidCallback          onClear;
  const _SearchBar({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      color: TC.surface(context),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: TextField(
      controller: controller,
      style: TextStyle(color: TC.text(context)),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: TextStyle(color: TC.subText(context), fontSize: 14),
        prefixIcon: Icon(Icons.search, color: TC.subText(context), size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: Icon(Icons.close, size: 18, color: TC.subText(context)),
            onPressed: onClear)
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _ErrorBody extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.wifi_off, color: TC.subText(context), size: 48),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message.contains('cached')
              ? 'You are offline and no data is cached yet.\n\nPlease connect to your server at least once.'
              : message,
          style: TextStyle(color: TC.subText(context)),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        child: const Text('Retry'),
      ),
    ],
  ));
}

class _EmptyClassroomsBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.school_outlined, color: TC.subText(context), size: 64),
      const SizedBox(height: 16),
      Text('No classrooms yet.',
          style: TextStyle(color: TC.subText(context), fontSize: 16)),
      const SizedBox(height: 8),
      Text('Tap + to join a class',
          style: TextStyle(color: TC.subText(context), fontSize: 13)),
    ],
  ));
}

// ── Classroom card ────────────────────────────────────────────────────────────

class _ClassroomCard extends StatelessWidget {
  final ClassroomModel classroom;
  final VoidCallback   onTap;
  const _ClassroomCard({required this.classroom, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 140,
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(
              alpha: TC.isDark(context) ? 0.15 : 0.08),
          blurRadius: 8, offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(classroom.name,
                  style: const TextStyle(color: AppColors.primary,
                      fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              _MetaRow(Icons.tag, 'Code: ${classroom.code}'),
              const SizedBox(height: 4),
              _MetaRow(Icons.person_outline,
                  'Teacher: ${classroom.teacherName ?? ""}',
                  color: AppColors.primary),
            ],
          ),
        )),
        ClipRRect(
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
          child: SizedBox(
            width: 160, height: 140,
            child: classroom.hasBanner && ApiService.token != null
                ? Image.network(
              ApiService.getBannerUrlSync(classroom.id),
              width: 160, height: 140, fit: BoxFit.cover,
              headers: {'Authorization': 'Bearer ${ApiService.token}'},
              errorBuilder: (_, __, ___) => _GradientBox(),
              loadingBuilder: (_, child, progress) =>
              progress == null ? child : _GradientBox(),
            )
                : _GradientBox(),
          ),
        ),
      ]),
    ),
  );
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color?   color;
  const _MetaRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: color ?? TC.subText(context)),
    const SizedBox(width: 4),
    Flexible(child: Text(text,
        style: TextStyle(
          color: color ?? TC.subText(context), fontSize: 13,
          fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis)),
  ]);
}

class _GradientBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 160, height: 140,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.darkCard],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.school, color: Colors.white54, size: 50),
  );
}