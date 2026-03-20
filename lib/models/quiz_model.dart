// Models matching quizdatabase schema
// These are used locally; real data comes from ApiService

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;

  UserModel({required this.id, required this.name, required this.email, required this.role});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'],
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'STUDENT',
  );
}

class ClassroomModel {
  final int id;
  final String name;
  final String code;
  final String? teacherName;
  final int quizCount;
  final int studentCount;
  // FIX: parse hasBanner from API response so we know whether to load
  //      the network banner image or fall back to the gradient placeholder.
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
    id: j['id'],
    name: j['name'] ?? '',
    code: j['code'] ?? '',
    teacherName: j['teacherName'],
    quizCount: j['quizCount'] ?? 0,
    studentCount: j['studentCount'] ?? 0,
    hasBanner: j['hasBanner'] ?? false,
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
    id: j['id'],
    title: j['title'] ?? '',
    description: j['description'],
    classRoomId: j['classRoomId'] ?? 0,
    classRoomName: j['classRoomName'],
    teacherName: j['teacherName'],
    questionCount: j['questionCount'] ?? 0,
    totalPoints: (j['totalPoints'] ?? 0).toDouble(),
    createdAt: j['createdAt'],
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
    id: j['id'],
    qIndex: j['qIndex'] ?? 0,
    type: j['type'] ?? 'ESSAY',
    text: j['text'] ?? '',
    points: (j['points'] ?? 1.0).toDouble(),
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
    id: j['id'],
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
    id: j['id'],
    quizId: j['quizId'],
    quizTitle: j['quizTitle'] ?? '',
    score: (j['score'] ?? 0).toDouble(),
    totalPoints: (j['totalPoints'] ?? 0).toDouble(),
    totalQuestions: j['totalQuestions'] ?? 0,
    answeredCount: j['answeredCount'] ?? 0,
    skippedCount: j['skippedCount'] ?? 0,
    submittedAt: j['submittedAt'],
  );
}