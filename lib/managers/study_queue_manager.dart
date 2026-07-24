import 'dart:math';
import '../models/question.dart';
import 'metrics_manager.dart';

class StudySessionStats {
  int answeredCorrect = 0;
  int answeredIncorrect = 0;
  int mastered = 0;
  int skipped = 0;
  int dueReviewsCompleted = 0;

  int get totalAnswers => answeredCorrect + answeredIncorrect;
}

class StudyQueue {
  final List<Question> _deck;
  final Random _random;
  final StudySessionStats stats = StudySessionStats();

  StudyQueue(List<Question> initialQuestions, {Random? random})
    : _deck = List.from(initialQuestions),
      _random = random ?? Random() {
    _deck.shuffle(_random);
  }

  bool get isFinished => _deck.isEmpty;
  int get remainingCount => _deck.length;

  Question? get currentQuestion => _deck.isNotEmpty ? _deck.first : null;

  void applyAnswerResult(StudyAnswerResult result) {
    if (isFinished) return;

    final current = _deck.removeAt(0);

    if (!result.isCorrect) {
      stats.answeredIncorrect++;
      _reinsert(current, minGap: 2, maxGap: 4);
    } else if (result.wasDueReview) {
      stats.answeredCorrect++;
      stats.dueReviewsCompleted++;
      // Mastered due review complete: remove from current session deck
    } else if (result.masteredNow) {
      stats.answeredCorrect++;
      stats.mastered++;
      // Mastered now (reached 3/3): remove from current session deck
    } else {
      stats.answeredCorrect++;
      _reinsert(current, minGap: 4, maxGap: 7);
    }
  }

  void skipCurrentQuestion() {
    if (isFinished) return;
    _deck.removeAt(0);
    stats.skipped++;
  }

  void _reinsert(
    Question question, {
    required int minGap,
    required int maxGap,
  }) {
    final len = _deck.length;
    if (len <= 0) {
      _deck.add(question);
      return;
    }

    final minIndex = min(minGap, len);
    final maxIndex = min(maxGap, len);

    int targetIndex;
    if (maxIndex <= minIndex) {
      targetIndex = minIndex;
    } else {
      targetIndex = minIndex + _random.nextInt(maxIndex - minIndex + 1);
    }

    _deck.insert(targetIndex, question);
  }
}
