class MissionInfo {
  const MissionInfo({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.rewardCoins,
    required this.bestScore,
    required this.completed,
  });

  final int id;
  final String type; // trivia | kuliner_budaya | minigame
  final String title;
  final String description;
  final int rewardCoins;
  final int bestScore;
  final bool completed;

  bool get isRequired => type != 'minigame';

  factory MissionInfo.fromJson(Map<String, dynamic> j) => MissionInfo(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        rewardCoins: (j['reward_coins'] as num?)?.toInt() ?? 0,
        bestScore: (j['best_score'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as bool?) ?? false,
      );
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  final int id;
  final String text;
  final List<String> options;
  final int correct; // indeks 0..3
  final String explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: (j['id'] as num).toInt(),
        text: j['text'] as String,
        options: [for (final o in j['options'] as List) o as String],
        correct: (j['correct'] as num).toInt(),
        explanation: (j['explanation'] as String?) ?? '',
      );
}

class CultureCard {
  const CultureCard({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.fact,
  });

  final int id;
  final String title;
  final String category;
  final String icon;
  final String fact;

  factory CultureCard.fromJson(Map<String, dynamic> j) => CultureCard(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        category: j['category'] as String,
        icon: (j['icon'] as String?) ?? 'food',
        fact: j['fact'] as String,
      );
}

class MissionResult {
  const MissionResult({
    required this.passed,
    required this.score,
    required this.correct,
    required this.total,
    required this.coinsEarned,
    required this.coins,
    required this.firstCompletion,
    required this.countryCompleted,
    required this.countryScore,
    required this.unlocked,
  });

  final bool passed;
  final int score;
  final int correct;
  final int total;
  final int coinsEarned;
  final int coins; // total koin setelah misi
  final bool firstCompletion;
  final bool countryCompleted; // negara baru saja selesai
  final int countryScore;
  final List<String> unlocked; // kode negara yang baru terbuka

  factory MissionResult.fromJson(Map<String, dynamic> j) {
    final country = (j['country'] as Map?) ?? const {};
    return MissionResult(
      passed: (j['passed'] as bool?) ?? false,
      score: (j['score'] as num?)?.toInt() ?? 0,
      correct: (j['correct'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      coinsEarned: (j['coins_earned'] as num?)?.toInt() ?? 0,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      firstCompletion: (j['first_completion'] as bool?) ?? false,
      countryCompleted: (j['country_completed'] as bool?) ?? false,
      countryScore: (country['best_score'] as num?)?.toInt() ?? 0,
      unlocked: [for (final c in (j['unlocked'] as List?) ?? const []) c as String],
    );
  }
}

class MissionException implements Exception {
  const MissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
