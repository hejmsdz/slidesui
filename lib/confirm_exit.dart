import 'package:flutter/material.dart';
import 'package:slidesui/strings.dart';

bool returnTrue() => true;

class ConfirmExit extends StatelessWidget {
  final Widget child;
  final String message;
  final bool Function() isActive;

  const ConfirmExit({
    super.key,
    required this.child,
    required this.message,
    this.isActive = returnTrue,
  });

  Future<bool?> _confirmExit(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings['confirmExitTitle']!),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text(strings['no']!),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              child: Text(strings['yes']!),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop =
              !isActive() || (await _confirmExit(context) ?? false);
          if (context.mounted && shouldPop) {
            Navigator.pop(context);
          }
        }
      },
      child: child,
    );
  }
}
