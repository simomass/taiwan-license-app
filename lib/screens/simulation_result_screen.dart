import 'package:flutter/material.dart';
import '../models/question.dart';

class SimulationResultScreen extends StatelessWidget {
  final int score;
  final List<Map<String, dynamic>> wrongAnswers;

  const SimulationResultScreen({
    super.key,
    required this.score,
    required this.wrongAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final bool passed = score >= 85;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulation Result'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              passed ? 'PASSED' : 'FAILED',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Score: $score / 100',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Text(
              'Failed Questions Review:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (wrongAnswers.isEmpty)
              const Text('Perfect score! No failed questions.', style: TextStyle(fontSize: 16)),
            ...wrongAnswers.map((w) {
              final Question q = w['question'];
              final int selected = w['selected'];
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Your answer: ${selected >= 0 ? q.options[selected] : "Not answered"}', style: const TextStyle(color: Colors.red)),
                      Text('Correct answer: ${q.options[q.correctIndex]}', style: const TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
