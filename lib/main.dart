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
              fontSize: 25,
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

  // Focus management
  final FocusNode _focusNode = FocusNode();
  final FocusNode _durationTextFieldFocusNode = FocusNode();
  final FocusNode _attendeeTextFieldFocusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _durationTextFieldFocusNode.dispose();
    _attendeeTextFieldFocusNode.dispose();
    super.dispose();
  }

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
            _rotatingWidgetKey.currentState?.toggleRotation();
          }
        },
        child: Scaffold(
            body: SafeArea(
                child: Row(
          children: [
            Expanded(
                flex: 2,
                child: ClockWidget(
                    rotatingWidgetKey: _rotatingWidgetKey,
                    durationTextFieldFocusNode: _durationTextFieldFocusNode)),
            Expanded(
                flex: 1,
                child: AttendeesWidget(
                    attendeeTextFieldFocusNode: _attendeeTextFieldFocusNode))
          ],
        ))));
  }
}
