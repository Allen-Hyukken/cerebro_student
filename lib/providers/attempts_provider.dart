import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/services/api_service.dart';

// ── Notifier ──────────────────────────────────────────────────────────────────

class AttemptsNotifier extends AutoDisposeAsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => ApiService.getMyAttempts();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ApiService.getMyAttempts);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Auto-disposes when HistoryScreen is popped, ensuring a fresh fetch on
/// every visit.
final attemptsProvider =
AutoDisposeAsyncNotifierProvider<AttemptsNotifier, List<dynamic>>(
  AttemptsNotifier.new,
);