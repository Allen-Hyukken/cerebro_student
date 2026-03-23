import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'quizapp.db');
    return openDatabase(
      path,
      version: 4, // v4: adds timeLimitMinutes, deadline, showAnswers to quizzes
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS submitted_quizzes (
              quizId INTEGER,
              userId INTEGER,
              submittedAt TEXT,
              PRIMARY KEY (quizId, userId)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS submitted_quizzes');
          await db.execute('''
            CREATE TABLE submitted_quizzes (
              quizId INTEGER,
              userId INTEGER,
              submittedAt TEXT,
              PRIMARY KEY (quizId, userId)
            )
          ''');
        }
        if (oldVersion < 4) {
          // Add teacher-controlled quiz fields
          try { await db.execute('ALTER TABLE quizzes ADD COLUMN timeLimitMinutes INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE quizzes ADD COLUMN deadline TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE quizzes ADD COLUMN showAnswers INTEGER DEFAULT 0'); } catch (_) {}
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE session (
        id INTEGER PRIMARY KEY,
        token TEXT,
        userId INTEGER,
        name TEXT,
        email TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE classrooms (
        id INTEGER PRIMARY KEY,
        name TEXT,
        code TEXT,
        teacherName TEXT,
        teacherId INTEGER,
        studentCount INTEGER,
        quizCount INTEGER,
        hasBanner INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE quizzes (
        id INTEGER PRIMARY KEY,
        classroomId INTEGER,
        title TEXT,
        description TEXT,
        published INTEGER,
        questionCount INTEGER,
        totalPoints REAL,
        teacherName TEXT,
        createdAt TEXT,
        timeLimitMinutes INTEGER,
        deadline TEXT,
        showAnswers INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY,
        quizId INTEGER,
        text TEXT,
        type TEXT,
        qIndex INTEGER,
        points REAL,
        choices TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quizId INTEGER,
        answers TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attempts (
        id INTEGER PRIMARY KEY,
        quizId INTEGER,
        quizTitle TEXT,
        score REAL,
        totalPoints REAL,
        totalQuestions INTEGER,
        answeredCount INTEGER,
        skippedCount INTEGER,
        submittedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE submitted_quizzes (
        quizId INTEGER,
        userId INTEGER,
        submittedAt TEXT,
        PRIMARY KEY (quizId, userId)
      )
    ''');
  }

  // ── Session ───────────────────────────────────────────────────────────────

  static Future<void> saveSession(Map<String, dynamic> data) async {
    final database = await db;
    await database.delete('session');
    await database.insert('session', {
      'id':     1,
      'token':  data['token'],
      'userId': data['id'],
      'name':   data['name'],
      'email':  data['email'],
      'role':   data['role'],
    });
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final database = await db;
    final rows = await database.query('session', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> clearSession() async {
    final database = await db;
    await database.delete('session');
  }

  // ── Classrooms ────────────────────────────────────────────────────────────

  static Future<void> saveClassrooms(List<dynamic> classrooms) async {
    final database = await db;
    await database.delete('classrooms');
    for (final c in classrooms) {
      await database.insert('classrooms', {
        'id':           c['id'],
        'name':         c['name'],
        'code':         c['code'],
        'teacherName':  c['teacherName'],
        'teacherId':    c['teacherId'],
        'studentCount': c['studentCount'] ?? 0,
        'quizCount':    c['quizCount']    ?? 0,
        'hasBanner':    (c['hasBanner'] == true) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getClassrooms() async {
    final database = await db;
    return database.query('classrooms');
  }

  // ── Quizzes ───────────────────────────────────────────────────────────────

  static Future<void> saveQuizzes(int classroomId, List<dynamic> quizzes) async {
    final database = await db;
    await database.delete('quizzes', where: 'classroomId = ?', whereArgs: [classroomId]);
    for (final q in quizzes) {
      await database.insert('quizzes', {
        'id':                q['id'],
        'classroomId':       classroomId,
        'title':             q['title'],
        'description':       q['description'],
        'published':         (q['published'] == true) ? 1 : 0,
        'questionCount':     q['questionCount']     ?? 0,
        'totalPoints':       q['totalPoints']       ?? 0.0,
        'teacherName':       q['teacherName'],
        'createdAt':         q['createdAt'],
        'timeLimitMinutes':  q['timeLimitMinutes'],         // null = no limit
        'deadline':          q['deadline'],                  // null = no deadline
        'showAnswers':       (q['showAnswers'] == true) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> getQuizzes(int classroomId) async {
    final database = await db;
    return database.query('quizzes', where: 'classroomId = ?', whereArgs: [classroomId]);
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  static Future<void> saveQuizDetail(Map<String, dynamic> quiz) async {
    final database = await db;
    final questions = quiz['questions'] as List<dynamic>? ?? [];

    // Upsert the quiz row itself (preserves teacher-control fields)
    await database.insert('quizzes', {
      'id':                quiz['id'],
      'classroomId':       quiz['classRoomId'] ?? 0,
      'title':             quiz['title'],
      'description':       quiz['description'],
      'published':         (quiz['published'] == true) ? 1 : 0,
      'questionCount':     questions.length,
      'totalPoints':       quiz['totalPoints'] ?? 0.0,
      'teacherName':       quiz['teacherName'],
      'createdAt':         quiz['createdAt'],
      'timeLimitMinutes':  quiz['timeLimitMinutes'],
      'deadline':          quiz['deadline'],
      'showAnswers':       (quiz['showAnswers'] == true) ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await database.delete('questions', where: 'quizId = ?', whereArgs: [quiz['id']]);
    for (final q in questions) {
      await database.insert('questions', {
        'id':      q['id'],
        'quizId':  quiz['id'],
        'text':    q['text'],
        'type':    q['type'],
        'qIndex':  q['qIndex']  ?? 0,
        'points':  q['points']  ?? 1.0,
        'choices': jsonEncode(q['choices'] ?? []),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<Map<String, dynamic>?> getQuizDetail(int quizId) async {
    final database = await db;
    final quizRows = await database.query('quizzes', where: 'id = ?', whereArgs: [quizId]);
    if (quizRows.isEmpty) return null;

    final quiz = Map<String, dynamic>.from(quizRows.first);

    // Restore teacher-control fields to expected JSON key names
    quiz['classRoomId']  = quiz['classroomId'];
    quiz['showAnswers']  = quiz['showAnswers'] == 1;

    final questionRows = await database.query('questions',
        where: 'quizId = ?', whereArgs: [quizId], orderBy: 'qIndex ASC');
    quiz['questions'] = questionRows.map((q) {
      final qMap = Map<String, dynamic>.from(q);
      qMap['choices'] = jsonDecode(q['choices'] as String? ?? '[]');
      return qMap;
    }).toList();
    return quiz;
  }

  // ── Submitted quizzes (one-time lock per user) ────────────────────────────

  static Future<void> markQuizSubmitted(int quizId, int userId) async {
    final database = await db;
    await database.insert('submitted_quizzes', {
      'quizId':      quizId,
      'userId':      userId,
      'submittedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<bool> isQuizSubmitted(int quizId, int userId) async {
    final database = await db;
    final rows = await database.query(
      'submitted_quizzes',
      where: 'quizId = ? AND userId = ?',
      whereArgs: [quizId, userId],
    );
    return rows.isNotEmpty;
  }

  static Future<void> clearSubmittedQuizzes() async {
    final database = await db;
    await database.delete('submitted_quizzes');
  }

  // ── Pending attempts ──────────────────────────────────────────────────────

  static Future<void> savePendingAttempt(int quizId, Map<String, String> answers) async {
    final database = await db;
    await database.insert('pending_attempts', {
      'quizId':    quizId,
      'answers':   jsonEncode(answers),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingAttempts() async {
    final database = await db;
    return database.query('pending_attempts');
  }

  static Future<void> deletePendingAttempt(int id) async {
    final database = await db;
    await database.delete('pending_attempts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Attempts ──────────────────────────────────────────────────────────────

  static Future<void> saveAttempt(Map<String, dynamic> attempt) async {
    final database = await db;
    await database.insert('attempts', {
      'id':             attempt['attemptId'],
      'quizId':         attempt['quizId'],
      'quizTitle':      attempt['quizTitle'],
      'score':          attempt['score'],
      'totalPoints':    attempt['totalPoints'],
      'totalQuestions': attempt['totalQuestions'],
      'answeredCount':  attempt['answeredCount'],
      'skippedCount':   attempt['skippedCount'],
      'submittedAt':    attempt['submittedAt'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getAttempts() async {
    final database = await db;
    return database.query('attempts', orderBy: 'submittedAt DESC');
  }
}