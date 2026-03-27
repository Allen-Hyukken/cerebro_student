// Models matching quizdatabase schema
// Works with both API (JSON) and SQLite (local cache) responses

class UserModel {
  final int    id;
  final String name;
  final String email;
  final String role;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:    _parseInt(j['id']),
    name:  j['name']  ?? '',
    email: j['email'] ?? '',
    role:  j['role']  ?? 'STUDENT',
  );
}

class ClassroomModel {
  final int     id;
  final String  name;
  final String  code;
  final String? teacherName;
  final int     quizCount;
  final int     studentCount;
  final bool    hasBanner;

  const ClassroomModel({
    required this.id,
    required this.name,
    required this.code,
    this.teacherName,
    this.quizCount    = 0,
    this.studentCount = 0,
    this.hasBanner    = false,
  });

  factory ClassroomModel.fromJson(Map<String, dynamic> j) => ClassroomModel(
    id:           _parseInt(j['id']),
    name:         j['name']         ?? '',
    code:         j['code']         ?? '',
    teacherName:  j['teacherName'],
    quizCount:    _parseInt(j['quizCount']),
    studentCount: _parseInt(j['studentCount']),
    hasBanner:    j['hasBanner'] == true || j['hasBanner'] == 1,
  );
}

class QuizModel {
  final int     id;
  final String  title;
  final String? description;
  final int     classRoomId;
  final String? classRoomName;
  final String? teacherName;
  final int     questionCount;
  final double  totalPoints;
  final String? createdAt;

  /// Minutes the student has after opening the quiz. null = no limit.
  final int? timeLimitMinutes;

  /// ISO-8601 deadline string from the server (assumed UTC if no tz offset).
  final String? deadline;

  /// When true, the student can see the correct/wrong breakdown after submitting.
  final bool showAnswers;

  const QuizModel({
    required this.id,
    required this.title,
    this.description,
    required this.classRoomId,
    this.classRoomName,
    this.teacherName,
    this.questionCount    = 0,
    this.totalPoints      = 0,
    this.createdAt,
    this.timeLimitMinutes,
    this.deadline,
    this.showAnswers      = false,
  });

  /// Parses [deadline] as UTC when no timezone info is present,
  /// then converts to the device's local timezone.
  DateTime? get deadlineDateTime {
    if (deadline == null) return null;
    try {
      final s = deadline!.trim();
      // If the string already carries timezone info (Z, +, or a negative
      // offset after the date part), parse as-is; otherwise append 'Z'
      // so the server's naive UTC timestamps are treated correctly.
      final hasOffset = s.endsWith('Z') ||
          s.contains('+') ||
          (s.length > 10 && RegExp(r'T\d{2}:\d{2}.*-\d{2}').hasMatch(s));
      return DateTime.parse(hasOffset ? s : '${s}Z').toLocal();
    } catch (_) {
      return null;
    }
  }

  /// True when the quiz deadline has already passed (compared in local time).
  bool get isDeadlinePassed {
    final dt = deadlineDateTime;
    return dt != null && DateTime.now().isAfter(dt);
  }

  factory QuizModel.fromJson(Map<String, dynamic> j) => QuizModel(
    id:               _parseInt(j['id']),
    title:            j['title']       ?? '',
    description:      j['description'],
    classRoomId:      _parseInt(j['classRoomId']),
    classRoomName:    j['classRoomName'],
    teacherName:      j['teacherName'],
    questionCount:    _parseInt(j['questionCount']),
    totalPoints:      _parseDouble(j['totalPoints']),
    createdAt:        j['createdAt'],
    timeLimitMinutes: j['timeLimitMinutes'] != null
        ? _parseInt(j['timeLimitMinutes']) : null,
    deadline:         j['deadline'] as String?,
    showAnswers:      j['showAnswers'] == true || j['showAnswers'] == 1,
  );
}

class QuestionModel {
  final int            id;
  final int            qIndex;
  final String         type; // MCQ | TF | IDENT | ESSAY | CODING
  final String         text;
  final double         points;
  final List<ChoiceModel> choices;

  const QuestionModel({
    required this.id,
    required this.qIndex,
    required this.type,
    required this.text,
    this.points  = 1.0,
    this.choices = const [],
  });

  factory QuestionModel.fromJson(Map<String, dynamic> j) => QuestionModel(
    id:      _parseInt(j['id']),
    qIndex:  _parseInt(j['qIndex']),
    type:    j['type']  ?? 'ESSAY',
    text:    j['text']  ?? '',
    points:  _parseDouble(j['points']),
    choices: (j['choices'] as List? ?? [])
        .map((c) => ChoiceModel.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class ChoiceModel {
  final int    id;
  final String text;

  const ChoiceModel({required this.id, required this.text});

  factory ChoiceModel.fromJson(Map<String, dynamic> j) => ChoiceModel(
    id:   _parseInt(j['id']),
    text: j['text'] ?? '',
  );
}

class AttemptModel {
  final int     id;
  final int     quizId;
  final String  quizTitle;
  final double  score;
  final double  totalPoints;
  final int     totalQuestions;
  final int     answeredCount;
  final int     skippedCount;
  final String? submittedAt;
  final bool    showAnswers;

  const AttemptModel({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.score,
    required this.totalPoints,
    required this.totalQuestions,
    required this.answeredCount,
    required this.skippedCount,
    this.submittedAt,
    this.showAnswers = false,
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
    showAnswers:    j['showAnswers'] == true || j['showAnswers'] == 1,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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