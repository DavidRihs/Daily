class MeetingSession {
  final DateTime startTime;
  final DateTime endTime;

  MeetingSession({required this.startTime, required this.endTime});

  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final s = duration.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    return '${m}m ${sec}s';
  }

  factory MeetingSession.fromJson(Map<String, dynamic> json) => MeetingSession(
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
      );

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      };
}
