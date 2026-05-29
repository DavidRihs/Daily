import 'package:flutter/material.dart';
import '../models/attendee.dart';

class AttendeeListWidget extends StatefulWidget {
  final List<Attendee> attendees;
  final String? activeAttendeeId;
  final String? selectedAttendeeId;
  final bool notesEnabled;
  final bool isRunning;
  final ValueChanged<List<Attendee>> onAttendeesChanged;
  final ValueChanged<String>? onAttendeeTap;   // single tap → open note panel
  final ValueChanged<String>? onAttendeeJump;  // double tap → jump to (during run)

  const AttendeeListWidget({
    super.key,
    required this.attendees,
    required this.activeAttendeeId,
    this.selectedAttendeeId,
    required this.notesEnabled,
    required this.isRunning,
    required this.onAttendeesChanged,
    this.onAttendeeTap,
    this.onAttendeeJump,
  });

  @override
  State<AttendeeListWidget> createState() => _AttendeeListWidgetState();
}

class _AttendeeListWidgetState extends State<AttendeeListWidget> {
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _addAttendee(String name) {
    name = name.trim();
    if (name.isEmpty) return;
    final updated = List<Attendee>.from(widget.attendees)
      ..add(Attendee(name: name));
    widget.onAttendeesChanged(updated);
    _addController.clear();
    _addFocusNode.requestFocus();
  }

  void _removeAttendee(String id) {
    widget.onAttendeesChanged(
        widget.attendees.where((a) => a.id != id).toList());
  }

  void _toggleEnabled(String id, bool value) {
    widget.onAttendeesChanged(widget.attendees
        .map((a) => a.id == id ? a.copyWith(enabled: value) : a)
        .toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    final updated = List<Attendee>.from(widget.attendees);
    if (newIndex > oldIndex) newIndex -= 1;
    updated.insert(newIndex, updated.removeAt(oldIndex));
    widget.onAttendeesChanged(updated);
  }

  void _shuffle() {
    final enabled =
        widget.attendees.where((a) => a.enabled).toList()..shuffle();
    final disabled = widget.attendees.where((a) => !a.enabled).toList();
    widget.onAttendeesChanged([...enabled, ...disabled]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            focusNode: _addFocusNode,
            controller: _addController,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              suffixIcon: Icon(Icons.person_add,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              labelText: 'Add attendee',
            ),
            onSubmitted: _addAttendee,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              itemCount: widget.attendees.length,
              itemBuilder: (context, index) {
                final attendee = widget.attendees[index];
                final isActive = attendee.id == widget.activeAttendeeId;
                final isSelected = attendee.id == widget.selectedAttendeeId;

                // Tile background — using M3 tonal roles for automatic contrast
                final Color tileColor;
                final Color textColor;
                final Color iconColor;
                if (isActive || isSelected) {
                  tileColor = theme.colorScheme.primary;
                  textColor = theme.colorScheme.onPrimary;
                } else if (attendee.enabled) {
                  tileColor = theme.colorScheme.primaryContainer;
                  textColor = theme.colorScheme.onPrimaryContainer;
                } else {
                  tileColor = theme.colorScheme.surfaceContainerHigh;
                  textColor = theme.colorScheme.onSurface;
                }
                iconColor = textColor;

                return Dismissible(
                  key: Key(attendee.id),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    padding: const EdgeInsets.only(left: 16),
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeAttendee(attendee.id),
                  child: GestureDetector(
                    onTap: widget.notesEnabled
                        ? () => widget.onAttendeeTap?.call(attendee.id)
                        : null,
                    onDoubleTap: widget.isRunning
                        ? () => widget.onAttendeeJump?.call(attendee.id)
                        : null,
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                        tileColor: tileColor,
                        leading: Checkbox(
                          side: WidgetStateBorderSide.resolveWith((_) =>
                              BorderSide(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                  strokeAlign:
                                      BorderSide.strokeAlignOutside)),
                          fillColor:
                              const WidgetStatePropertyAll(Colors.white),
                          checkColor: Colors.black,
                          value: attendee.enabled,
                          onChanged: (v) =>
                              _toggleEnabled(attendee.id, v ?? true),
                        ),
                        title: Text(
                          attendee.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle,
                                    color: iconColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              onReorder: _reorder,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _shuffle,
              icon: const Icon(Icons.shuffle, size: 25),
              label: const Text('Randomize', style: TextStyle(fontSize: 25)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
