import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const int defaultDuration = 40;

void main() {
  runApp(const MaterialApp(
    title: 'Daily meeting',
    home: NamesListScreen(),
  ));
}

class NamesListScreen extends StatefulWidget {
  const NamesListScreen({super.key});

  @override
  State<NamesListScreen> createState() => _NamesListScreenState();
}

class _NamesListScreenState extends State<NamesListScreen> {
  final List<String> _names = ["test"]; // List to hold names

  void _addName(String name) {
    setState(() {
      _names.add(name);
    });
  }

  void _editName(int index, String newName) {
    setState(() {
      _names[index] = newName;
    });
  }

  void _deleteName(int index) {
    setState(() {
      _names.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Names List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _names.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_names[index]),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(index),
            ),
            onLongPress: () => _deleteName(index),
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    final TextEditingController _nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Name'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Enter name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_nameController.text.isNotEmpty) {
                  _addName(_nameController.text);
                }
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(int index) {
    final TextEditingController _nameController =
        TextEditingController(text: _names[index]);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_nameController.text.isNotEmpty) {
                  _editName(index, _nameController.text);
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class MainWidget extends StatefulWidget {
  const MainWidget({super.key});

  @override
  State<MainWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> {
  final GlobalKey<_RotatingWidgetState> _rotatingWidgetKey =
      GlobalKey<_RotatingWidgetState>();
  final TextEditingController _durationController =
      TextEditingController(text: defaultDuration.toString());

  final FocusNode _focusNode = FocusNode();
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    return KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space &&
              !_textFieldFocusNode.hasFocus) {
            _rotatingWidgetKey.currentState?.toggleRotation();
          }
        },
        child: Scaffold(
            body: SafeArea(
                child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black87,
                  child: Stack(
                    alignment: const Alignment(1, 1),
                    children: [
                      SvgPicture.asset('assets/clock.svg',
                          width: 1500, height: 1500),
                      RotatingWidget(key: _rotatingWidgetKey),
                      FloatingActionButton(
                        onPressed: () {
                          _rotatingWidgetKey.currentState?.toggleRotation();
                          setState(() {});
                        },
                        child: Icon(_rotatingWidgetKey
                                    .currentState?.isCurrentlyRotating ??
                                false
                            ? Icons.stop
                            : Icons.play_arrow),
                      )
                    ],
                  )),
            ),
            Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.green,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _rotatingWidgetKey.currentState?.resetRotation();
                        },
                        child: const Text('Reset Rotation'),
                      ),
                      TextField(
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        focusNode: _textFieldFocusNode,
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Rotation Duration (seconds)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onTap: () => _durationController.selection =
                            TextSelection(
                                baseOffset: 0,
                                extentOffset:
                                    _durationController.value.text.length),
                        onTapOutside: (event) {
                          final int? duration =
                              int.tryParse(_durationController.value.text);
                          if (duration != null && duration > 0) {
                            _rotatingWidgetKey.currentState
                                ?.setRotationDuration(duration);
                          } else {
                            String duration = _rotatingWidgetKey.currentState
                                    ?.getRotationDuration()
                                    ?.inSeconds
                                    .toString() ??
                                defaultDuration.toString();

                            _durationController.text = duration;
                          }
                          FocusScope.of(context).unfocus();
                        },
                      )
                    ],
                  ),
                ))
          ],
        ))));
  }
}

class RotatingWidget extends StatefulWidget {
  const RotatingWidget({super.key});

  @override
  State<StatefulWidget> createState() => _RotatingWidgetState();
}

class _RotatingWidgetState extends State<RotatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool isRotating = false;

  bool get isCurrentlyRotating => isRotating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: defaultDuration),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleRotation() {
    setState(() {
      if (isRotating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
      isRotating = !isRotating;
    });
  }

  void resetRotation() {
    setState(() {
      _controller.reset();
      isRotating = false;
    });
  }

  Duration? getRotationDuration() => _controller.duration;

  void setRotationDuration(int seconds) {
    setState(() {
      _controller.duration = Duration(seconds: seconds);
      _controller.reset();
      if (isRotating) {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SvgPicture.asset('assets/needles.svg', width: 1500, height: 1500),
    );
  }
}
