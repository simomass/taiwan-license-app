import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question.dart';
import '../managers/data_manager.dart';
import '../managers/metrics_manager.dart';

class TrainingScreen extends StatefulWidget {
  final String category;

  const TrainingScreen({super.key, required this.category});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  WebViewController? _webViewController;
  List<Question> _pendingQuestions = [];
  Question? _currentQuestion;
  String _feedbackText = "";
  bool _answered = false;
  int _totalQuestions = 0;
  int _solvedCount = 0;
  final MetricsManager _metricsManager = MetricsManager();

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
    _loadData();
  }

  Future<void> _loadData() async {
    await _metricsManager.loadMetrics();

    final categoryQuestions =
        DataManager().getQuestionsByCategory(widget.category);
    _totalQuestions = categoryQuestions.length;

    _pendingQuestions = List.from(categoryQuestions);
    _pendingQuestions.shuffle();

    _nextQuestion();
  }

  void _nextQuestion() {
    setState(() {
      _feedbackText = "";
      _answered = false;
      if (_pendingQuestions.isNotEmpty) {
        _currentQuestion = _pendingQuestions.first;
        if (_isWebViewSupported &&
            _webViewController != null &&
            _currentQuestion!.videoUrl != null &&
            _currentQuestion!.videoUrl!.isNotEmpty) {
          _webViewController!
              .loadRequest(Uri.parse(_currentQuestion!.videoUrl!));
        }
      } else {
        _currentQuestion = null;
      }
    });
  }

  void _skipQuestion() {
    if (_pendingQuestions.isNotEmpty) {
      final current = _pendingQuestions.removeAt(0);
      _pendingQuestions.add(current); // Move to the end of the queue
      _nextQuestion();
    }
  }

  Future<void> _checkAnswer(int selectedIndex) async {
    if (_answered || _currentQuestion == null) return;

    final isCorrect = selectedIndex == _currentQuestion!.correctIndex;

    // Log to metrics
    await _metricsManager.recordAnswer(_currentQuestion!.id, isCorrect);

    setState(() {
      _answered = true;
      if (isCorrect) {
        _feedbackText = "Corretto!";
        _solvedCount++;
      } else {
        _feedbackText = "Sbagliato!";
      }
    });
  }

  Future<void> _launchExternalVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestion == null && _totalQuestions == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: _currentQuestion == null
          ? const Center(
              child: Text(
                "Hai completato tutte le domande di questa categoria!",
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Risolte in questa sessione: $_solvedCount / $_totalQuestions",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _currentQuestion!.question.trim().isEmpty
                        ? "What does this sign/image indicate?"
                        : _currentQuestion!.question,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  if (_currentQuestion!.imagePath != null &&
                      _currentQuestion!.imagePath!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: Image.asset(
                          _currentQuestion!.imagePath!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text("Immagine non trovata",
                                style: TextStyle(color: Colors.red));
                          },
                        ),
                      ),
                    ),
                  if (_currentQuestion!.videoUrl != null &&
                      _currentQuestion!.videoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _isWebViewSupported && _webViewController != null
                          ? Container(
                              height: 250,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                              ),
                              child: WebViewWidget(
                                  controller: _webViewController!),
                            )
                          : Column(
                              children: [
                                const Text(
                                  "L'embedded player non è supportato su questa piattaforma.",
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.open_in_browser),
                                  label: const Text("Apri Video nel Browser"),
                                  onPressed: () => _launchExternalVideo(
                                      _currentQuestion!.videoUrl!),
                                ),
                              ],
                            ),
                    ),
                  ...List.generate(_currentQuestion!.options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ElevatedButton(
                        onPressed: _answered ? null : () => _checkAnswer(index),
                        child: Text(_currentQuestion!.options[index]),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  if (!_answered)
                    TextButton(
                      onPressed: _skipQuestion,
                      child: const Text("Skip Question",
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                  if (_answered) ...[
                    Text(
                      _feedbackText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _feedbackText == "Corretto!"
                            ? Colors.green
                            : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_feedbackText == "Corretto!") {
                          _pendingQuestions.removeAt(0);
                        } else {
                          final current = _pendingQuestions.removeAt(0);
                          _pendingQuestions.add(current);
                        }
                        _nextQuestion();
                      },
                      child: const Text("Prossima Domanda",
                          style: TextStyle(fontSize: 18)),
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}
