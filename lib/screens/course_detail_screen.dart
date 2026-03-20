import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/screens/quiz_intro_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final ClassroomModel classroom;
  const CourseDetailScreen({super.key, required this.classroom});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<QuizModel> _quizzes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getClassroomQuizzes(widget.classroom.id);
      setState(() => _quizzes = data.map((j) => QuizModel.fromJson(j)).toList());
    } catch (e) {
      setState(() => _error = 'Failed to load quizzes.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FIX: Build the classroom header banner.
  //      Load from the API (with JWT header) when hasBanner is true,
  //      otherwise show the gradient placeholder.
  Widget _buildBannerRight(double width, double height) {
    final borderRadius = const BorderRadius.only(
      topRight: Radius.circular(20),
      bottomRight: Radius.circular(20),
    );

    if (widget.classroom.hasBanner) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          ApiService.getBannerUrl(widget.classroom.id),
          width: width,
          height: height,
          fit: BoxFit.cover,
          headers: {
            if (ApiService.token != null)
              'Authorization': 'Bearer ${ApiService.token}',
          },
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _bannerPlaceholder(width, height, borderRadius);
          },
          errorBuilder: (_, __, ___) =>
              _bannerPlaceholder(width, height, borderRadius),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: _bannerPlaceholder(width, height, null),
    );
  }

  Widget _bannerPlaceholder(double width, double height, BorderRadius? borderRadius) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.75), AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.school, color: Colors.white54, size: 60),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2), color: AppColors.white),
                child: ClipOval(child: Image.asset('assets/icons/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 20, color: AppColors.primary))),
              ),
              const SizedBox(width: 12),
            ]),
          ),

          // Classroom header card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final half = constraints.maxWidth / 2;
                return Row(children: [
                  SizedBox(
                    width: half,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(widget.classroom.name, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Row(children: [const Icon(Icons.tag, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('Code: ${widget.classroom.code}', style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                        const SizedBox(height: 5),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 14, color: AppColors.primary), const SizedBox(width: 4),
                          Flexible(child: Text('Teacher: ${widget.classroom.teacherName ?? ''}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                        ]),
                      ]),
                    ),
                  ),
                  // FIX: replaced Image.asset with network banner loader
                  _buildBannerRight(half, 150),
                ]);
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Quiz grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadQuizzes, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Retry')),
            ]))
                : _quizzes.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.quiz_outlined, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text('No quizzes yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ]))
                : RefreshIndicator(
              onRefresh: _loadQuizzes,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
                ),
                itemCount: _quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = _quizzes[index];
                  return _QuizCard(
                    quiz: quiz,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizIntroScreen(quiz: quiz))),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizModel quiz;
  final VoidCallback onTap;
  const _QuizCard({required this.quiz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(quiz.title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis, maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.quiz_outlined, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('${quiz.questionCount} Questions', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.star_outline, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('${quiz.totalPoints} pts', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
        ]),
      ),
    );
  }
}