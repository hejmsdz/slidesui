import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage(
      {super.key, required this.path, required this.title, this.onClose});

  final String path;
  final String title;
  final void Function(String?)? onClose;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool _isLoading = true;
  String? _url;

  @override
  void initState() {
    super.initState();

    final state = context.read<SlidesModel>();

    if (state.bootstrap == null) {
      Navigator.of(context).pop();
      return;
    }

    final teamId = state.currentTeam?.id ?? "";

    controller = WebViewController();

    controller
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (url) {
          if (Settings.containsKey('slides.fontSize') == true) {
            controller.runJavaScript(
                "localStorage.setItem('previewFontSize', '${Settings.getValue<double>('slides.fontSize')}')");
          }

          setState(() {
            _isLoading = false;
          });
        },
        onUrlChange: (event) {
          setState(() {
            _url = event.url;
          });
        },
      ))
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    postAuthNonce().then((nonce) async {
      controller
          .setUserAgent("${await controller.getUserAgent()} PsalltWebView");

      final uri =
          Uri.parse("${state.bootstrap!.frontendUrl}auth/nonce/callback")
              .replace(queryParameters: {
        'nonce': nonce.nonce,
        'teamId': teamId,
        'redirect': widget.path,
      });

      controller.loadRequest(uri);
    }).catchError((e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    widget.onClose?.call(_url);
    super.dispose();
  }

  Future<bool> hasUnsavedChanges() async {
    final result = await controller.runJavaScriptReturningResult(
        "window.dispatchEvent(new Event('beforeunload', { cancelable: true }));");
    return result.toString() == "false";
  }

  Future<bool?> _confirmExit() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings['confirmExitTitle']!),
          content: Text(strings['confirmExitUnsavedChanges']!),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, 1.0),
          child: Opacity(
            opacity: _isLoading ? 1 : 0,
            child: const LinearProgressIndicator(
              value: null,
            ),
          ),
        ),
      ),
      body: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            final shouldConfirm = await hasUnsavedChanges();

            if (shouldConfirm) {
              final confirmed = await _confirmExit();

              if (confirmed != true) {
                return;
              }
            }

            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: WebViewWidget(
          controller: controller,
        ),
      ),
    );
  }
}
