import 'package:flutter/material.dart';
import '../managers/metrics_manager.dart';
import '../managers/data_manager.dart';
import '../models/question.dart';
import 'study_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MetricsScreen extends StatefulWidget {
  final MetricsManager metricsManager;

  const MetricsScreen({super.key, required this.metricsManager});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  void _openStudySession() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final failedIds = widget.metricsManager.getMostFailedQuestions();
    final studyIds = widget.metricsManager.getQuestionsForStudy();
    final allQuestions = DataManager().allQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await widget.metricsManager.clearMetrics();
              if (context.mounted) {
                Navigator.pop(context); // Go back after clearing
              }
            },
          )
        ],
      ),
      body: failedIds.isEmpty
          ? const Center(
              child: Text(
                'No mistakes recorded yet!\nKeep training!',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                // Study Session Entry Banner
                Card(
                  margin: const EdgeInsets.all(16.0),
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.blue.shade200, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: const Icon(Icons.school, color: Colors.white),
                        ),
                        title: const Text(
                          'Start Study Session',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text(
                          studyIds.isNotEmpty
                              ? '${studyIds.length} question(s) ready for mastery & review'
                              : 'All missed questions currently mastered & up-to-date!',
                          style: TextStyle(
                            color: studyIds.isNotEmpty ? Colors.blue.shade900 : Colors.grey.shade700,
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: studyIds.isNotEmpty ? Colors.blueAccent : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: studyIds.isNotEmpty ? _openStudySession : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Study'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Target mastery streak:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            DropdownButton<int>(
                              value: widget.metricsManager.studyMasteryThreshold,
                              isDense: true,
                              underline: const SizedBox(),
                              items: [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e correct answer${e > 1 ? 's' : ''}'),
                              )).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  await widget.metricsManager.setStudyMasteryThreshold(val);
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Missed Questions Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: failedIds.length,
                    itemBuilder: (context, index) {
                      final id = failedIds[index];
                      final Question? q = allQuestions.where((q) => q.id == id).firstOrNull;

                      if (q == null) return const SizedBox.shrink();

                      final incorrectCount = widget.metricsManager.getIncorrectCount(id);
                      final correctCount = widget.metricsManager.getCorrectCount(id);
                      final streak = widget.metricsManager.getStudyConsecutiveCorrect(id);
                      final total = incorrectCount + correctCount;
                      final rate = (incorrectCount / total * 100).toStringAsFixed(1);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        child: ListTile(
                          title: Text(
                            q.question.trim().isEmpty ? "What does this sign/image indicate?" : q.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Incorrect: $incorrectCount / Total: $total ($rate% fail rate) • Study streak: $streak/${widget.metricsManager.studyMasteryThreshold}'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            _showQuestionDetails(context, q);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showQuestionDetails(BuildContext context, Question q) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Question Details - ${q.category}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(q.question.trim().isEmpty ? "What does this sign/image indicate?" : q.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (q.imagePath != null && q.imagePath!.isNotEmpty)
                  Image.asset(q.imagePath!, height: 100),
                const SizedBox(height: 16),
                const Text('Options:'),
                ...List.generate(q.options.length, (i) {
                  final isCorrect = i == q.correctIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${i+1}. ${q.options[i]}',
                      style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.black,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final failedIds = widget.metricsManager.getMostFailedQuestions();
    final allQuestions = DataManager().allQuestions;

    if (failedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    // UTF-8 BOM for Excel
    buffer.write('\uFEFF');
    buffer.writeln('Question ID,Category,Question Text,Correct Attempts,Incorrect Attempts,Fail Rate (%)');

    for (var id in failedIds) {
      final q = allQuestions.where((q) => q.id == id).firstOrNull;
      if (q == null) continue;

      final incorrectCount = widget.metricsManager.getIncorrectCount(id);
      final correctCount = widget.metricsManager.getCorrectCount(id);
      final total = incorrectCount + correctCount;
      final rate = (incorrectCount / total * 100).toStringAsFixed(1);
      
      final text = q.question.trim().isEmpty ? "What does this sign/image indicate?" : q.question;
      final escapedText = '"${text.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      final escapedCategory = '"${q.category.replaceAll('"', '""')}"';

      buffer.writeln('${q.id},$escapedCategory,$escapedText,$correctCount,$incorrectCount,$rate');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wrong_questions_stats.csv');
      await file.writeAsString(buffer.toString());

      final xFile = XFile(file.path);
      await SharePlus.instance.share(
        ShareParams(
          text: 'My Driving License Test Stats',
          files: [xFile],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }
}
