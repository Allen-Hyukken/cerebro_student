import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quiz_app/services/db_service.dart';
import 'package:quiz_app/services/xp_service.dart';

class ApiService {
  static const String _prefKey    = 'server_url';
  static const String _defaultUrl = 'http://192.168.1.5:5000/api';
  static String? _cachedBaseUrl;

  static Future<String> get baseUrl async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = prefs.getString(_prefKey) ?? _defaultUrl;
    return _cachedBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, clean);
    _cachedBaseUrl = clean;
  }

  static void clearCache() => _cachedBaseUrl = null;

  static const Duration _timeout       = Duration(seconds: 10);
  static const Duration _silentTimeout = Duration(seconds: 4);

  // ── Session state ─────────────────────────────────────────────────────────
  static String? _token;
  static int?    _userId;
  static String? _name;
  static String? _email;
  static String? _role;

  static String? get token      => _token;
  static int?    get userId     => _userId;
  static String? get name       => _name;
  static String? get email      => _email;
  static String? get role       => _role;
  static bool    get isTeacher  => _role == 'TEACHER';
  static bool    get isStudent  => _role == 'STUDENT';
  static bool    get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Session restore ───────────────────────────────────────────────────────
  static Future<bool> restoreSession() async {
    final session = await DbService.getSession();
    if (session == null) return false;

    // Load session into memory first
    _token  = session['token'];
    _userId = session['userId'] as int?;
    _name   = session['name'];
    _email  = session['email'];
    _role   = session['role'];

    // Verify token + check user still exists in MySQL
    try {
      final url = '${await baseUrl}/auth/me';
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 401 || res.statusCode == 403) {
        // Account deleted or token invalid — force logout
        await logout();
        return false;
      }
    } catch (_) {
      // Offline — trust cached session
    }

    return true;
  }

  // ── Request helpers ───────────────────────────────────────────────────────
  static Future<http.Response> _get(String path) async {
    final url = '${await baseUrl}$path';
    try {
      return await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    } on SocketException catch (e) {
      throw Exception('Cannot reach server.\n$e\n\nGo to ⚙ Settings → Server URL and enter your PC\'s IP.');
    } on TimeoutException {
      throw Exception('Request timed out (${_timeout.inSeconds}s).\nServer may be off or unreachable.');
    }
  }

  static Future<http.Response> _post(String path, {Object? body}) async {
    final url = '${await baseUrl}$path';
    try {
      return await http.post(Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw Exception('Cannot reach server.\n$e\n\nGo to ⚙ Settings → Server URL and enter your PC\'s IP.');
    } on TimeoutException {
      throw Exception('Request timed out (${_timeout.inSeconds}s).\nServer may be off or unreachable.');
    }
  }

  static Future<http.Response?> _getSilent(String path) async {
    final url = '${await baseUrl}$path';
    try {
      return await http.get(Uri.parse(url), headers: _headers).timeout(_silentTimeout);
    } catch (_) { return null; }
  }

  static Future<http.Response?> _postSilent(String path, {Object? body}) async {
    final url = '${await baseUrl}$path';
    try {
      return await http.post(Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null)
          .timeout(_silentTimeout);
    } catch (_) { return null; }
  }

  // ── Ping ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> ping() async {
    final res = await _get('/ping');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Banner URL ────────────────────────────────────────────────────────────
  static Future<String> getBannerUrl(int classroomId) async =>
      '${await baseUrl}/classrooms/$classroomId/banner';

  static String getBannerUrlSync(int classroomId) =>
      '${_cachedBaseUrl ?? _defaultUrl}/classrooms/$classroomId/banner';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String name, String email, String password,
      {String role = 'STUDENT'}) async {
    final res = await _post('/auth/register',
        body: {'name': name, 'email': email, 'password': password, 'role': role});
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      _storeSession(data);
      await DbService.saveSession(data);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _post('/auth/login',
        body: {'email': email, 'password': password});
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      _storeSession(data);
      await DbService.saveSession(data);
      // Pre-cache all data after login while online
      await _preCacheAll();
    }
    return data;
  }

  static Future<void> logout() async {
    _token = null; _userId = null;
    _name  = null; _email  = null; _role = null;
    await DbService.clearSession();
    // Do NOT clear submitted_quizzes — locks are per userId
    // so switching accounts still keeps each user's quiz locks intact
  }

  static void _storeSession(Map<String, dynamic> data) {
    _token  = data['token'];
    _userId = int.tryParse(data['id'].toString());
    _name   = data['name'];
    _email  = data['email'];
    _role   = data['role'];
  }

  // ── Pre-cache everything while online ─────────────────────────────────────
  // Called after login and on every sync — saves classrooms + all quizzes
  // + all quiz details to SQLite so everything works offline
  static Future<void> _preCacheAll() async {
    try {
      // 1. Cache classrooms
      final classroomsRes = await _getSilent('/classrooms');
      if (classroomsRes == null || classroomsRes.statusCode != 200) return;
      final classrooms = jsonDecode(classroomsRes.body) as List<dynamic>;
      await DbService.saveClassrooms(classrooms);

      // 2. For each classroom, cache quizzes + quiz details
      for (final classroom in classrooms) {
        final classroomId = classroom['id'] as int;
        final quizzesRes = await _getSilent('/quizzes?classroomId=$classroomId');
        if (quizzesRes == null || quizzesRes.statusCode != 200) continue;
        final quizzes = jsonDecode(quizzesRes.body) as List<dynamic>;
        await DbService.saveQuizzes(classroomId, quizzes);

        // 3. For each quiz, cache full detail including questions + choices
        for (final quiz in quizzes) {
          final quizId = quiz['id'] as int;
          final detailRes = await _getSilent('/quizzes/$quizId?teacher=false');
          if (detailRes == null || detailRes.statusCode != 200) continue;
          final detail = jsonDecode(detailRes.body) as Map<String, dynamic>;
          await DbService.saveQuizDetail(detail);
        }
      }
    } catch (_) {
      // Silent fail — don't crash if pre-cache fails
    }
  }

  // ── Classrooms ────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getMyClassrooms() async {
    final res = await _getSilent('/classrooms');
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      await DbService.saveClassrooms(data);
      // Also pre-cache quizzes in background
      _preCacheAll();
      return data;
    }
    // Offline fallback
    final cached = await DbService.getClassrooms();
    if (cached.isNotEmpty) return cached;
    throw Exception('No cached classrooms. Please connect to the server at least once.');
  }

  static Future<Map<String, dynamic>> getClassroomDetail(int id) async {
    final res = await _get('/classrooms/$id');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Classroom not found');
  }

  static Future<List<dynamic>> getQuizLeaderboard(int quizId) async {
    final res = await _getSilent('/quizzes/$quizId/leaderboard');
    if (res != null && res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load leaderboard');
  }

  static Future<void> joinClassroom(String code) async {
    final res = await _post('/classrooms/join?code=$code');
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Failed to join classroom');
    }
    // Re-cache after joining new classroom
    _preCacheAll();
  }

  // ── Quizzes ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getClassroomQuizzes(int classroomId) async {
    final res = await _getSilent('/quizzes?classroomId=$classroomId');
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      await DbService.saveQuizzes(classroomId, data);
      return data;
    }
    // Offline fallback
    final cached = await DbService.getQuizzes(classroomId);
    if (cached.isNotEmpty) return cached;
    throw Exception('No cached quizzes. Please connect to the server at least once.');
  }

  static Future<Map<String, dynamic>> getQuizDetail(int quizId,
      {bool teacher = false}) async {
    final res = await _getSilent('/quizzes/$quizId?teacher=$teacher');
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await DbService.saveQuizDetail(data);
      return data;
    }
    // Offline fallback
    final cached = await DbService.getQuizDetail(quizId);
    if (cached != null) return cached;
    throw Exception('No cached quiz. Please connect to the server at least once.');
  }

  // ── Attempts ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitAttempt(
      int quizId, Map<String, String> answers) async {
    final res = await _postSilent('/attempts',
        body: {'quizId': quizId, 'answers': answers});
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await DbService.saveAttempt(data);
      if (_userId != null) await DbService.markQuizSubmitted(quizId, _userId!);
      // Award XP based on score
      if (_userId != null) {
        final xp = XpService().calculateQuizXp(
            (data['score'] ?? 0).toDouble(),
            (data['totalPoints'] ?? 0).toDouble());
        await XpService().addXp(_userId!, xp);
      }
      return data;
    }
    // Offline → save pending + lock quiz (one-time only)
    await DbService.savePendingAttempt(quizId, answers);
    if (_userId != null) await DbService.markQuizSubmitted(quizId, _userId!);
    // Award participation XP offline
    if (_userId != null) await XpService().addXp(_userId!, 10);
    return {
      'attemptId': -1,
      'quizId': quizId,
      'quizTitle': 'Quiz',
      'score': 0.0,
      'totalPoints': 0.0,
      'totalQuestions': answers.length,
      'answeredCount': answers.length,
      'skippedCount': 0,
      'submittedAt': DateTime.now().toIso8601String(),
      'offline': true,
    };
  }

  /// Manually mark quiz as submitted in SQLite (for cross-device sync)
  static Future<void> markSubmittedLocally(int quizId, int userId) async {
    await DbService.markQuizSubmitted(quizId, userId);
  }

  /// Check if THIS user already submitted this quiz
  /// Checks both SQLite (offline lock) and server (online history)
  static Future<bool> hasSubmittedQuiz(int quizId) async {
    if (_userId == null) return false;

    // 1. Check SQLite first (fast, works offline)
    final localLock = await DbService.isQuizSubmitted(quizId, _userId!);
    if (localLock) return true;

    // 2. Check server attempts (catches cross-device submissions)
    try {
      final res = await _getSilent('/attempts/me');
      if (res != null && res.statusCode == 200) {
        final attempts = jsonDecode(res.body) as List<dynamic>;
        final alreadySubmitted = attempts.any((a) =>
        (a['quizId'] ?? a['quiz_id']) == quizId);
        if (alreadySubmitted) {
          // Cache it locally so we don't need to check server next time
          await DbService.markQuizSubmitted(quizId, _userId!);
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  static Future<void> syncPendingAttempts() async {
    final pending = await DbService.getPendingAttempts();
    for (final attempt in pending) {
      try {
        final answers = (jsonDecode(attempt['answers'] as String) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
        final res = await _postSilent('/attempts',
            body: {'quizId': attempt['quizId'], 'answers': answers});
        if (res != null && res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          await DbService.saveAttempt(data);
          await DbService.deletePendingAttempt(attempt['id'] as int);
        }
      } catch (_) {}
    }
    // Also refresh cache after sync
    await _preCacheAll();
  }

  static Future<List<dynamic>> getMyAttempts() async {
    final res = await _getSilent('/attempts/me');
    if (res != null && res.statusCode == 200) return jsonDecode(res.body);
    return await DbService.getAttempts();
  }

  static Future<Map<String, dynamic>> getAttempt(int attemptId) async {
    final res = await _get('/attempts/$attemptId');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Attempt not found');
  }
}