import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/theme_service.dart';
import 'package:quiz_app/services/sound_service.dart';
import 'package:quiz_app/screens/course_detail_screen.dart';
import 'package:quiz_app/screens/login_screen.dart';
import 'package:quiz_app/screens/history_screen.dart';
import 'package:quiz_app/widgets/user_avatar.dart';
import 'package:quiz_app/screens/memory_game_screen.dart';
import 'package:quiz_app/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  List<ClassroomModel> _allClassrooms = [];
  List<ClassroomModel> _filtered      = [];
  bool _isLoading  = true;
  bool _drawerOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadClassrooms();
    ThemeService().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeService().removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncAndRefresh();
  }

  Future<void> _syncAndRefresh() async {
    try { await ApiService.syncPendingAttempts(); } catch (_) {}
    await _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getMyClassrooms();
      final classrooms = data.map((j) => ClassroomModel.fromJson(j)).toList();
      setState(() { _allClassrooms = classrooms; _filtered = classrooms; });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = _allClassrooms.where((c) =>
      c.name.toLowerCase().contains(query.toLowerCase()) ||
          c.code.toLowerCase().contains(query.toLowerCase()) ||
          (c.teacherName?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();
    });
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _showJoinClassDialog() {
    final codeController = TextEditingController();
    bool joining = false;
    bool success = false;
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
                ? Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 70, height: 70,
                  decoration: BoxDecoration(color: AppColors.correct.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.correct, size: 44)),
              const SizedBox(height: 20),
              Text("You've joined the class!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TC.text(context)), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('The class has been added to your list.', style: TextStyle(fontSize: 13, color: TC.subText(context)), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); _loadClassrooms(); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ])
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 24)),
                const SizedBox(width: 14),
                Expanded(child: Text('Join a Class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TC.text(context)))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: TC.subText(context)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
              const SizedBox(height: 6),
              Text('Enter the class code from your teacher.', style: TextStyle(color: TC.subText(context), fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primary),
                onChanged: (_) { if (errorMsg != null) setS(() => errorMsg = null); },
                decoration: InputDecoration(
                  counterText: '', hintText: 'ABC123',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkSubText : Colors.grey.shade300, fontFamily: 'monospace', fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                  filled: true, fillColor: TC.bg(context),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.wrong, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(errorMsg!, style: const TextStyle(color: AppColors.wrong, fontSize: 12))),
                ]),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: joining ? null : () async {
                    final code = codeController.text.trim();
                    if (code.length < 4) { setS(() => errorMsg = 'Enter a valid class code.'); return; }
                    setS(() { joining = true; errorMsg = null; });
                    try {
                      await ApiService.joinClassroom(code);
                      setS(() { joining = false; success = true; });
                    } catch (e) {
                      setS(() { joining = false; errorMsg = e.toString().replaceAll('Exception: ', ''); });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 14), disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6)),
                  child: joining
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Join Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                )),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = TC.isDark(context);
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                IconButton(icon: Icon(Icons.menu, color: TC.text(context)), onPressed: () => setState(() => _drawerOpen = true)),
                IconButton(icon: Icon(Icons.add, color: TC.text(context)), onPressed: _showJoinClassDialog),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                        color: TC.surface(context),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6, offset: const Offset(0, 2))]),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: TextStyle(color: TC.text(context)),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: TC.subText(context), fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: TC.subText(context), size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(icon: Icon(Icons.close, size: 18, color: TC.subText(context)), onPressed: () { _searchController.clear(); _onSearch(''); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2), color: TC.surface(context)),
                  child: ClipOval(child: Image.asset('assets/icons/logo.png', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 22, color: AppColors.primary))),
                ),
              ]),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Expanded(child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wifi_off, color: TC.subText(context), size: 48),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!.contains('cached')
                      ? 'You are offline and no data is cached yet.\n\nPlease connect to your server at least once.'
                      : _error!,
                  style: TextStyle(color: TC.subText(context)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _syncAndRefresh,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Retry')),
            ]))
                : _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.school_outlined, color: TC.subText(context), size: 64),
              const SizedBox(height: 16),
              Text('No classrooms yet.', style: TextStyle(color: TC.subText(context), fontSize: 16)),
              const SizedBox(height: 8),
              Text('Tap + to join a class', style: TextStyle(color: TC.subText(context), fontSize: 13)),
            ]))
                : RefreshIndicator(
              onRefresh: _syncAndRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  return _ClassroomCard(
                    classroom: c,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CourseDetailScreen(classroom: c))),
                  );
                },
              ),
            ),
            ),
          ]),

          // ── Drawer ─────────────────────────────────────────────────────
          if (_drawerOpen)
            GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
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
                          borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24))),
                      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(children: [
                            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _drawerOpen = false)),
                            const SizedBox(width: 8),
                            const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(children: [
                            const UserAvatar(size: 56, borderColor: Colors.white),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(ApiService.name ?? 'Student', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(ApiService.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ])),
                          ]),
                        ),
                        const Divider(color: Colors.white24, thickness: 1, indent: 20, endIndent: 20),
                        const SizedBox(height: 8),
                        Flexible(child: SingleChildScrollView(child: Column(children: [
                          _drawerItem(Icons.home_outlined, 'Home', () {
                            setState(() => _drawerOpen = false);
                            _loadClassrooms();
                          }),
                          _drawerItem(Icons.book_outlined, 'My Classrooms', () {
                            setState(() => _drawerOpen = false);
                            _loadClassrooms();
                          }),
                          _drawerItem(Icons.history_edu, 'Quiz History', () {
                            setState(() => _drawerOpen = false);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                          }),
                          _drawerItem(Icons.person_outline, 'Profile', () {
                            setState(() => _drawerOpen = false);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                          }),
                          _drawerItem(Icons.add_circle_outline, 'Join a Class', () {
                            setState(() => _drawerOpen = false);
                            _showJoinClassDialog();
                          }),
                          _drawerItem(Icons.games_outlined, 'Mini Games', () {
                            setState(() => _drawerOpen = false);
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const MemoryGameScreen()));
                          }),
                          _drawerItem(Icons.sync_outlined, 'Sync Now', () async {
                            setState(() => _drawerOpen = false);
                            await _syncAndRefresh();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Synced!'), backgroundColor: AppColors.correct, duration: Duration(seconds: 2)),
                              );
                            }
                          }),
                          const Divider(color: Colors.white24, thickness: 1, indent: 20, endIndent: 20),

                          // ── Dark mode toggle ────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(children: [
                              Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.white70, size: 22),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('Dark Mode', style: TextStyle(color: Colors.white, fontSize: 15))),
                              StatefulBuilder(builder: (ctx, setSw) => Switch(
                                value: ThemeService().isDark,
                                onChanged: (val) async {
                                  await ThemeService().setDark(val);
                                  setSw(() {});
                                },
                                activeColor: Colors.white,
                                activeTrackColor: AppColors.darkCard,
                                inactiveThumbColor: Colors.white70,
                                inactiveTrackColor: Colors.white24,
                              )),
                            ]),
                          ),

                          // ── Background music toggle ──────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(children: [
                              const Icon(Icons.music_note, color: Colors.white70, size: 22),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('Music', style: TextStyle(color: Colors.white, fontSize: 15))),
                              StatefulBuilder(builder: (ctx, setSw) => Switch(
                                value: SoundService().isBgEnabled,
                                onChanged: (val) async {
                                  await SoundService().toggleBackground();
                                  setSw(() {});
                                },
                                activeColor: Colors.white,
                                activeTrackColor: AppColors.darkCard,
                                inactiveThumbColor: Colors.white70,
                                inactiveTrackColor: Colors.white24,
                              )),
                            ]),
                          ),

                          _drawerItem(Icons.info_outline, 'About', () {
                            setState(() => _drawerOpen = false);
                            showDialog(context: context, builder: (ctx) => AlertDialog(
                              backgroundColor: TC.surface(context),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text('Cerebro Metron', style: TextStyle(fontWeight: FontWeight.bold, color: TC.text(context))),
                              content: Text('A quiz app for students.\nVersion 1.0.0', style: TextStyle(color: TC.subText(context))),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                            ));
                          }),
                        ]))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: GestureDetector(
                            onTap: _logout,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                              child: const Row(children: [
                                Icon(Icons.logout, color: Colors.white, size: 22),
                                SizedBox(width: 14),
                                Text('Log Out', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ])),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: Colors.white70, size: 22),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
    onTap: onTap,
    horizontalTitleGap: 8,
  );
}

// ── Classroom card ─────────────────────────────────────────────────────────────
class _ClassroomCard extends StatelessWidget {
  final ClassroomModel classroom;
  final VoidCallback onTap;
  const _ClassroomCard({required this.classroom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: TC.isDark(context) ? 0.15 : 0.08),
                blurRadius: 8, offset: const Offset(0, 4))]),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(classroom.name,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.tag, size: 13, color: TC.subText(context)),
                      const SizedBox(width: 4),
                      Text('Code: ${classroom.code}',
                          style: TextStyle(color: TC.subText(context), fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Teacher: ${classroom.teacherName ?? ""}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ]),
            ),
          ),
          // Banner
          ClipRRect(
            borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
            child: SizedBox(
              width: 160, height: 140,
              child: classroom.hasBanner && ApiService.token != null
                  ? Image.network(
                ApiService.getBannerUrlSync(classroom.id),
                width: 160, height: 140, fit: BoxFit.cover,
                headers: {'Authorization': 'Bearer ${ApiService.token}'},
                errorBuilder: (_, __, ___) => _buildGradient(),
                loadingBuilder: (_, child, progress) => progress == null ? child : _buildGradient(),
              )
                  : _buildGradient(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGradient() => Container(
    width: 160, height: 140,
    decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.darkCard],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: const Icon(Icons.school, color: Colors.white54, size: 50),
  );
}