import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class StudyAnswerResult {
  final String questionId;
  final bool isCorrect;
  final int studyConsecutiveCorrect;
  final bool masteredNow;
  final bool wasDueReview;
  final DateTime? nextReviewAt;

  const StudyAnswerResult({
    required this.questionId,
    required this.isCorrect,
    required this.studyConsecutiveCorrect,
    required this.masteredNow,
    required this.wasDueReview,
    required this.nextReviewAt,
  });

  bool get isMastered => studyConsecutiveCorrect >= 3;
}

class MetricsManager {
  static final MetricsManager _instance = MetricsManager._internal();
  factory MetricsManager() => _instance;
  MetricsManager._internal();

  static const String _metricsKey = 'question_metrics';
  int studyMasteryThreshold = 3;

  // Structure: { questionId: { 'correct': int, 'incorrect': int, 'study_consecutive_correct': int, ... } }
  Map<String, Map<String, dynamic>> _metrics = {};

  Future<void> setStudyMasteryThreshold(int val) async {
    studyMasteryThreshold = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('studyMasteryThreshold', val);
  }

  Future<void> loadMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    studyMasteryThreshold = prefs.getInt('studyMasteryThreshold') ?? 3;
    final String? data = prefs.getString(_metricsKey);
    if (data != null) {
      try {
        final decoded = json.decode(data) as Map<String, dynamic>;
        _metrics = decoded.map((key, value) {
          return MapEntry(
            key,
            Map<String, dynamic>.from(value as Map),
          );
        });
      } catch (e) {
        // If there's an error parsing, we just keep the empty map
      }
    }
  }

  Future<void> _saveMetricsMap(
      Map<String, Map<String, dynamic>> metricsToSave) async {
    final prefs = await SharedPreferences.getInstance();
    final success =
        await prefs.setString(_metricsKey, json.encode(metricsToSave));
    if (!success) {
      throw StateError('Failed to save metrics to SharedPreferences');
    }
  }

  Future<void> _saveMetrics() async {
    await _saveMetricsMap(_metrics);
  }

  Future<void> recordAnswer(String questionId, bool isCorrect) async {
    if (!_metrics.containsKey(questionId)) {
      _metrics[questionId] = {'correct': 0, 'incorrect': 0};
    }

    if (isCorrect) {
      _metrics[questionId]!['correct'] = (getCorrectCount(questionId)) + 1;
    } else {
      _metrics[questionId]!['incorrect'] = (getIncorrectCount(questionId)) + 1;
    }

    await _saveMetrics();
  }

  int getCorrectCount(String questionId) {
    final val = _metrics[questionId]?['correct'];
    return val is int ? val : 0;
  }

  int getIncorrectCount(String questionId) {
    final val = _metrics[questionId]?['incorrect'];
    return val is int ? val : 0;
  }

  int getTotalAttempts(String questionId) {
    return getCorrectCount(questionId) + getIncorrectCount(questionId);
  }

  double getFailureRate(String questionId) {
    int total = getTotalAttempts(questionId);
    if (total == 0) return 0.0;
    return getIncorrectCount(questionId) / total;
  }

  // Returns question IDs sorted by number of incorrect answers (descending)
  List<String> getMostFailedQuestions() {
    final List<MapEntry<String, Map<String, dynamic>>> entries =
        _metrics.entries.toList();
    entries.sort((a, b) {
      final aIncorrect = (a.value['incorrect'] as int?) ?? 0;
      final bIncorrect = (b.value['incorrect'] as int?) ?? 0;
      return bIncorrect.compareTo(aIncorrect); // Descending
    });
    return entries
        .where((e) => ((e.value['incorrect'] as int?) ?? 0) > 0)
        .map((e) => e.key)
        .toList();
  }

  // Study Modality Extensions
  int getStudyConsecutiveCorrect(String questionId) {
    final val = _metrics[questionId]?['study_consecutive_correct'];
    return val is int ? val : 0;
  }

  DateTime? _parseMetricDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  List<String> getQuestionsForStudy({DateTime? now}) {
    final currentUtc = (now ?? DateTime.now()).toUtc();
    final List<String> eligible = [];

    for (var entry in _metrics.entries) {
      final qId = entry.key;
      final data = entry.value;

      final incorrect = (data['incorrect'] as int?) ?? 0;
      if (incorrect <= 0) continue;

      final studyStreak = (data['study_consecutive_correct'] as int?) ?? 0;
      if (studyStreak < studyMasteryThreshold) {
        eligible.add(qId);
      } else {
        // Mastered: check if due for review
        final nextReviewAt = _parseMetricDate(data['study_next_review_at']);
        if (nextReviewAt == null || !nextReviewAt.isAfter(currentUtc)) {
          eligible.add(qId);
        }
      }
    }

    return eligible;
  }

  int _calculateNextReviewInterval(int currentInterval) {
    if (currentInterval < 4) return 4;
    if (currentInterval < 10) return 10;
    return 30;
  }

  Future<StudyAnswerResult> recordStudyAnswer(
    String questionId,
    bool isCorrect, {
    DateTime? answeredAt,
  }) async {
    final now = (answeredAt ?? DateTime.now()).toUtc();

    // Deep copy current metrics map for transactional persistence
    final snapshot =
        _metrics.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    final originalMetrics = Map<String, dynamic>.from(
      snapshot[questionId] ??
          <String, dynamic>{
            'correct': 0,
            'incorrect': 0,
          },
    );
    final updatedMetrics = Map<String, dynamic>.from(originalMetrics);

    final previousStreak =
        (originalMetrics['study_consecutive_correct'] as int?) ?? 0;
    final nextReviewDateParsed =
        _parseMetricDate(originalMetrics['study_next_review_at']);
    final wasDueReview = previousStreak >= studyMasteryThreshold &&
        (nextReviewDateParsed == null || !nextReviewDateParsed.isAfter(now));

    bool masteredNow = false;
    DateTime? nextReviewAt;

    if (isCorrect) {
      updatedMetrics['correct'] =
          ((originalMetrics['correct'] as int?) ?? 0) + 1;
      updatedMetrics['study_last_reviewed_at'] = now.toIso8601String();

      if (wasDueReview) {
        updatedMetrics['study_consecutive_correct'] = studyMasteryThreshold;
        final currentInterval =
            (originalMetrics['study_review_interval_days'] as int?) ?? 0;
        final nextInterval = _calculateNextReviewInterval(currentInterval);
        updatedMetrics['study_review_interval_days'] = nextInterval;
        nextReviewAt = now.add(Duration(days: nextInterval));
        updatedMetrics['study_next_review_at'] = nextReviewAt.toIso8601String();
      } else {
        final nextStreak = min(previousStreak + 1, studyMasteryThreshold);
        updatedMetrics['study_consecutive_correct'] = nextStreak;

        if (nextStreak >= studyMasteryThreshold) {
          masteredNow = true;
          const firstInterval = 4;
          updatedMetrics['study_mastered_at'] = now.toIso8601String();
          updatedMetrics['study_review_interval_days'] = firstInterval;
          nextReviewAt = now.add(const Duration(days: firstInterval));
          updatedMetrics['study_next_review_at'] =
              nextReviewAt.toIso8601String();
        }
      }
    } else {
      updatedMetrics['incorrect'] =
          ((originalMetrics['incorrect'] as int?) ?? 0) + 1;
      updatedMetrics['study_consecutive_correct'] = 0;
      updatedMetrics['study_last_reviewed_at'] = now.toIso8601String();
      updatedMetrics['study_mastered_at'] = null;
      updatedMetrics['study_next_review_at'] = null;
      updatedMetrics['study_review_interval_days'] = null;
    }

    snapshot[questionId] = updatedMetrics;

    // Save snapshot to storage
    await _saveMetricsMap(snapshot);

    // Commit to in-memory state on success
    _metrics = snapshot;

    return StudyAnswerResult(
      questionId: questionId,
      isCorrect: isCorrect,
      studyConsecutiveCorrect:
          (updatedMetrics['study_consecutive_correct'] as int?) ?? 0,
      masteredNow: masteredNow,
      wasDueReview: wasDueReview,
      nextReviewAt: nextReviewAt,
    );
  }

  Future<void> clearMetrics() async {
    _metrics.clear();
    await _saveMetrics();
  }
}
