import 'package:daily_stemys/attendees_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'clock_widget.dart';
import 'firebase_options.dart';

const int defaultDuration = 40;

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MaterialApp(
    title: 'Daily meeting',
    home: const MainWidget(),
    theme: ThemeData(
        elevatedButtonTheme: const ElevatedButtonThemeData(
            style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 20)),
                padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 20)))),
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow, brightness: Brightness.dark),
        useMaterial3: true,
        listTileTheme: const ListTileThemeData(
            minVerticalPadding: 0,
            titleTextStyle: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ))),
  ));
}

class MainWidget extends StatefulWidget {
  const MainWidget({super.key});

  @override
  State<MainWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> {
  final GlobalKey<RotatingWidgetState> _rotatingWidgetKey =
      GlobalKey<RotatingWidgetState>();

  final GlobalKey<AttendeesWidgetState> _attendeesWidgetKey =
      GlobalKey<AttendeesWidgetState>();

  // Focus management
  final FocusNode _focusNode = FocusNode();
  final FocusNode _durationTextFieldFocusNode = FocusNode();
  final FocusNode _attendeeTextFieldFocusNode = FocusNode();

  late AttendeesWidget _attendeesWidget;

  @override
  void initState() {
    super.initState();
    _attendeesWidget = AttendeesWidget(
        attendeeTextFieldFocusNode: _attendeeTextFieldFocusNode,
        key: _attendeesWidgetKey);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _durationTextFieldFocusNode.dispose();
    _attendeeTextFieldFocusNode.dispose();
    super.dispose();
  }

  void next() {}

  @override
  Widget build(BuildContext context) {
    if (!_attendeeTextFieldFocusNode.hasFocus) {
      FocusScope.of(context).requestFocus(_focusNode);
    }
    return KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space &&
              !_durationTextFieldFocusNode.hasFocus &&
              !_attendeeTextFieldFocusNode.hasFocus) {
            if (_rotatingWidgetKey.currentState?.isRotating ?? false) {
              if (_attendeesWidgetKey.currentState?.isLocked() ?? false) {
                _attendeesWidgetKey.currentState?.unlock();
                _rotatingWidgetKey.currentState?.resetRotation();
                if (!(_attendeesWidgetKey.currentState?.next() ?? true)) {
                  _rotatingWidgetKey.currentState?.stopRotation();
                }
              } else {
                _attendeesWidgetKey.currentState?.lock();
              }
            } else {
              _rotatingWidgetKey.currentState?.toggleRotation();
            }

            setState(() {});
          }
        },
        child: Scaffold(
            body: NotificationListener<Notification>(
                onNotification: (notification) {
                  if (notification is NextPersonNotification) {
                    if (!(_attendeesWidgetKey.currentState?.next() ?? true)) {
                      _rotatingWidgetKey.currentState?.stopRotation();
                    }
                  }
                  if (notification is ResetClockNotification) {
                    _rotatingWidgetKey.currentState?.resetRotation();
                  }
                  return true;
                },
                child: SafeArea(
                    child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: ClockWidget(
                            rotatingWidgetKey: _rotatingWidgetKey,
                            durationTextFieldFocusNode:
                                _durationTextFieldFocusNode)),
                    Expanded(flex: 1, child: _attendeesWidget)
                  ],
                )))));
  }
}
