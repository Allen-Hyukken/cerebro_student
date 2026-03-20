import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/login_screen.dart';

class ConnectionCheckScreen extends StatefulWidget {
  const ConnectionCheckScreen({super.key});

  @override
  State<ConnectionCheckScreen> createState() => _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends State<ConnectionCheckScreen> {
  _Status _serverStatus = _Status.idle;
  _Status _dbStatus     = _Status.idle;
  String  _serverMsg    = '';
  String  _dbMsg        = '';
  String  _currentUrl   = '';
  bool    _autoProceeded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUrl = await ApiService.baseUrl;
    setState(() {});
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() {
      _serverStatus  = _Status.checking;
      _dbStatus      = _Status.idle;
      _serverMsg     = '';
      _dbMsg         = '';
      _autoProceeded = false;
    });

    try {
      final result = await ApiService.ping();

      setState(() {
        _serverStatus = _Status.ok;
        _serverMsg    = _currentUrl;
      });

      final db = result['db'] as String? ?? 'unknown';
      if (db == 'ok') {
        setState(() {
          _dbStatus = _Status.ok;
          _dbMsg    = 'MySQL connected';
        });
        // Auto-proceed after short pause
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted || _autoProceeded) return;
        _autoProceeded = true;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
        setState(() {
          _dbStatus = _Status.error;
          _dbMsg    = db;
        });
      }
    } catch (e) {
      setState(() {
        _serverStatus = _Status.error;
        _serverMsg    = e.toString().replaceAll('Exception: ', '');
        _dbStatus     = _Status.idle;
        _dbMsg        = '';
      });
    }
  }

  void _showEditUrlDialog() async {
    final currentUrl = await ApiService.baseUrl;
    final controller = TextEditingController(text: currentUrl);

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Server URL', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Enter your PC\'s local IP.\n\n'
                'Windows: open Command Prompt → ipconfig\n'
                'Look for "IPv4 Address" under Wi-Fi.\n\n'
                'Format:  http://192.168.x.x:5000/api',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.5:5000/api',
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Save & Retry'),
          ),
        ],
      ),
    );

    if (saved != null && saved.isNotEmpty) {
      await ApiService.setBaseUrl(saved);
      setState(() => _currentUrl = saved);
      _runCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _serverStatus == _Status.error || _dbStatus == _Status.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  color: AppColors.white,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 16)],
                ),
                child: ClipOval(child: Image.asset(
                  'assets/icons/logo.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 52, color: AppColors.primary),
                )),
              ),
              const SizedBox(height: 28),

              const Text('Cerebro Metron',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('Connecting to server...',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),

              // ── Server URL chip (tap to edit) ────────────────────────────
              GestureDetector(
                onTap: _showEditUrlDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.dns_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _currentUrl.isEmpty ? 'Loading...' : _currentUrl,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // ── Status rows ───────────────────────────────────────────────
              _CheckRow(label: 'Flask server', status: _serverStatus, message: _serverMsg),
              const SizedBox(height: 12),
              _CheckRow(label: 'MySQL database', status: _dbStatus, message: _dbMsg),

              // ── Error help ────────────────────────────────────────────────
              if (hasError) ...[
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.wrong.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.wrong.withValues(alpha: 0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('How to fix this',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.wrong, fontSize: 13)),
                    const SizedBox(height: 10),
                    if (_serverStatus == _Status.error) ...[
                      _tip('1. On your PC, run:  python app.py'),
                      _tip('2. Open Command Prompt → ipconfig'),
                      _tip('   Copy the "IPv4 Address" (e.g. 192.168.1.8)'),
                      _tip('3. Tap the URL bar above and enter:'),
                      _tip('   http://192.168.1.8:5000/api'),
                      _tip('4. Phone & PC must be on the same Wi-Fi'),
                      _tip('5. Windows: allow port 5000 in Firewall'),
                    ] else if (_dbStatus == _Status.error) ...[
                      _tip('Flask is reachable but MySQL is down.'),
                      _tip('1. Start MySQL service on your PC'),
                      _tip('   Windows: net start mysql'),
                      _tip('2. Check password in config.py → _DB_PASS'),
                      _tip('3. Make sure quizdatabase exists'),
                      _tip('   Run: python diagnose.py'),
                    ],
                  ]),
                ),
              ],

              const SizedBox(height: 28),

              // ── Buttons ───────────────────────────────────────────────────
              if (_serverStatus != _Status.checking) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _runCheck,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showEditUrlDialog,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change Server URL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Skip (continue anyway)',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: AppColors.wrong, fontSize: 13)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.wrong, height: 1.4))),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

enum _Status { idle, checking, ok, error }

class _CheckRow extends StatelessWidget {
  final String  label;
  final _Status status;
  final String  message;
  const _CheckRow({required this.label, required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    Widget leading;
    Color  color;

    switch (status) {
      case _Status.checking:
        leading = const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary));
        color = AppColors.primary;
        break;
      case _Status.ok:
        leading = const Icon(Icons.check_circle_rounded, color: AppColors.correct, size: 24);
        color   = AppColors.correct;
        break;
      case _Status.error:
        leading = const Icon(Icons.error_rounded, color: AppColors.wrong, size: 24);
        color   = AppColors.wrong;
        break;
      case _Status.idle:
        leading = Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 24);
        color   = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        leading,
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(message,
                style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace', height: 1.3),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
        ])),
      ]),
    );
  }
}