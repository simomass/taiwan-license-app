import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/question.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  List<Question> allQuestions = [];
  bool isLoaded = false;

  Future<void> loadQuestions() async {
    if (isLoaded) return;
    try {
      final String response = await rootBundle.loadString(
        'assets/questions.json',
      );
      final List<dynamic> data = json.decode(response);
      allQuestions = data.map((q) => Question.fromJson(q)).toList();
      isLoaded = true;
    } catch (e) {
      debugPrint("Errore nel caricamento del JSON: $e");
    }
  }

  List<Question> getQuestionsByCategory(String categoryName) {
    return allQuestions.where((q) => q.category == categoryName).toList();
  }

  List<String> getAllCategories() {
    return allQuestions.map((q) => q.category).toSet().toList();
  }
}
