import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Attendee {
  final String id;
  final String name;
  final bool enabled;
  final String note;
  final DateTime? noteEditedAt;

  Attendee({
    String? id,
    required this.name,
    this.enabled = true,
    this.note = '',
    this.noteEditedAt,
  }) : id = id ?? _uuid.v4();

  Attendee copyWith({
    String? name,
    bool? enabled,
    String? note,
    DateTime? noteEditedAt,
  }) =>
      Attendee(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        note: note ?? this.note,
        noteEditedAt: noteEditedAt ?? this.noteEditedAt,
      );

  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        note: json['note'] as String? ?? '',
        noteEditedAt: json['noteEditedAt'] == null
            ? null
            : DateTime.tryParse(json['noteEditedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'note': note,
        if (noteEditedAt != null) 'noteEditedAt': noteEditedAt!.toIso8601String(),
      };
}
