import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _prefKey = 'server_url';

  // Default — user can change this inside the app on the Server Settings screen
  static const String _defaultUrl = 'http://192.168.1.8:5000/api';

  // In-memory cache so we don't hit SharedPreferences on every request
  static String? _cachedBaseUrl;

  static Future<String> get baseUrl async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = prefs.getString(_prefKey) ?? _defaultUrl;
    return _cachedBaseUrl!;
  }

  /// Called by ServerSettingsScreen when the user saves a new IP/URL.
  static Future<void> setBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/$'), ''); // strip trailing slash
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, clean);
    _cachedBaseUrl = clean; // update in-memory cache immediately
  }

  /// Clears cache — forces next call to re-read from SharedPreferences.
  static void clearCache() => _cachedBaseUrl = null;

  static const Duration _timeout = Duration(seconds: 10);

  // ── Session state ────────────────────────────────────────────────────────
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

  // ── Request helpers ──────────────────────────────────────────────────────

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
      return await http
          .post(Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw Exception('Cannot reach server.\n$e\n\nGo to ⚙ Settings → Server URL and enter your PC\'s IP.');
    } on TimeoutException {
      throw Exception('Request timed out (${_timeout.inSeconds}s).\nServer may be off or unreachable.');
    }
  }

  // ── Ping ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> ping() async {
    final res = await _get('/ping');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Banner URL (needs token in header — returned by Image.network caller) ─

  static Future<String> getBannerUrl(int classroomId) async =>
      '${await baseUrl}/classrooms/$classroomId/banner';

  // Sync version used by widgets that already know baseUrl
  static String getBannerUrlSync(int classroomId) =>
      '${_cachedBaseUrl ?? _defaultUrl}/classrooms/$classroomId/banner';

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String name, String email, String password,
      {String role = 'STUDENT'}) async {
    final res = await _post('/auth/register',
        body: {'name': name, 'email': email, 'password': password, 'role': role});
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) _storeSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _post('/auth/login',
        body: {'email': email, 'password': password});
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) _storeSession(data);
    return data;
  }

  static void logout() {
    _token = null; _userId = null;
    _name  = null; _email  = null; _role = null;
  }

  static void _storeSession(Map<String, dynamic> data) {
    _token  = data['token'];
    _userId = int.tryParse(data['id'].toString());
    _name   = data['name'];
    _email  = data['email'];
    _role   = data['role'];
  }

  // ── Classrooms ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getMyClassrooms() async {
    final res = await _get('/classrooms');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load classrooms');
  }

  static Future<Map<String, dynamic>> getClassroomDetail(int id) async {
    final res = await _get('/classrooms/$id');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Classroom not found');
  }

  static Future<void> joinClassroom(String code) async {
    final res = await _post('/classrooms/join?code=$code');
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Failed to join classroom');
    }
  }

  // ── Quizzes ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getClassroomQuizzes(int classroomId) async {
    final res = await _get('/quizzes?classroomId=$classroomId');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load quizzes');
  }

  static Future<Map<String, dynamic>> getQuizDetail(int quizId,
      {bool teacher = false}) async {
    final res = await _get('/quizzes/$quizId?teacher=$teacher');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load quiz');
  }

  // ── Attempts ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitAttempt(
      int quizId, Map<String, String> answers) async {
    final res = await _post('/attempts',
        body: {'quizId': quizId, 'answers': answers});
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed to submit');
  }

  static Future<List<dynamic>> getMyAttempts() async {
    final res = await _get('/attempts/me');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load attempts');
  }

  static Future<Map<String, dynamic>> getAttempt(int attemptId) async {
    final res = await _get('/attempts/$attemptId');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Attempt not found');
  }
}