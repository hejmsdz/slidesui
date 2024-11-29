import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/presentation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class LiveSessionButton extends StatefulWidget {
  const LiveSessionButton({super.key, required this.controller});

  final PresentationController controller;

  @override
  State<LiveSessionButton> createState() => _LiveSessionButtonState();
}

class _LiveSessionButtonState extends State<LiveSessionButton> {
  bool _isConnected = false;
  bool _isPaused = false;
  String id = "";
  String token = "";

  void handleSlideChange() {
    if (_isPaused) {
      return;
    }

    http.post(apiURL('v2/live/$id/page', {
      'page': "${widget.controller.currentPage}",
      'token': token,
    }));
  }

  Future<void> connectToDevice() async {
    final response = await http.post(
      apiURL('v2/live'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "deck": buildDeckRequestFromState(
                Provider.of<SlidesModel>(context, listen: false))
            .toJson(),
        "currentPage": widget.controller.currentPage,
      }),
    );
    if (response.statusCode == 200 && mounted) {
      final liveResponse = LiveResponse.fromJson(jsonDecode(response.body));
      id = liveResponse.id;
      token = liveResponse.token;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(strings['liveSessionStarted']!
            .replaceFirst('{url}', liveResponse.url)),
        action: SnackBarAction(
            label: strings['shareLink']!,
            onPressed: () {
              Share.share(liveResponse.url);
            }),
      ));
    }

    setState(() {
      _isConnected = true;
    });
    widget.controller.addListener(handleSlideChange);
  }

  disconnect({bool shouldUpdateState = true}) {
    widget.controller.removeListener(handleSlideChange);
    if (shouldUpdateState) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    disconnect(shouldUpdateState: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon((_isConnected && !_isPaused)
          ? Icons.pause_presentation
          : Icons.present_to_all),
      tooltip: strings['liveSession']!,
      onPressed: () async {
        if (_isConnected) {
          setState(() {
            _isPaused = !_isPaused;
          });

          if (!_isPaused) {
            handleSlideChange();
          }
        } else {
          connectToDevice();
        }
      },
    );
  }
}
