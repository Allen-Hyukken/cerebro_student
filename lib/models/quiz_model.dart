// Models matching quizdatabase schema
// Works with both API (JSON) and SQLite (local cache) responses

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;

  UserModel({required this.id, required this.name, required this.email, required this.role});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:    _parseInt(j['id']),
    name:  j['name']  ?? '',
    email: j['email'] ?? '',
    role:  j['role']  ?? 'STUDENT',
  );
}

class ClassroomModel {
  final int id;
  final String name;
  final String code;
  final String? teacherName;
  final int quizCount;
  final int studentCount;
  final bool hasBanner;

  ClassroomModel({
    required this.id,
    required this.name,
    required this.code,
    this.teacherName,
    this.quizCount = 0,
    this.studentCount = 0,
    this.hasBanner = false,
  });

  factory ClassroomModel.fromJson(Map<String, dynamic> j) => ClassroomModel(
    id:           _parseInt(j['id']),
    name:         j['name']         ?? '',
    code:         j['code']         ?? '',
    teacherName:  j['teacherName'],
    quizCount:    _parseInt(j['quizCount']),
    studentCount: _parseInt(j['studentCount']),
    // handles bool (from API) or int 0/1 (from SQLite)
    hasBanner:    j['hasBanner'] == true || j['hasBanner'] == 1,
  );
}

class QuizModel {
  final int id;
  final String title;
  final String? description;
  final int classRoomId;
  final String? classRoomName;
  final String? teacherName;
  final int questionCount;
  final double totalPoints;
  final String? createdAt;

  QuizModel({
    required this.id,
    required this.title,
    this.description,
    required this.classRoomId,
    this.classRoomName,
    this.teacherName,
    this.questionCount = 0,
    this.totalPoints = 0,
    this.createdAt,
  });

  factory QuizModel.fromJson(Map<String, dynamic> j) => QuizModel(
    id:            _parseInt(j['id']),
    title:         j['title']         ?? '',
    description:   j['description'],
    classRoomId:   _parseInt(j['classRoomId']),
    classRoomName: j['classRoomName'],
    teacherName:   j['teacherName'],
    questionCount: _parseInt(j['questionCount']),
    totalPoints:   _parseDouble(j['totalPoints']),
    createdAt:     j['createdAt'],
  );
}

class QuestionModel {
  final int id;
  final int qIndex;
  final String type; // MCQ, TF, IDENT, ESSAY, CODING
  final String text;
  final double points;
  final List<ChoiceModel> choices;

  QuestionModel({
    required this.id,
    required this.qIndex,
    required this.type,
    required this.text,
    this.points = 1.0,
    this.choices = const [],
  });

  factory QuestionModel.fromJson(Map<String, dynamic> j) => QuestionModel(
    id:      _parseInt(j['id']),
    qIndex:  _parseInt(j['qIndex']),
    type:    j['type']   ?? 'ESSAY',
    text:    j['text']   ?? '',
    points:  _parseDouble(j['points']),
    choices: j['choices'] != null
        ? (j['choices'] as List).map((c) => ChoiceModel.fromJson(c)).toList()
        : [],
  );
}

class ChoiceModel {
  final int id;
  final String text;

  ChoiceModel({required this.id, required this.text});

  factory ChoiceModel.fromJson(Map<String, dynamic> j) => ChoiceModel(
    id:   _parseInt(j['id']),
    text: j['text'] ?? '',
  );
}

class AttemptModel {
  final int id;
  final int quizId;
  final String quizTitle;
  final double score;
  final double totalPoints;
  final int totalQuestions;
  final int answeredCount;
  final int skippedCount;
  final String? submittedAt;

  AttemptModel({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.score,
    required this.totalPoints,
    required this.totalQuestions,
    required this.answeredCount,
    required this.skippedCount,
    this.submittedAt,
  });

  double get completionPercent =>
      totalQuestions > 0 ? answeredCount / totalQuestions * 100 : 0;

  factory AttemptModel.fromJson(Map<String, dynamic> j) => AttemptModel(
    id:             _parseInt(j['id'] ?? j['attemptId']),
    quizId:         _parseInt(j['quizId']),
    quizTitle:      j['quizTitle']      ?? '',
    score:          _parseDouble(j['score']),
    totalPoints:    _parseDouble(j['totalPoints']),
    totalQuestions: _parseInt(j['totalQuestions']),
    answeredCount:  _parseInt(j['answeredCount']),
    skippedCount:   _parseInt(j['skippedCount']),
    submittedAt:    j['submittedAt'],
  );
}

// ── Type-safe helpers (handle int/double from both SQLite and JSON) ────────────
int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}