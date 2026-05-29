import 'dart:async';
import 'dart:js_interop';
import 'dart:math' show pi, cos, sin;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/attendee.dart';
import '../models/meeting.dart';
import '../models/meeting_session.dart';
import '../services/storage_service.dart';
import 'attendee_list_widget.dart';

// Thin wrapper around the browser's Date object so we can call
// toLocaleDateString / toLocaleTimeString with no explicit locale — the
// browser then uses the OS regional settings (e.g. 29.05.2026 on Windows
// even when the browser UI language is English).
@JS('Date')
extension type _JsDate._(JSObject _) implements JSObject {
  external factory _JsDate(double millisecondsSinceEpoch);
  external JSString toLocaleDateString();
  external JSString toLocaleTimeString(JSArray<JSString> locales, JSObject options);
}

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
    with SingleTickerProviderStateMixin {
  late List<Attendee> _attendees;

  // Running state
  String? _activeAttendeeId;
  bool _isRunning = false;
  DateTime? _meetingStartTime;
  final Stopwatch _meetingStopwatch = Stopwatch(); // for the meeting-total timer in the control bar
  Timer? _ticker;

  // Per-person countdown controller — drives the ring dot at 60 fps.
  // Two AnimatedBuilders (countdown text + ring painter) both listen to this
  // controller. Flutter notifies all listeners synchronously on the same tick,
  // so both widgets always read the same .value — desync is impossible.
  AnimationController? _countdownController;
  bool _overtime = false;
  DateTime? _overtimeStart; // set at the exact moment the countdown completes

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
    _initSelection();
    if (widget.meeting.timeEnabled) _initCountdown();
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
  }

  void _initCountdown() {
    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.meeting.timePerPerson),
    )
      // Permanent listener — fires when the countdown finishes.
      // No setState needed: AnimatedBuilder is already running at 60 fps and
      // will pick up the new _overtime/_overtimeStart on the very next frame,
      // avoiding the freeze that a full setState rebuild would cause.
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && _isRunning) {
          _overtime = true;
          _overtimeStart = DateTime.now();
          _countdownController?.repeat();
        }
      });
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
        _initCountdown();
      } else {
        _countdownController?.dispose();
        _countdownController = null;
      }
    } else if (widget.meeting.timeEnabled &&
        old.meeting.timePerPerson != widget.meeting.timePerPerson &&
        !_isRunning) {
      _countdownController?.duration =
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
    _countdownController?.dispose();
    _noteController.dispose();
    _meetingStopwatch.stop();
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

  // Elapsed seconds — read from the controller so text and dot share the
  // same value when they are in the same AnimatedBuilder pass.
  int get _personElapsed {
    if (_overtime) return widget.meeting.timePerPerson;
    final ctrl = _countdownController;
    if (ctrl == null) return 0;
    return (ctrl.value * widget.meeting.timePerPerson).floor();
  }

  bool get _isOvertime => _isRunning && _overtime;

  String _fmtCountdown() {
    if (_overtime && _overtimeStart != null) {
      // _overtimeStart is stamped at the exact completion frame so "+0s"
      // appears in the same build pass as the dot reaching 12 o'clock.
      final over = DateTime.now().difference(_overtimeStart!).inSeconds;
      final m = over ~/ 60;
      final s = over % 60;
      return m > 0 ? '+${m}m ${s.toString().padLeft(2, '0')}s' : '+${s}s';
    }
    final remaining = widget.meeting.timePerPerson - _personElapsed;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  String _fmtDateTime(DateTime dt) {
    final d = _JsDate(dt.millisecondsSinceEpoch.toDouble());
    final date = d.toLocaleDateString().toDart;
    final time = d.toLocaleTimeString(
      <JSString>[].toJS, // empty array → use OS regional locale
      {'hour': '2-digit', 'minute': '2-digit'}.jsify()! as JSObject,
    ).toDart;
    return '$date $time';
  }

  String _fmtEditedAt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Edited just now';
    if (diff.inMinutes < 60) return 'Edited ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Edited ${diff.inHours}h ago';
    return 'Edited ${_fmtDateTime(dt)}';
  }

  String _fmtMeetingTime() {
    final s = _meetingStopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  MarkdownStyleSheet get _mdStyle =>
      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 20, color: Colors.white),
        h1: const TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
        h2: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        h3: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        listBullet: const TextStyle(fontSize: 20, color: Colors.white),
        code: TextStyle(
            fontSize: 18,
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
      if (!mounted) return;
      // When the countdown AnimatedBuilder is running at 60 fps it already
      // drives all redraws; calling setState here would cause a conflicting
      // extra rebuild every second, creating the visible stutter.
      if (_countdownController?.isAnimating ?? false) return;
      setState(() {});
    });
    final first = _firstEnabledId();
    _activatePerson(first);
  }

  void _stopMeeting() {
    _ticker?.cancel();
    _ticker = null;
    _countdownController?.reset(); // sends dot back to 12 o'clock
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
    _overtime = false;
    _overtimeStart = null;
    if (widget.meeting.timeEnabled && _countdownController != null) {
      _countdownController!.duration =
          Duration(seconds: widget.meeting.timePerPerson);
      // forward(from: 0) resets AND starts in one call — both the arc and
      // the text read controller.value so they are always in sync.
      _countdownController!.forward(from: 0);
    }
    setState(() {
      _activeAttendeeId = id;
      if (widget.meeting.notesEnabled) _selectedAttendeeId = id;
    });
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
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          children: [
            _buildControlBar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 3, child: _buildLeftPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 1, child: _buildRightPanel()),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Control bar ────────────────────────────────────────────────────────────

  Widget _buildControlBar() {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.meeting.lastSession;
    const barHeight = 60.0;
    const textSize = 40.0;

    // Name shown: active person when running, selected person when stopped + notes
    final displayName = _isRunning
        ? (_activeAttendee?.name ?? '')
        : (widget.meeting.notesEnabled
            ? (_selectedAttendee?.name ?? '')
            : '');

    return Container(
      height: barHeight,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Centered countdown (only when timeEnabled) ──
          // Two AnimatedBuilders on the same controller are notified in the
          // same frame → the text here and the ring dot in _buildClockPanel
          // always read the same value and can never be out of sync.
          if (widget.meeting.timeEnabled && _countdownController != null)
            AnimatedBuilder(
              animation: _countdownController!,
              builder: (_, __) => Text(
                _isRunning ? _fmtCountdown() : '',
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w600,
                  color: _isOvertime ? scheme.error : scheme.primary,
                ),
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
                // Same controller as the countdown text — notified in the
                // same frame, so this stays in sync without extra setState.
                _countdownController != null
                  ? AnimatedBuilder(
                      animation: _countdownController!,
                      builder: (_, __) => Text(
                        _fmtMeetingTime(),
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.55),
                            fontSize: textSize),
                      ),
                    )
                  : Text(
                      _fmtMeetingTime(),
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: textSize),
                    )
              else if (session != null)
                Text(
                  'Last: ${_fmtDateTime(session.startTime)} — ${session.formattedDuration}',
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
                  color: scheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 40),
                  tooltip: 'Next  (Space)',
                  onPressed: _advanceToNext,
                  color: scheme.primary,
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

    // Time only → arc clock
    if (m.timeEnabled) {
      return _buildClockPanel();
    }

    // Nothing enabled
    return _buildStatusPanel(null);
  }

  // ── Clock panel ────────────────────────────────────────────────────────────

  Widget _buildClockPanel() {
    final scheme = Theme.of(context).colorScheme;
    if (_countdownController == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: scheme.surfaceContainerLow,
      child: AnimatedBuilder(
        animation: _countdownController!,
        builder: (_, __) => CustomPaint(
          painter: _RingClockPainter(
            progress: _countdownController!.value,
            dotColor: _isOvertime ? scheme.error : scheme.primary,
            ringColor: scheme.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ── Status panel ────────────────────────────────────────────────────────────

  Widget _buildStatusPanel(String? message) {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.meeting.lastSession;
    final text = message ??
        (session != null
            ? 'Last: ${_fmtDateTime(session.startTime)}\n${session.formattedDuration}'
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
      child: Stack(
        children: [
          Positioned.fill(
            child: _editingNote
                ? _buildNoteEditor()
                : _buildNoteViewer(attendee),
          ),
          // Edit button — plain, no tray, anchored to the note panel
          if (!_isRunning && !_editingNote)
            Positioned(
              top: 10,
              right: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: FilledButton.tonalIcon(
                  onPressed: _startEditNote,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteEditor() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Button row — sits above the text field, no overlap at all
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton(
                  onPressed: _cancelEditNote,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.85),
                    side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.4)),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: FilledButton(
                  onPressed: _saveNote,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
        // Text field fills the rest
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  final sel = _noteController.selection;
                  if (!sel.isValid) return KeyEventResult.ignored;
                  const indent = '  ';
                  _noteController.value = TextEditingValue(
                    text: _noteController.text
                        .replaceRange(sel.start, sel.end, indent),
                    selection: TextSelection.collapsed(
                        offset: sel.start + indent.length),
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
                style: TextStyle(color: scheme.onSurface, fontSize: 18),
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
          ),
        ),
      ],
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
                size: 40, color: scheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text('No notes',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
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

// ── Ring clock painter ─────────────────────────────────────────────────────
// White ring with a single dot indicator that travels counterclockwise.
// progress 0.0 → dot at 12 o'clock; progress 1.0 → dot back at 12 o'clock.

class _RingClockPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 from AnimationController.value
  final Color dotColor;
  final Color ringColor;

  _RingClockPainter({
    required this.progress,
    required this.dotColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.38;
    final ringStroke = size.shortestSide * 0.04;
    final dotRadius = size.shortestSide * 0.04;

    // Ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke,
    );

    // Dot travels counterclockwise starting at 12 o'clock (−π/2).
    final angle = -pi / 2 - progress * 2 * pi;
    final dotCenter = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    // Fixed dot at 12 o'clock
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius),
      dotRadius * 1.5,
      Paint()..color = ringColor,
    );

    // Solid dot
    canvas.drawCircle(dotCenter, dotRadius, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_RingClockPainter old) =>
      old.progress != progress || old.dotColor != dotColor;
}

