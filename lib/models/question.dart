class Question {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? videoId;
  final String? videoUrl;
  final String? imagePath;
  final String? source;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.videoId,
    this.videoUrl,
    this.imagePath,
    this.source,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    // Read the correct index and options
    int correctIndex = json['correct_index'];
    List<String> options = List<String>.from(json['options']);

    // We can shuffle the options to provide more variety, but we must track the correct option
    if (options.length > 1 &&
        (json['source'] != 'pdf_3.pdf' && json['source'] != 'pdf_5.pdf')) {
      // Don't shuffle True/False questions (pdf_3 and pdf_5) to keep O/X consistent
      String correctText = options[correctIndex];
      options.shuffle();
      correctIndex = options.indexOf(correctText);
    }

    return Question(
      id: json['id'].toString(),
      question: json['question'],
      options: options,
      correctIndex: correctIndex,
      videoId: json['video_id'],
      videoUrl: json['video_url'],
      imagePath: json['image_path'],
      source: json['source'],
    );
  }

  // Get human-readable category based on the source PDF
  String get category {
    switch (source) {
      case 'pdf_1.pdf':
        return 'Motorcycle License Written Test Question Bank';
      case 'pdf_2.pdf':
        return 'Hazard Perception Video';
      case 'pdf_3.pdf':
        return 'Regulations (True/False)';
      case 'pdf_4.pdf':
        return 'Regulations (Multiple Choice)';
      case 'pdf_5.pdf':
        return 'Road Signs, Markings, Traffic Signals (True/False)';
      case 'pdf_6.pdf':
        return 'Road Signs, Markings, Traffic Signals (Multiple Choice)';
      default:
        return 'General Knowledge';
    }
  }

  // Check if it's a video question
  bool get isVideoQuestion => source == 'pdf_2.pdf';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_index': correctIndex,
      'video_id': videoId,
      'video_url': videoUrl,
      'image_path': imagePath,
      'source': source,
    };
  }

  factory Question.fromSavedJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'].toString(),
      question: json['question'],
      options: List<String>.from(json['options']),
      correctIndex: json['correct_index'],
      videoId: json['video_id'],
      videoUrl: json['video_url'],
      imagePath: json['image_path'],
      source: json['source'],
    );
  }
}
