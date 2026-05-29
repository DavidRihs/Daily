import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/attendee.dart';
import '../models/meeting.dart';
import '../models/meeting_session.dart';
import '../services/storage_service.dart';
import 'attendee_list_widget.dart';

class MeetingScreen extends StatefulWidget {
  final Meeting meeting;
  final ValueChanged<Meeting> onMeetingUpdated;

  const MeetingScreen({
    super.key,
    required this.meeting,
    required this.onMeetingUpdated,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with TickerProviderStateMixin {
  late List<Attendee> _attendees;

  // Running state
  String? _activeAttendeeId;
  bool _isRunning = false;
  DateTime? _meetingStartTime;
  final Stopwatch _personStopwatch = Stopwatch();
  final Stopwatch _meetingStopwatch = Stopwatch();
  Timer? _ticker;

  // Clock animation (only when timeEnabled)
  AnimationController? _clockController;

  // Selected attendee for note display (always set when notesEnabled)
  String? _selectedAttendeeId;

  // Note editing state
  bool _editingNote = false;
  final TextEditingController _noteController = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _attendees = List.from(widget.meeting.attendees);
    _initClock();
    _initSelection();
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
  }

  void _initClock() {
    if (widget.meeting.timeEnabled) {
      _clockController = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.meeting.timePerPerson),
      );
    }
  }

  /// When notes are enabled, ensure there is always a selected attendee.
  void _initSelection() {
    if (widget.meeting.notesEnabled && _attendees.isNotEmpty) {
      _selectedAttendeeId = _attendees.first.id;
    }
  }

  @override
  void didUpdateWidget(MeetingScreen old) {
    super.didUpdateWidget(old);
    if (old.meeting.timeEnabled != widget.meeting.timeEnabled) {
      if (widget.meeting.timeEnabled) {
        _clockController ??= AnimationController(
          vsync: this,
          duration: Duration(seconds: widget.meeting.timePerPerson),
        );
      } else {
        _clockController?.dispose();
        _clockController = null;
      }
    }
    if (widget.meeting.timeEnabled &&
        _clockController != null &&
        old.meeting.timePerPerson != widget.meeting.timePerPerson) {
      _clockController!.duration =
          Duration(seconds: widget.meeting.timePerPerson);
    }
    if (!_isRunning) {
      _attendees = List.from(widget.meeting.attendees);
      _ensureSelection();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    _ticker?.cancel();
    _clockController?.dispose();
    _noteController.dispose();
    _meetingStopwatch.stop();
    _personStopwatch.stop();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Make sure _selectedAttendeeId is valid (or reset to first).
  void _ensureSelection() {
    if (!widget.meeting.notesEnabled) return;
    if (_attendees.isEmpty) { _selectedAttendeeId = null; return; }
    if (_selectedAttendeeId == null ||
        !_attendees.any((a) => a.id == _selectedAttendeeId)) {
      _selectedAttendeeId = _attendees.first.id;
    }
  }

  Attendee? get _activeAttendee => _activeAttendeeId == null
      ? null
      : _attendees.cast<Attendee?>().firstWhere(
            (a) => a?.id == _activeAttendeeId, orElse: () => null);

  Attendee? get _selectedAttendee => _selectedAttendeeId == null
      ? null
      : _attendees.cast<Attendee?>().firstWhere(
            (a) => a?.id == _selectedAttendeeId, orElse: () => null);

  int get _personElapsed => _personStopwatch.elapsed.inSeconds;
  bool get _isOvertime =>
      _isRunning && _personElapsed >= widget.meeting.timePerPerson;

  String _fmtCountdown() {
    final c = widget.meeting.timePerPerson - _personElapsed;
    final abs = c.abs();
    final m = abs ~/ 60;
    final s = abs % 60;
    final sign = c < 0 ? '+' : '';
    return m > 0
        ? '$sign${m}m ${s.toString().padLeft(2, '0')}s'
        : '$sign${s}s';
  }

  String _fmtEditedAt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Edited just now';
    if (diff.inMinutes < 60) return 'Edited ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Edited ${diff.inHours}h ago';
    String pad(int n) => n.toString().padLeft(2, '0');
    return 'Edited ${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }

  String _fmtMeetingTime() {
    final s = _meetingStopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  MarkdownStyleSheet get _mdStyle =>
      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 16, color: Colors.white),
        h1: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        h2: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        h3: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        listBullet: const TextStyle(fontSize: 16, color: Colors.white),
        code: TextStyle(
            fontSize: 14,
            backgroundColor: Colors.grey.shade800,
            color: Colors.greenAccent),
      );

  // ── Keyboard ───────────────────────────────────────────────────────────────

  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isNav = key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp;
    if (!isNav) return false;

    // Never hijack keys while a text field is focused
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context != null) {
      bool inTextField = false;
      focus!.context!.visitAncestorElements((el) {
        if (el.widget is EditableText) { inTextField = true; return false; }
        return true;
      });
      if (inTextField) return false;
    }

    if (!mounted || !_isRunning) return false;

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _advanceToNext();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _advanceToPrev();
      return true;
    }
    return false;
  }

  // ── Meeting control ────────────────────────────────────────────────────────

  Future<void> _startMeeting() async {
    // Cancel any unsaved note edit
    setState(() => _editingNote = false);

    // Reload latest data from server so notes are in sync before we begin
    final (allMeetings, _) = await StorageService.loadMeetings();
    if (!mounted) return;
    final fresh = allMeetings
        .cast<Meeting?>()
        .firstWhere((m) => m?.id == widget.meeting.id, orElse: () => null);
    if (fresh != null) {
      _attendees = List.from(fresh.attendees);
      _ensureSelection();
      // Propagate the fresh attendee list to the parent so it's not lost
      widget.onMeetingUpdated(widget.meeting.copyWith(attendees: _attendees));
    }

    // Set start time before _activatePerson, which may call _stopMeeting
    // immediately if no attendees are enabled.
    _meetingStartTime = DateTime.now();
    _meetingStopwatch.reset();
    _meetingStopwatch.start();
    setState(() {
      _isRunning = true;
      _activeAttendeeId = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    final first = _firstEnabledId();
    _activatePerson(first);
  }

  void _stopMeeting() {
    _ticker?.cancel();
    _ticker = null;
    _clockController?.stop();
    _clockController?.reset();
    _personStopwatch.stop();
    _meetingStopwatch.stop();

    final session = MeetingSession(
      startTime: _meetingStartTime!,
      endTime: DateTime.now(),
    );
    final updated =
        widget.meeting.copyWith(attendees: _attendees, lastSession: session);
    setState(() {
      _isRunning = false;
      _activeAttendeeId = null;
      // Keep _selectedAttendeeId so note panel stays visible after stop
    });
    widget.onMeetingUpdated(updated);
  }

  void _toggleMeeting() =>
      _isRunning ? _stopMeeting() : _startMeeting();

  // ── Person navigation ──────────────────────────────────────────────────────

  String? _firstEnabledId() {
    final e = _attendees.where((a) => a.enabled);
    return e.isEmpty ? null : e.first.id;
  }

  void _activatePerson(String? id) {
    if (id == null) { _stopMeeting(); return; }
    setState(() {
      _activeAttendeeId = id;
      // Note panel always follows the active person during a session
      if (widget.meeting.notesEnabled) _selectedAttendeeId = id;
    });
    _personStopwatch.reset();
    _personStopwatch.start();
    if (widget.meeting.timeEnabled && _clockController != null) {
      _clockController!.duration =
          Duration(seconds: widget.meeting.timePerPerson);
      _clockController!.reset();
      _clockController!.repeat();
    }
  }

  void _advanceToNext() {
    final enabled = _attendees.where((a) => a.enabled).toList();
    if (enabled.isEmpty) { _stopMeeting(); return; }
    if (_activeAttendeeId == null) { _activatePerson(enabled.first.id); return; }
    final idx = enabled.indexWhere((a) => a.id == _activeAttendeeId);
    // Last person → stop, do not loop
    if (idx == -1 || idx == enabled.length - 1) {
      _stopMeeting();
    } else {
      _activatePerson(enabled[idx + 1].id);
    }
  }

  void _advanceToPrev() {
    final enabled = _attendees.where((a) => a.enabled).toList();
    if (enabled.isEmpty) return;
    if (_activeAttendeeId == null) { _activatePerson(enabled.last.id); return; }
    final idx = enabled.indexWhere((a) => a.id == _activeAttendeeId);
    // Wraps around to the last person (intentional — going back from the first
    // person is not a session-ending action unlike going forward past the last).
    _activatePerson(idx <= 0 ? enabled.last.id : enabled[idx - 1].id);
  }

  void _jumpTo(String id) {
    if (!_isRunning) return;
    final idx = _attendees.indexWhere((a) => a.id == id);
    if (idx == -1 || !_attendees[idx].enabled) return;
    _activatePerson(id);
  }

  // ── Attendees ──────────────────────────────────────────────────────────────

  void _onAttendeesChanged(List<Attendee> updated) {
    setState(() {
      _attendees = updated;
      _ensureSelection();
    });
    widget.onMeetingUpdated(widget.meeting.copyWith(attendees: updated));
  }

  void _onAttendeeTap(String id) {
    if (!widget.meeting.notesEnabled) return;
    setState(() {
      _selectedAttendeeId = id;
      _editingNote = false;
    });
  }

  // ── Note editing ───────────────────────────────────────────────────────────

  void _startEditNote() {
    if (_selectedAttendee == null) return;
    _noteController.text = _selectedAttendee!.note;
    setState(() => _editingNote = true);
  }

  void _cancelEditNote() => setState(() => _editingNote = false);

  void _saveNote() {
    final note = _noteController.text;
    // Skip save if nothing changed — avoids spurious timestamp updates.
    if (note == _selectedAttendee?.note) {
      setState(() => _editingNote = false);
      return;
    }
    final now = DateTime.now();
    final updated = _attendees
        .map((a) => a.id == _selectedAttendeeId
            ? a.copyWith(note: note, noteEditedAt: now)
            : a)
        .toList();
    setState(() { _attendees = updated; _editingNote = false; });
    widget.onMeetingUpdated(widget.meeting.copyWith(attendees: updated));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildControlBar(),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                // Left panel — 75 % of width
                Expanded(flex: 3, child: _buildLeftPanel()),
                const VerticalDivider(width: 1),
                // Right panel — 25 % of width
                Expanded(flex: 1, child: _buildRightPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Control bar ────────────────────────────────────────────────────────────

  Widget _buildControlBar() {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.meeting.lastSession;
    final overtime = _isOvertime;
    const barHeight = 60.0;
    const textSize = 40.0;

    // Name shown: active person when running, selected person when stopped + notes
    final displayName = _isRunning
        ? (_activeAttendee?.name ?? '—')
        : (widget.meeting.notesEnabled
            ? (_selectedAttendee?.name ?? '—')
            : '—');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: barHeight,
      color: (_isRunning && widget.meeting.timeEnabled && overtime)
          ? scheme.errorContainer.withValues(alpha: 0.25)
          : scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Centered countdown (only when timeEnabled) ──
          if (widget.meeting.timeEnabled)
            Text(
              _isRunning ? _fmtCountdown() : '',
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w600,
                color: overtime ? scheme.error : scheme.primary
              ),
            ),
          // ── Left / right content row ──
          Row(
            children: [
              // Attendee name (left)
              Text(
                displayName,
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              // Session info / meeting timer (right, before buttons)
              if (_isRunning)
                Text(
                  _fmtMeetingTime(),
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      fontSize: textSize),
                )
              else if (session != null)
                Text(
                  'Last: ${session.formattedDate} — ${session.formattedDuration}',
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 25),
                ),
              const SizedBox(width: 12),
              if (_isRunning) ...[
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 40),
                  tooltip: 'Previous',
                  onPressed: _advanceToPrev,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 40),
                  tooltip: 'Next  (Space)',
                  onPressed: _advanceToNext,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.icon(
                onPressed: _toggleMeeting,
                icon:
                    Icon(_isRunning ? Icons.stop : Icons.play_arrow, size: 25),
                label: Text(_isRunning ? 'Stop' : 'Start',
                    style: const TextStyle(fontSize: 25)),
                style: _isRunning
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        minimumSize: const Size(0, 36))
                    : FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        minimumSize: const Size(0, 36)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Left panel ─────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    final m = widget.meeting;

    // Notes enabled → always show note panel (selected attendee, or first)
    if (m.notesEnabled) {
      if (_attendees.isEmpty) {
        return _buildStatusPanel('Add attendees to start');
      }
      final a = _selectedAttendee ?? _attendees.first;
      return _buildNotePanel(a);
    }

    // Time only → SVG clock
    if (m.timeEnabled && _clockController != null) {
      return _buildClockPanel();
    }

    // Nothing enabled
    return _buildStatusPanel(null);
  }

  // ── Clock panel ────────────────────────────────────────────────────────────

  Widget _buildClockPanel() {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(50.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset('assets/clock.svg', fit: BoxFit.contain),
          RotationTransition(
            turns: _clockController!,
            child: SvgPicture.asset('assets/needle.svg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  // ── Status panel ────────────────────────────────────────────────────────────

  Widget _buildStatusPanel(String? message) {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.meeting.lastSession;
    final text = message ??
        (session != null
            ? 'Last: ${session.formattedDate}\n${session.formattedDuration}'
            : 'Press Start to begin');
    return Container(
      color: scheme.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.4), fontSize: 15),
      ),
    );
  }

  // ── Note panel ─────────────────────────────────────────────────────────────

  Widget _buildNotePanel(Attendee attendee) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar: hidden during a running session
          if (!_isRunning)
            Container(
              color: scheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingNote) ...[
                    TextButton(
                      onPressed: _cancelEditNote,
                      child: Text('Cancel',
                          style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.7))),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _saveNote,
                      child: const Text('Save'),
                    ),
                  ] else
                    TextButton.icon(
                      onPressed: _startEditNote,
                      icon: const Icon(Icons.edit, size: 15),
                      label: const Text('Edit note'),
                      style: TextButton.styleFrom(
                          foregroundColor: scheme.primary),
                    ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _editingNote
                ? _buildNoteEditor()
                : _buildNoteViewer(attendee),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteEditor() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.tab) {
            final sel = _noteController.selection;
            if (!sel.isValid) return KeyEventResult.ignored;
            const indent = '  ';
            _noteController.value = TextEditingValue(
              text: _noteController.text.replaceRange(sel.start, sel.end, indent),
              selection: TextSelection.collapsed(offset: sel.start + indent.length),
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _noteController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          autofocus: true,
          style: TextStyle(color: scheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Write markdown notes here…',
            hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteViewer(Attendee attendee) {
    final scheme = Theme.of(context).colorScheme;
    if (attendee.note.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined,
                size: 40, color: scheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Text('No notes',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 14)),
          ],
        ),
      );
    }
    // FittedBox.contain scales DOWN if too tall, UP if there's spare room.
    // Fixed reference width lets FittedBox scale above container width.
    return Stack(
      children: [
        // Positioned.fill gives LayoutBuilder tight constraints so FittedBox
        // can scale the content UP when there is spare space, not just down.
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (ctx, constraints) => FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 560,
                  child: MarkdownBody(
                    data: attendee.note,
                    styleSheet: _mdStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (attendee.noteEditedAt != null)
          Positioned(
            bottom: 10,
            right: 10,
            child: Text(
              _fmtEditedAt(attendee.noteEditedAt!),
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }

  // ── Right panel ────────────────────────────────────────────────────────────

  Widget _buildRightPanel() => AttendeeListWidget(
        attendees: _attendees,
        activeAttendeeId: _activeAttendeeId,
        selectedAttendeeId:
            widget.meeting.notesEnabled ? _selectedAttendeeId : null,
        notesEnabled: widget.meeting.notesEnabled,
        isRunning: _isRunning,
        onAttendeesChanged: _onAttendeesChanged,
        // Selecting a different attendee is disabled during a session
        onAttendeeTap: _isRunning ? null : _onAttendeeTap,
        onAttendeeJump: _jumpTo,
      );
}
