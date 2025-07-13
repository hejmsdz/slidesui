import 'package:flutter/material.dart';

class OverlayAppBar extends StatefulWidget {
  final bool isUiVisible;
  final List<Widget> actions;

  const OverlayAppBar(
      {super.key, required this.isUiVisible, required this.actions});

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
          foregroundColor: Colors.white54,
          actions: widget.actions,
        ),
      ),
    );
  }
}
