import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../services/storage_service.dart';
import '../widgets/meeting_edit_dialog.dart';
import '../widgets/meeting_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Meeting> _meetings = [];
  int _selectedIndex = 0;
  bool _loading = true;
  bool _serverError = false;

  // Drag-reorder state
  int? _draggingIndex;   // tab currently being dragged
  int? _dragOverIndex;  // tab currently hovered as a drop target

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _serverError = false; });
    final (meetings, ok) = await StorageService.loadMeetings();
    setState(() {
      _meetings = meetings;
      _selectedIndex = 0;
      _loading = false;
      _serverError = !ok;
    });
  }

  Future<void> _save() async {
    final ok = await StorageService.saveMeetings(_meetings);
    if (!ok && mounted) {
      setState(() => _serverError = true);
    } else {
      setState(() => _serverError = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<Meeting>(
      context: context,
      builder: (_) => const MeetingEditDialog(),
    );
    if (result == null) return;
    setState(() {
      _meetings.add(result);
      _selectedIndex = _meetings.length - 1;
    });
    await _save();
  }

  Future<void> _showEditDialog(int index) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => MeetingEditDialog(meeting: _meetings[index]),
    );
    if (result == null) return;
    if (result == 'delete') {
      setState(() {
        _meetings.removeAt(index);
        _selectedIndex = _selectedIndex.clamp(
            0, _meetings.isEmpty ? 0 : _meetings.length - 1);
      });
    } else if (result is Meeting) {
      setState(() => _meetings[index] = result);
    }
    await _save();
  }

  void _onMeetingUpdated(Meeting updated) {
    final idx = _meetings.indexWhere((m) => m.id == updated.id);
    if (idx == -1) return;
    setState(() => _meetings[idx] = updated);
    _save();
  }

  void _onTabReorder(int fromIndex, int toIndex) {
    setState(() {
      final m = _meetings.removeAt(fromIndex);
      _meetings.insert(toIndex, m);
      if (_selectedIndex == fromIndex) {
        _selectedIndex = toIndex;
      } else if (_selectedIndex > fromIndex && _selectedIndex <= toIndex) {
        _selectedIndex--;
      } else if (_selectedIndex < fromIndex && _selectedIndex >= toIndex) {
        _selectedIndex++;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          if (_serverError)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              content: const Text(
                  'Cannot reach server (http://localhost:8080). Start the Dart server and refresh.'),
              backgroundColor: Colors.red.shade900,
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          // Custom tab bar
          _buildTabBar(),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _meetings.isEmpty
                ? _buildEmpty()
                : MeetingScreen(
                    key: ValueKey(_meetings[_selectedIndex].id),
                    meeting: _meetings[_selectedIndex],
                    onMeetingUpdated: _onMeetingUpdated,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._meetings.asMap().entries.map((e) =>
                      _buildTab(e.key, e.value.name,
                          e.key == _selectedIndex)),
                ],
              ),
            ),
          ),
          // Add (+) button
          Tooltip(
            message: 'New meeting',
            child: InkWell(
              onTap: _showCreateDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: double.infinity,
                alignment: Alignment.center,
                child: Icon(Icons.add,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String name, bool isSelected) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDragging = _draggingIndex == index;
    final isDropTarget = _dragOverIndex == index && _draggingIndex != index;
    final anyDragging = _draggingIndex != null;

    final tabContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDropTarget
                ? cs.primary
                : isSelected
                    ? cs.primary
                    : Colors.transparent,
            width: isDropTarget ? 3 : 2,
          ),
          left: BorderSide(
            color: isDropTarget ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        color: isDropTarget
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : isDragging
                ? cs.surface.withValues(alpha: 0.3)
                : isSelected
                    ? cs.surface
                    : cs.surface.withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small drag hint icon — only visible when any drag is in progress
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: anyDragging ? 0.45 : 0.0,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.drag_indicator,
                  size: 14, color: cs.onSurface),
            ),
          ),
          Text(
            name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 14),
          // Hide edit button while dragging to keep things clean
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: anyDragging ? 0.0 : 1.0,
            child: Tooltip(
              message: 'Edit meeting',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: anyDragging ? null : () => _showEditDialog(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                  child: Icon(Icons.edit,
                      size: 14,
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.45)),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<int>(
      key: ValueKey(_meetings[index].id),
      data: index,
      onDragStarted: () => setState(() => _draggingIndex = index),
      onDragEnd: (_) => setState(() {
        _draggingIndex = null;
        _dragOverIndex = null;
      }),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              border: Border(
                bottom: BorderSide(color: cs.primary, width: 3),
              ),
              boxShadow: [
                BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                    fontSize: 15)),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: tabContent),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onMove: (_) => setState(() => _dragOverIndex = index),
        onLeave: (_) => setState(() {
          if (_dragOverIndex == index) _dragOverIndex = null;
        }),
        onAcceptWithDetails: (d) {
          setState(() {
            _draggingIndex = null;
            _dragOverIndex = null;
          });
          _onTabReorder(d.data, index);
        },
        builder: (ctx, candidate, _) => GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: tabContent,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined,
              size: 64,
              color: Colors.grey.shade600),
          const SizedBox(height: 16),
          const Text('No meetings yet',
              style: TextStyle(fontSize: 20, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create a meeting'),
          ),
        ],
      ),
    );
  }
}
