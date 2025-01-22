import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/state.dart';

class IfSpecialMode extends StatelessWidget {
  const IfSpecialMode({
    super.key,
    this.mode,
    this.modes,
    required this.child,
    this.elseChild,
  });

  final String? mode;
  final List<String>? modes;
  final Widget child;
  final Widget? elseChild;

  bool isEnabled(SlidesModel state) {
    if (mode != null) {
      return state.specialMode == mode;
    } else if (modes != null) {
      return modes!.contains(state.specialMode);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlidesModel>(builder: (context, state, _) {
      if (isEnabled(state)) {
        return child;
      }

      if (elseChild != null) {
        return elseChild!;
      }

      return SizedBox.shrink();
    });
  }
}
