enum Mood { great, good, neutral, low, rough }

class Thought {
  Thought({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.tags,
    required this.mood,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final List<String> tags;
  final Mood mood;

  static Mood moodFromString(String value) {
    return Mood.values.firstWhere(
      (m) => m.name == value,
      orElse: () => Mood.neutral,
    );
  }
}
