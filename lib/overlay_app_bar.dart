import 'package:flutter/material.dart';

bool isLightBackground(Color? color) {
  if (color == null) {
    return false;
  }

  return color.computeLuminance() > 0.45;
}

class OverlayAppBar extends StatefulWidget {
  final bool isUiVisible;
  final List<Widget> actions;
  final bool isLightBackground;

  const OverlayAppBar(
      {super.key,
      required this.isUiVisible,
      required this.actions,
      this.isLightBackground = false});

  @override
  State<OverlayAppBar> createState() => _OverlayAppBarState();
}

class _OverlayAppBarState extends State<OverlayAppBar> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: Durations.medium1,
        opacity: widget.isUiVisible ? 1 : 0,
        child: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor:
              widget.isLightBackground ? Colors.black54 : Colors.white54,
          actions: widget.actions,
        ),
      ),
    );
  }
}
