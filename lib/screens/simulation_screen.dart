import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';
import '../managers/data_manager.dart';
import '../managers/metrics_manager.dart';
import 'simulation_result_screen.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  List<Question> _simulationQuestions = [];
  Map<int, int> _userAnswers = {}; // question index -> selected option index
  Set<int> _skippedQuestions = {}; // question indices that user navigated away from without answering
  int _currentIndex = 0;
  bool _isGenerating = true;
  bool _isOverviewExpanded = true;
  
  Timer? _timer;
  int _secondsRemaining = 1800; // 30 minutes

  WebViewController? _webViewController;

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
    _loadOrGenerateSimulation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveSimulationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sim_active', true);
      
      final questionsJson = _simulationQuestions.map((q) => q.toJson()).toList();
      await prefs.setString('sim_questions', jsonEncode(questionsJson));
      
      final answersJson = _userAnswers.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString('sim_answers', jsonEncode(answersJson));
      
      await prefs.setString('sim_skipped', jsonEncode(_skippedQuestions.toList()));
      await prefs.setInt('sim_current_index', _currentIndex);
      await prefs.setInt('sim_seconds_remaining', _secondsRemaining);
    } catch (e) {
      debugPrint("Error saving simulation state: $e");
    }
  }

  Future<void> _clearSimulationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sim_active');
      await prefs.remove('sim_questions');
      await prefs.remove('sim_answers');
      await prefs.remove('sim_skipped');
      await prefs.remove('sim_current_index');
      await prefs.remove('sim_seconds_remaining');
    } catch (e) {
      debugPrint("Error clearing simulation state: $e");
    }
  }

  Future<void> _loadOrGenerateSimulation() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool('sim_active') ?? false;
    
    if (active) {
      try {
        final questionsStr = prefs.getString('sim_questions');
        final answersStr = prefs.getString('sim_answers');
        final skippedStr = prefs.getString('sim_skipped');
        final currentIndex = prefs.getInt('sim_current_index') ?? 0;
        final secondsRemaining = prefs.getInt('sim_seconds_remaining') ?? 1800;
        
        if (questionsStr != null) {
          final List<dynamic> questionsList = jsonDecode(questionsStr);
          final questions = questionsList.map((q) => Question.fromSavedJson(q)).toList();
          
          Map<int, int> answers = {};
          if (answersStr != null) {
            final Map<String, dynamic> answersMap = jsonDecode(answersStr);
            answers = answersMap.map((k, v) => MapEntry(int.parse(k), v as int));
          }
          
          Set<int> skipped = {};
          if (skippedStr != null) {
            final List<dynamic> skippedList = jsonDecode(skippedStr);
            skipped = Set<int>.from(skippedList.cast<int>());
          }
          
          setState(() {
            _simulationQuestions = questions;
            _userAnswers = answers;
            _skippedQuestions = skipped;
            _currentIndex = currentIndex;
            _secondsRemaining = secondsRemaining;
            _isGenerating = false;
          });
          
          _startTimer();
          _updateVideoForCurrentQuestion();
          return;
        }
      } catch (e) {
        debugPrint("Error loading simulation: $e");
      }
    }
    
    _generateNewSimulation();
  }

  void _generateNewSimulation() {
    final allQs = DataManager().allQuestions;
    
    // 1. Get 15 Video Questions
    final videoQs = allQs.where((q) => q.isVideoQuestion).toList();
    videoQs.shuffle();
    final selectedVideoQs = videoQs.take(15).toList();

    // 2. Get 35 General Knowledge Questions
    final otherQs = allQs.where((q) => !q.isVideoQuestion).toList();
    otherQs.shuffle();
    final selectedOtherQs = otherQs.take(35).toList();

    // Combine them, but keep video questions first
    _simulationQuestions = [...selectedVideoQs, ...selectedOtherQs];
    _secondsRemaining = 1800; // 30 minutes
    _currentIndex = 0;
    _userAnswers.clear();
    _skippedQuestions.clear();
    
    setState(() {
      _isGenerating = false;
    });
    
    _startTimer();
    _updateVideoForCurrentQuestion();
    _saveSimulationState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        
        // Save state every 5 seconds to minimize disk writes
        if (_secondsRemaining % 5 == 0) {
          _saveSimulationState();
        }
      } else {
        _timer?.cancel();
        _finishSimulation(); // automatically submit when time is up
      }
    });
  }

  String get _timeString {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  void _updateVideoForCurrentQuestion() {
    if (!_isWebViewSupported || _webViewController == null) return;
    
    final q = _simulationQuestions[_currentIndex];
    final url = q.videoUrl;
    if (url != null && url.isNotEmpty) {
      WebViewCookieManager().clearCookies();
      _webViewController!.loadRequest(Uri.parse(url));
    }
  }

  void _answerQuestion(int selectedIndex) {
    setState(() {
      _userAnswers[_currentIndex] = selectedIndex;
      _skippedQuestions.remove(_currentIndex);
    });
    _saveSimulationState();
  }

  void _markAsSkippedIfNeeded() {
    if (!_userAnswers.containsKey(_currentIndex)) {
      _skippedQuestions.add(_currentIndex);
    }
  }

  void _goToQuestion(int index) {
    _markAsSkippedIfNeeded();
    setState(() {
      _currentIndex = index;
    });
    _updateVideoForCurrentQuestion();
    _saveSimulationState();
  }

  void _nextQuestion() {
    if (_currentIndex < 49) {
      _goToQuestion(_currentIndex + 1);
    } else {
      _markAsSkippedIfNeeded();
      _finishSimulation();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      _goToQuestion(_currentIndex - 1);
    }
  }

  Future<void> _finishSimulation() async {
    _timer?.cancel();
    await _clearSimulationState();

    // Record metrics and calculate score
    final metricsManager = MetricsManager();
    
    int correctCount = 0;
    List<Map<String, dynamic>> wrongAnswers = [];

    for (int i = 0; i < _simulationQuestions.length; i++) {
      final q = _simulationQuestions[i];
      final userAnswer = _userAnswers[i] ?? -1;
      
      final isCorrect = userAnswer == q.correctIndex;
      if (userAnswer != -1) {
        await metricsManager.recordAnswer(q.id, isCorrect);
      }

      if (isCorrect) {
        correctCount++;
      } else {
        wrongAnswers.add({
          'question': q,
          'selected': userAnswer,
        });
      }
    }

    final score = correctCount * 2; // 2 points per question

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SimulationResultScreen(
          score: score,
          wrongAnswers: wrongAnswers,
        ),
      ),
    );
  }

  Future<void> _launchExternalVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool?> _showAbandonDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Simulation?'),
        content: const Text('Do you want to abandon the simulation? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = _simulationQuestions[_currentIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final abandon = await _showAbandonDialog();
        if (abandon == true && mounted) {
          await _clearSimulationState();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Simulation ($_timeString)'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  '${_currentIndex + 1}/50',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    q.question.trim().isEmpty ? "What does this sign/image indicate?" : q.question,
                    style: const TextStyle(fontSize: 20),
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
                            return const Text("Immagine non trovata", style: TextStyle(color: Colors.red));
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
                                  "L'embedded player non è supportato su questa piattaforma.",
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.open_in_browser),
                                  label: const Text("Apri Video nel Browser"),
                                  onPressed: () => _launchExternalVideo(q.videoUrl!),
                                ),
                              ],
                            ),
                    ),
                    
                  ...List.generate(q.options.length, (index) {
                    final isSelected = _userAnswers[_currentIndex] == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.blue.shade200 : null,
                        ),
                        onPressed: () => _answerQuestion(index),
                        child: Text(
                          q.options[index],
                          style: TextStyle(color: isSelected ? Colors.black : null),
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 30),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _currentIndex > 0 ? _previousQuestion : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _nextQuestion,
                        child: Text(_currentIndex == 49 ? 'Finish Test' : 'Next / Skip'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          
          // The 50-box grid
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey.shade200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(
                            _isOverviewExpanded
                                ? Icons.keyboard_double_arrow_down
                                : Icons.keyboard_double_arrow_up,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _isOverviewExpanded = !_isOverviewExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                    Text(
                      '${_userAnswers.length} / 50 answered',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isOverviewExpanded)
                Center(
                  child: Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    alignment: WrapAlignment.center,
                    children: List.generate(50, (index) {
                      final isAnswered = _userAnswers.containsKey(index);
                      final isSkipped = _skippedQuestions.contains(index);
                      final isCurrent = index == _currentIndex;

                      Color boxColor = Colors.red.shade400; // Unanswered
                      if (isAnswered) {
                        boxColor = Colors.yellow.shade600;
                      } else if (isSkipped) {
                        boxColor = Colors.grey.shade400;
                      }

                      return GestureDetector(
                        onTap: () => _goToQuestion(index),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: boxColor,
                            borderRadius: BorderRadius.circular(4),
                            border: isCurrent 
                                ? Border.all(color: Colors.black, width: 2.5) 
                                : Border.all(color: Colors.black12, width: 1),
                            boxShadow: isCurrent ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                color: (isAnswered || isSkipped) ? Colors.black87 : Colors.white,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ));
  }
}
