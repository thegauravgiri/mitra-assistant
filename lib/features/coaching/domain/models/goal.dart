enum GoalType { interruptions, monologue, questions, fillers, talkShare, pace }

class Goal {
  final GoalType type;
  final double target;

  const Goal(this.type, this.target);

  static double defaultTarget(GoalType t) {
    switch (t) {
      case GoalType.interruptions:
        return 1;
      case GoalType.monologue:
        return 60;
      case GoalType.questions:
        return 3;
      case GoalType.fillers:
        return 3;
      case GoalType.talkShare:
        return 15;
      case GoalType.pace:
        return 0; // uses the typical pace range
    }
  }

  static String label(GoalType t) {
    switch (t) {
      case GoalType.interruptions:
        return 'Interrupt less';
      case GoalType.monologue:
        return 'Keep stretches short';
      case GoalType.questions:
        return 'Ask more questions';
      case GoalType.fillers:
        return 'Fewer filler words';
      case GoalType.talkShare:
        return 'Balance talk share';
      case GoalType.pace:
        return 'Steady pace';
    }
  }

  String get description {
    switch (type) {
      case GoalType.interruptions:
        return 'Interrupt others at most ${target.toStringAsFixed(0)}x per meeting';
      case GoalType.monologue:
        return 'Keep your longest stretch under ${target.toStringAsFixed(0)} s';
      case GoalType.questions:
        return 'Ask at least ${target.toStringAsFixed(0)} questions per meeting';
      case GoalType.fillers:
        return 'Stay under ${target.toStringAsFixed(0)} filler words per minute';
      case GoalType.talkShare:
        return 'Stay within ${target.toStringAsFixed(0)} points of your fair share of talk time';
      case GoalType.pace:
        return 'Keep your pace in the typical range';
    }
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'target': target};

  static Goal? fromJson(Map<String, dynamic> json) {
    final type = GoalType.values.where((t) => t.name == json['type']);
    if (type.isEmpty) return null;
    return Goal(type.first, (json['target'] as num?)?.toDouble() ?? defaultTarget(type.first));
  }
}
