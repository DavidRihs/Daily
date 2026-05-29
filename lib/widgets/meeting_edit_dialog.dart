import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meeting.dart';

class MeetingEditDialog extends StatefulWidget {
  final Meeting? meeting;
  const MeetingEditDialog({super.key, this.meeting});

  @override
  State<MeetingEditDialog> createState() => _MeetingEditDialogState();
}

class _MeetingEditDialogState extends State<MeetingEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _timeController;
  late bool _notesEnabled;
  late bool _timeEnabled;

  bool get _isEditing => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _nameController = TextEditingController(text: m?.name ?? '');
    _timeController =
        TextEditingController(text: (m?.timePerPerson ?? 40).toString());
    _notesEnabled = m?.notesEnabled ?? false;
    _timeEnabled = m?.timeEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final time = int.tryParse(_timeController.text) ?? 40;
    final m = widget.meeting;
    Navigator.of(context).pop(Meeting(
      id: m?.id,
      name: name,
      notesEnabled: _notesEnabled,
      timeEnabled: _timeEnabled,
      timePerPerson: time.clamp(5, 3600),
      attendees: m?.attendees ?? [],
      lastSession: m?.lastSession,
    ));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Delete meeting?',
              style: TextStyle(color: cs.onSurface)),
          content: Text(
            'Delete "${widget.meeting!.name}"? This cannot be undone.',
            style: TextStyle(color: cs.onSurface),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(color: cs.onSurface))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (confirmed == true && mounted) Navigator.of(context).pop('delete');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text(
        _isEditing ? 'Edit meeting' : 'New meeting',
        style: TextStyle(color: onSurface),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                labelText: 'Meeting name',
                labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.75)),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Enable notes per person',
                  style: TextStyle(color: onSurface)),
              value: _notesEnabled,
              onChanged: (v) => setState(() => _notesEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Enable time per person',
                  style: TextStyle(color: onSurface)),
              value: _timeEnabled,
              onChanged: (v) => setState(() => _timeEnabled = v),
            ),
            if (_timeEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _timeController,
                style: TextStyle(color: onSurface),
                decoration: InputDecoration(
                  labelText: 'Seconds per person',
                  labelStyle:
                      TextStyle(color: onSurface.withValues(alpha: 0.75)),
                  suffixText: 'sec',
                  suffixStyle: TextStyle(color: onSurface.withValues(alpha: 0.6)),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            if (_isEditing)
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete meeting'),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: onSurface)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ],
    );
  }
}
