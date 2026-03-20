import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/course_detail_screen.dart';
import 'package:quiz_app/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<ClassroomModel> _allClassrooms = [];
  List<ClassroomModel> _filtered      = [];
  bool _isLoading  = true;
  bool _drawerOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getMyClassrooms();
      final classrooms = data.map((j) => ClassroomModel.fromJson(j)).toList();
      setState(() { _allClassrooms = classrooms; _filtered = classrooms; });
    } catch (e) {
      setState(() => _error = 'Failed to load classrooms.');
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

  void _logout() {
    ApiService.logout();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _showJoinClassDialog() {
    final codeController = TextEditingController();
    bool joining = false;
    bool success = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: success
                ? Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 70, height: 70,
                  decoration: BoxDecoration(color: AppColors.correct.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.correct, size: 44)),
              const SizedBox(height: 20),
              const Text("You've joined the class!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('The class has been added to your list.', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
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
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 24)),
                const SizedBox(width: 14),
                const Expanded(child: Text('Join a Class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
              const SizedBox(height: 6),
              const Text('Enter the class code from your teacher.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 7,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primary),
                onChanged: (_) { if (errorMsg != null) setDialogState(() => errorMsg = null); },
                decoration: InputDecoration(
                  counterText: '', hintText: 'ABC123',
                  hintStyle: TextStyle(color: Colors.grey.shade300, fontFamily: 'monospace', fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                  filled: true, fillColor: AppColors.background,
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
                  Text(errorMsg!, style: const TextStyle(color: AppColors.wrong, fontSize: 12)),
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
                    if (code.length < 4) { setDialogState(() => errorMsg = 'Enter a valid class code.'); return; }
                    setDialogState(() { joining = true; errorMsg = null; });
                    try {
                      await ApiService.joinClassroom(code);
                      setDialogState(() { joining = false; success = true; });
                    } catch (e) {
                      setDialogState(() { joining = false; errorMsg = e.toString().replaceAll('Exception: ', ''); });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 14), disabledBackgroundColor: AppColors.primary.withOpacity(0.6)),
                  child: joining
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Join Class', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _drawerOpen = true),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.menu, color: AppColors.primary, size: 22),
                  ),
                ),
                const Spacer(),
                Text('My Classes', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const Spacer(),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2), color: AppColors.white),
                  child: ClipOval(child: Image.asset('assets/icons/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 20, color: AppColors.primary))),
                ),
              ]),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search classes...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true, fillColor: AppColors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Classroom list
            Expanded(child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadClassrooms, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Retry')),
            ]))
                : _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.school_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text('No classes yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Tap + to join a class', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]))
                : RefreshIndicator(
              onRefresh: _loadClassrooms,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  return _ClassroomCard(
                    classroom: c,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(classroom: c))),
                  );
                },
              ),
            ),
            ),
          ]),

          // Settings drawer
          if (_drawerOpen)
            GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(
                color: Colors.black45,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: double.infinity,
                      decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24))),
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
                            const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 32)),
                            const SizedBox(width: 14),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(ApiService.name ?? 'Student', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(ApiService.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ]),
                        ),
                        const Divider(color: Colors.white24, thickness: 1, indent: 20, endIndent: 20),
                        _drawerItem(Icons.home_outlined, 'Home', () => setState(() => _drawerOpen = false)),
                        _drawerItem(Icons.book_outlined, 'My Classrooms', () => setState(() => _drawerOpen = false)),
                        _drawerItem(Icons.quiz_outlined, 'My Quizzes', () => setState(() => _drawerOpen = false)),
                        _drawerItem(Icons.person_outline, 'Profile', () => setState(() => _drawerOpen = false)),
                        _drawerItem(Icons.notifications_outlined, 'Notifications', () => setState(() => _drawerOpen = false)),
                        const Divider(color: Colors.white24, thickness: 1, indent: 20, endIndent: 20),
                        _drawerItem(Icons.help_outline, 'Help & Support', () => setState(() => _drawerOpen = false)),
                        _drawerItem(Icons.info_outline, 'About', () => setState(() => _drawerOpen = false)),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: GestureDetector(
                            onTap: _logout,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                              child: Row(children: const [
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

          // FAB — join class
          Positioned(
            bottom: 24, right: 24,
            child: FloatingActionButton(
              onPressed: _showJoinClassDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
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

class _ClassroomCard extends StatelessWidget {
  final ClassroomModel classroom;
  final VoidCallback onTap;
  const _ClassroomCard({required this.classroom, required this.onTap});

  // FIX: Build the right-side banner widget.
  //      If the classroom has a banner, load it from the API using the JWT
  //      auth header so the protected endpoint accepts the request.
  //      Otherwise fall back to the gradient placeholder.
  Widget _bannerWidget(double width, double height) {
    if (classroom.hasBanner) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: Image.network(
          ApiService.getBannerUrl(classroom.id),
          width: width,
          height: height,
          fit: BoxFit.cover,
          headers: {
            if (ApiService.token != null)
              'Authorization': 'Bearer ${ApiService.token}',
          },
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _placeholder(width, height);
          },
          errorBuilder: (_, __, ___) => _placeholder(width, height),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: _placeholder(width, height),
    );
  }

  Widget _placeholder(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary.withOpacity(0.7), AppColors.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.school, color: Colors.white54, size: 50),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          return Row(children: [
            SizedBox(
              width: half,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(classroom.name, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.tag, size: 13, color: Colors.grey), const SizedBox(width: 4), Text('Code: ${classroom.code}', style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 13, color: AppColors.primary), const SizedBox(width: 4),
                    Flexible(child: Text('Teacher: ${classroom.teacherName ?? ''}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ]),
                ]),
              ),
            ),
            _bannerWidget(half, 140),
          ]);
        }),
      ),
    );
  }
}