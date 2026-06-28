class ProgressPhase {
  final String title;
  final String days;
  final List<ProgressItem> items;

  ProgressPhase(
      {required this.title, required this.days, required this.items});

  factory ProgressPhase.fromJson(Map<String, dynamic> json) {
    return ProgressPhase(
      title: json['title'] as String,
      days: json['days'] as String,
      items: (json['items'] as List)
          .map((i) => ProgressItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  int get completedCount => items.where((i) => i.completed).length;
}

class ProgressItem {
  final int index;
  final String text;
  bool completed;

  ProgressItem(
      {required this.index, required this.text, required this.completed});

  factory ProgressItem.fromJson(Map<String, dynamic> json) {
    return ProgressItem(
      index: json['index'] as int,
      text: json['text'] as String,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
