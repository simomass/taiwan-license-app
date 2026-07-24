import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question.dart';
import '../managers/data_manager.dart';
import '../managers/metrics_manager.dart';
import '../managers/study_queue_manager.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final MetricsManager _metricsManager = MetricsManager();
  final DataManager _dataManager = DataManager();

  WebViewController? _webViewController;
  StudyQueue? _studyQueue;

  bool _isLoading = true;
  bool _isRecordingAnswer = false;
  bool _hasAnswered = false;

  int? _selectedAnswerIndex;
  StudyAnswerResult? _pendingResult;

  bool get _isWebViewSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    if (_isWebViewSupported) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000));
    }
    _initStudySession();
  }

  Future<void> _initStudySession() async {
    setState(() {
      _isLoading = true;
    });

    await _dataManager.loadQuestions();
    await _metricsManager.loadMetrics();

    final eligibleIds = _metricsManager.getQuestionsForStudy();
    final eligibleSet = eligibleIds.toSet();

    final studyQuestions = _dataManager.allQuestions
        .where((q) => eligibleSet.contains(q.id))
        .toList();

    if (studyQuestions.isEmpty) {
      setState(() {
        _studyQueue = null;
        _isLoading = false;
      });
      return;
    }

    _studyQueue = StudyQueue(studyQuestions);
    _loadCurrentVideoIfNeeded();

    setState(() {
      _isLoading = false;
    });
  }

  void _loadCurrentVideoIfNeeded() {
    final q = _studyQueue?.currentQuestion;
    if (q != null &&
        _isWebViewSupported &&
        _webViewController != null &&
        q.videoUrl != null &&
        q.videoUrl!.isNotEmpty) {
      _webViewController!.loadRequest(Uri.parse(q.videoUrl!));
    }
  }

  Future<void> _launchExternalVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onAnswerSelected(int selectedIndex) async {
    if (_hasAnswered || _isRecordingAnswer || _studyQueue == null) return;

    final q = _studyQueue!.currentQuestion;
    if (q == null) return;

    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _isRecordingAnswer = true;
    });

    final isCorrect = selectedIndex == q.correctIndex;

    try {
      final result = await _metricsManager.recordStudyAnswer(q.id, isCorrect);
      if (!mounted) return;

      setState(() {
        _pendingResult = result;
        _hasAnswered = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving answer: $e. Tap to try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _onAnswerSelected(selectedIndex),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingAnswer = false;
        });
      }
    }
  }

  void _onNextPressed() {
    if (_studyQueue == null || _pendingResult == null) return;

    _studyQueue!.applyAnswerResult(_pendingResult!);

    setState(() {
      _selectedAnswerIndex = null;
      _pendingResult = null;
      _hasAnswered = false;
    });

    _loadCurrentVideoIfNeeded();
  }

  void _onSkipPressed() {
    if (_studyQueue == null || _hasAnswered || _isRecordingAnswer) return;

    _studyQueue!.skipCurrentQuestion();

    setState(() {
      _selectedAnswerIndex = null;
      _pendingResult = null;
      _hasAnswered = false;
    });

    _loadCurrentVideoIfNeeded();
  }

  Widget _buildOptionButton(Question q, int index) {
    final optionText = q.options[index];
    final isSelected = _selectedAnswerIndex == index;
    final canShowFeedback = _hasAnswered && _pendingResult != null;

    Color? backgroundColor;
    Color? foregroundColor;

    if (canShowFeedback) {
      if (index == q.correctIndex) {
        backgroundColor = Colors.green.shade600;
        foregroundColor = Colors.white;
      } else if (isSelected && !_pendingResult!.isCorrect) {
        backgroundColor = Colors.red.shade600;
        foregroundColor = Colors.white;
      } else {
        backgroundColor = Colors.grey.shade300;
        foregroundColor = Colors.grey.shade700;
      }
    } else if (isSelected) {
      backgroundColor = Colors.blue.shade200;
      foregroundColor = Colors.black;
    }

    final VoidCallback? onPressed = (_hasAnswered || _isRecordingAnswer)
        ? null
        : () => _onAnswerSelected(index);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        ),
        onPressed: onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${index + 1}. $optionText',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    if (!_hasAnswered || _pendingResult == null) return const SizedBox.shrink();

    final result = _pendingResult!;
    String bannerText;
    Color color;

    if (result.masteredNow) {
      bannerText =
          "Mastered! (${_metricsManager.studyMasteryThreshold}/${_metricsManager.studyMasteryThreshold}) Scheduled for future review.";
      color = Colors.green.shade700;
    } else if (result.wasDueReview && result.isCorrect) {
      bannerText = "Review Complete! Next review scheduled.";
      color = Colors.green.shade700;
    } else if (result.isCorrect) {
      bannerText =
          "Correct! (${result.studyConsecutiveCorrect}/${_metricsManager.studyMasteryThreshold})";
      color = Colors.green.shade700;
    } else {
      bannerText =
          "Incorrect - Streak reset (0/${_metricsManager.studyMasteryThreshold})";
      color = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            result.isCorrect ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Modality')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars, size: 80, color: Colors.amber.shade600),
              const SizedBox(height: 16),
              const Text(
                'No Questions to Study!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You have no missed questions or all missed questions are currently mastered and not yet due for review.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to Performance'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedView() {
    final stats = _studyQueue!.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Session Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 16),
            const Text(
              'Session Finished!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your progress has been saved.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatRow('Questions Mastered', '${stats.mastered}'),
                    const Divider(),
                    _buildStatRow(
                      'Due Reviews Completed',
                      '${stats.dueReviewsCompleted}',
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Correct Answers',
                      '${stats.answeredCorrect}',
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Incorrect Answers',
                      '${stats.answeredIncorrect}',
                    ),
                    const Divider(),
                    _buildStatRow('Skipped Questions', '${stats.skipped}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to Performance',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Modality')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_studyQueue == null) {
      return _buildEmptyView();
    }

    if (_studyQueue!.isFinished) {
      return _buildFinishedView();
    }

    final q = _studyQueue!.currentQuestion!;
    final streak = _metricsManager.getStudyConsecutiveCorrect(q.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Modality'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_studyQueue!.remainingCount} remaining',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: const Icon(Icons.category, size: 16),
                  label: Text(q.category, style: const TextStyle(fontSize: 12)),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.bolt,
                    size: 16,
                    color: Colors.orange,
                  ),
                  label: Text(
                    'Streak: $streak/${_metricsManager.studyMasteryThreshold}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q.question.trim().isEmpty
                  ? "What does this sign/image indicate?"
                  : q.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (q.imagePath != null && q.imagePath!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: Image.asset(
                    q.imagePath!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        "Immagine non trovata",
                        style: TextStyle(color: Colors.red),
                      );
                    },
                  ),
                ),
              ),
            if (q.videoUrl != null && q.videoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _isWebViewSupported && _webViewController != null
                    ? Container(
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: WebViewWidget(controller: _webViewController!),
                      )
                    : Column(
                        children: [
                          const Text(
                            "Embedded player not supported on this platform.",
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text("Open Video in Browser"),
                            onPressed: () => _launchExternalVideo(q.videoUrl!),
                          ),
                        ],
                      ),
              ),
            ...List.generate(
              q.options.length,
              (index) => _buildOptionButton(q, index),
            ),
            _buildFeedbackBanner(),
            const SizedBox(height: 16),
            if (!_hasAnswered)
              TextButton.icon(
                icon: const Icon(Icons.skip_next, color: Colors.grey),
                label: const Text(
                  "Skip for this session",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                onPressed: _isRecordingAnswer ? null : _onSkipPressed,
              ),
            if (_hasAnswered && _pendingResult != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Next", style: TextStyle(fontSize: 18)),
                onPressed: _onNextPressed,
              ),
          ],
        ),
      ),
    );
  }
}
