enum GuideRole { user, guide }

enum GuideErrorKind { network, quota, other }

class GuideQuiz {
  const GuideQuiz({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correct;
  final String explanation;

  factory GuideQuiz.fromJson(Map<String, dynamic> j) => GuideQuiz(
        question: j['question'] as String,
        options: [for (final o in j['options'] as List) o as String],
        correct: (j['correct'] as num).toInt(),
        explanation: (j['explanation'] as String?) ?? '',
      );
}

class GuideMessage {
  GuideMessage({
    required this.role,
    required this.text,
    this.quiz,
    this.isError = false,
    this.animate = false,
  });

  final GuideRole role;
  final String text;
  final GuideQuiz? quiz;
  final bool isError;

  /// true = teks guide baru, ditampilkan kata demi kata.
  bool animate;

  /// Pilihan pengguna pada kartu soal (null = belum menjawab).
  int? picked;
}

class GuideException implements Exception {
  const GuideException(this.message, this.kind);

  final String message;
  final GuideErrorKind kind;

  @override
  String toString() => message;
}
