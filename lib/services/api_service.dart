import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Emulator  → http://10.0.2.2:8080
  // Real device → http://YOUR_PC_IP:8080
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  static String? _token;
  static int?    _userId;
  static String? _name;
  static String? _email;
  static String? _role;

  static String? get token    => _token;
  static int?    get userId   => _userId;
  static String? get name     => _name;
  static String? get email    => _email;
  static String? get role     => _role;
  static bool    get isTeacher => _role == 'TEACHER';
  static bool    get isStudent => _role == 'STUDENT';
  static bool    get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// POST /api/auth/register
  /// Body: { "name": "...", "email": "...", "password": "...", "role": "STUDENT" }
  static Future<Map<String, dynamic>> register(
      String name, String email, String password, {String role = 'STUDENT'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) _storeSession(data);
    return data;
  }

  /// POST /api/auth/login
  /// Body: { "email": "...", "password": "..." }
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
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

  // ── Classrooms ────────────────────────────────────────────────────────────

  /// GET /api/classrooms
  /// Returns classrooms for logged-in user (teacher or student)
  /// Fields: id, name, code, teacherName, teacherId, studentCount, quizCount, hasBanner
  static Future<List<dynamic>> getMyClassrooms() async {
    final res = await http.get(Uri.parse('$baseUrl/classrooms'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load classrooms');
  }

  /// GET /api/classrooms/{id}
  /// Returns classroom detail + quizzes list
  static Future<Map<String, dynamic>> getClassroomDetail(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/classrooms/$id'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Classroom not found');
  }

  /// POST /api/classrooms/join?code=ABC123
  /// Student joins classroom by code — returns 200 OK with no body
  static Future<void> joinClassroom(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/classrooms/join?code=$code'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Failed to join classroom');
    }
  }

  /// Banner image URL — use with Image.network()
  static String getBannerUrl(int classroomId) =>
      '$baseUrl/classrooms/$classroomId/banner';

  // ── Quizzes ───────────────────────────────────────────────────────────────

  /// GET /api/quizzes?classroomId={id}
  /// Fields: id, title, description, published, questionCount, totalPoints, createdAt, teacherName
  static Future<List<dynamic>> getClassroomQuizzes(int classroomId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/quizzes?classroomId=$classroomId'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load quizzes');
  }

  /// GET /api/quizzes/{id}?teacher=false
  /// Returns quiz + questions + choices
  /// Question fields: id, text, type (MCQ/TF/IDENT/ESSAY/CODING), qIndex, points, choices
  /// Choice fields: id, text  (correct NOT sent to students)
  static Future<Map<String, dynamic>> getQuizDetail(int quizId, {bool teacher = false}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/quizzes/$quizId?teacher=$teacher'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load quiz');
  }

  // ── Attempts ──────────────────────────────────────────────────────────────

  /// POST /api/attempts
  /// Body: { "quizId": 1, "answers": { "questionId": "answerValue" } }
  ///
  /// Answer values:
  ///   MCQ   → choiceId as string e.g. "42"
  ///   TF    → "True" or "False"
  ///   IDENT/ESSAY/CODING → answer text
  ///
  /// Returns: { attemptId, quizId, quizTitle, score, totalPoints,
  ///            totalQuestions, answeredCount, skippedCount, submittedAt, answers }
  static Future<Map<String, dynamic>> submitAttempt(
      int quizId, Map<String, String> answers) async {
    final res = await http.post(
      Uri.parse('$baseUrl/attempts'),
      headers: _headers,
      body: jsonEncode({'quizId': quizId, 'answers': answers}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed to submit');
  }

  /// GET /api/attempts/me — student's attempt history
  static Future<List<dynamic>> getMyAttempts() async {
    final res = await http.get(Uri.parse('$baseUrl/attempts/me'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load attempts');
  }

  /// GET /api/attempts/{id}
  static Future<Map<String, dynamic>> getAttempt(int attemptId) async {
    final res = await http.get(Uri.parse('$baseUrl/attempts/$attemptId'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Attempt not found');
  }
}
