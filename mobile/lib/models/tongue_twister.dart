
class TongueTwister {
  final String id;
  final String title;
  final String text;
  final String level;
  final int seconds;
  final int xp;
  final String color;
  final String icon;

  const TongueTwister({
    required this.id,
    required this.title,
    required this.text,
    required this.level,
    required this.seconds,
    required this.xp,
    required this.color,
    required this.icon,
  });

  factory TongueTwister.fromJson(Map<String, dynamic> json) {
    return TongueTwister(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      level: json['level']?.toString() ?? 'Beginner',
      seconds: (json['seconds'] as num?)?.toInt() ?? 60,
      xp: (json['xp'] as num?)?.toInt() ?? 10,
      color: json['color']?.toString() ?? '#625FE8',
      icon: json['icon']?.toString() ?? 'record_voice_over',
    );
  }
}
