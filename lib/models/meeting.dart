import 'package:uuid/uuid.dart';
import 'attendee.dart';
import 'meeting_session.dart';

const _uuid = Uuid();

class Meeting {
  final String id;
  final String name;
  final bool notesEnabled;
  final bool timeEnabled;
  final int timePerPerson; // seconds
  final List<Attendee> attendees;
  final MeetingSession? lastSession;

  Meeting({
    String? id,
    required this.name,
    this.notesEnabled = false,
    this.timeEnabled = true,
    this.timePerPerson = 40,
    List<Attendee>? attendees,
    this.lastSession,
  })  : id = id ?? _uuid.v4(),
        attendees = attendees ?? [];

  Meeting copyWith({
    String? name,
    bool? notesEnabled,
    bool? timeEnabled,
    int? timePerPerson,
    List<Attendee>? attendees,
    MeetingSession? lastSession,
    bool clearLastSession = false,
  }) =>
      Meeting(
        id: id,
        name: name ?? this.name,
        notesEnabled: notesEnabled ?? this.notesEnabled,
        timeEnabled: timeEnabled ?? this.timeEnabled,
        timePerPerson: timePerPerson ?? this.timePerPerson,
        attendees: attendees ?? this.attendees,
        lastSession:
            clearLastSession ? null : (lastSession ?? this.lastSession),
      );

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: json['id'] as String,
        name: json['name'] as String,
        notesEnabled: json['notesEnabled'] as bool? ?? false,
        timeEnabled: json['timeEnabled'] as bool? ?? true,
        timePerPerson: json['timePerPerson'] as int? ?? 40,
        attendees: (json['attendees'] as List<dynamic>?)
                ?.map((e) => Attendee.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastSession: json['lastSession'] != null
            ? MeetingSession.fromJson(
                json['lastSession'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notesEnabled': notesEnabled,
        'timeEnabled': timeEnabled,
        'timePerPerson': timePerPerson,
        'attendees': attendees.map((a) => a.toJson()).toList(),
        if (lastSession != null) 'lastSession': lastSession!.toJson(),
      };
}
