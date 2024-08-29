import 'package:daily_stemys/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svg/flutter_svg.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget(
      {super.key,
      required GlobalKey<RotatingWidgetState> rotatingWidgetKey,
      required FocusNode durationTextFieldFocusNode})
      : _rotatingWidgetKey = rotatingWidgetKey,
        _durationTextFieldFocusNode = durationTextFieldFocusNode;

  final GlobalKey<RotatingWidgetState> _rotatingWidgetKey;

  final FocusNode _durationTextFieldFocusNode;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  final TextEditingController _durationController =
      TextEditingController(text: defaultDuration.toString());

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(50),
        color: Colors.black54,
        child: Stack(
          alignment: const Alignment(1, 1),
          children: [
            SvgPicture.asset('assets/clock.svg', width: 2000, height: 2000),
            RotatingWidget(key: widget._rotatingWidgetKey),
            FloatingActionButton.large(
              onPressed: () {
                widget._rotatingWidgetKey.currentState?.toggleRotation();
                setState(() {});
              },
              child: Icon(
                  widget._rotatingWidgetKey.currentState?.isCurrentlyRotating ??
                          false
                      ? Icons.stop
                      : Icons.play_arrow),
            ),
            Container(
              width: 150,
              alignment: Alignment.topRight,
              child: TextField(
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                focusNode: widget._durationTextFieldFocusNode,
                controller: _durationController,
                decoration: const InputDecoration(
                  suffixText: 'sec',
                  labelText: 'Rotation duration',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onTap: () => _durationController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _durationController.value.text.length),
                onSubmitted: (value) => setRotationDuration(context),
                onTapOutside: (event) {
                  setRotationDuration(context);
                },
              ),
            )
          ],
        ));
  }

  void setRotationDuration(BuildContext context) {
    final int? duration = int.tryParse(_durationController.value.text);
    if (duration != null && duration > 0) {
      widget._rotatingWidgetKey.currentState?.setRotationDuration(duration);
    } else {
      String duration = widget._rotatingWidgetKey.currentState
              ?.getRotationDuration()
              ?.inSeconds
              .toString() ??
          defaultDuration.toString();

      _durationController.text = duration;
    }
    FocusScope.of(context).unfocus();
  }
}

class RotatingWidget extends StatefulWidget {
  const RotatingWidget({super.key});

  @override
  State<StatefulWidget> createState() => RotatingWidgetState();
}

class RotatingWidgetState extends State<RotatingWidget>
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
      child: SvgPicture.asset('assets/needles.svg', width: 2000, height: 2000),
    );
  }
}
