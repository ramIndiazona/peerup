class AICharacter {
  const AICharacter({
    required this.id,
    required this.name,
    required this.description,
    required this.personality,
    required this.difficulty,
    required this.scenario,
    required this.isPremium,
    this.avatar,
  });

  final String id;
  final String name;
  final String description;
  final String? avatar;
  final String personality;
  final String difficulty;
  final String scenario;
  final bool isPremium;

  factory AICharacter.fromJson(Map<String, dynamic> json) => AICharacter(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    avatar: json['avatar'] as String?,
    personality: json['personality'] as String? ?? '',
    difficulty: json['difficulty'] as String? ?? 'intermediate',
    scenario: json['scenario'] as String? ?? '',
    isPremium: json['isPremium'] == true,
  );
}

class AISession {
  const AISession({
    required this.id,
    required this.status,
    required this.startedAt,
    this.characterId,
    this.endedAt,
    this.transcript = const [],
    this.wordCount,
  });

  final String id;
  final String? characterId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<dynamic> transcript;
  final int? wordCount;

  factory AISession.fromJson(Map<String, dynamic> json) => AISession(
    id: json['id'] as String,
    characterId: json['characterId'] as String?,
    status: json['status'] as String? ?? 'ACTIVE',
    startedAt:
        DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
    endedAt:
        json['endedAt'] is String
            ? DateTime.tryParse(json['endedAt'] as String)
            : null,
    transcript: (json['transcript'] as List?) ?? const [],
    wordCount: (json['wordCount'] as num?)?.toInt(),
  );
}

class AIStartResult {
  const AIStartResult({required this.session, required this.resumed});

  final AISession session;
  final bool resumed;

  factory AIStartResult.fromJson(Map<String, dynamic> json) => AIStartResult(
    session: AISession.fromJson(
      ((json['session'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    resumed: json['resumed'] == true,
  );
}

class TranscriptLine {
  const TranscriptLine({required this.role, required this.content});

  final String role;
  final String content;

  factory TranscriptLine.fromJson(Map<String, dynamic> json) => TranscriptLine(
    role: json['role'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
  );
}
