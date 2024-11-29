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
  @override
  void initState() {
    super.initState();

    /*
    final state = Provider.of<SlidesModel>(context, listen: false);
    if (state.live != null) {
      connectToDevice();
    }
    */
  }

  void handleSlideChange() {
    final state = Provider.of<SlidesModel>(context, listen: false);
    if (state.isLivePaused || state.live == null) {
      return;
    }

    http.post(apiURL('v2/live/${state.live?.id}/page', {
      'page': "${widget.controller.currentPage}",
      'token': state.live?.token,
    }));
  }

  Future<void> connectToDevice() async {
    final state = Provider.of<SlidesModel>(context, listen: false);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final body = jsonEncode({
      "deck": buildDeckRequestFromState(state).toJson(),
      "currentPage": widget.controller.currentPage,
    });

    http.Response? response;
    if (state.live != null) {
      response = await http.put(
        apiURL('v2/live/${state.live?.id}', {'token': state.live?.token}),
        headers: headers,
        body: body,
      );
    }

    if (response == null || response.statusCode != 200) {
      response = await http.post(
        apiURL('v2/live'),
        headers: headers,
        body: body,
      );
    }

    if (response.statusCode != 200 || !mounted) {
      return;
    }

    final liveResponse = LiveResponse.fromJson(jsonDecode(response.body));
    Provider.of<SlidesModel>(context, listen: false)
        .setLiveSession(liveResponse);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(strings['liveSessionStarted']!
          .replaceFirst('{url}', liveResponse.url)),
      action: SnackBarAction(
          label: strings['shareLink']!,
          onPressed: () {
            Share.share(liveResponse.url);
          }),
    ));

    handleSlideChange();
    widget.controller.addListener(handleSlideChange);
  }

  disconnect() {
    widget.controller.removeListener(handleSlideChange);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlidesModel>(
      builder: (context, state, child) {
        final isConnected = state.live != null;
        final isPaused = state.isLivePaused;

        return IconButton(
          icon: Icon(!isConnected || isPaused
              ? Icons.present_to_all
              : Icons.pause_presentation),
          tooltip: strings['liveSession']!,
          onPressed: () async {
            if (isConnected) {
              state.setIsLivePaused(!isPaused);

              if (!state.isLivePaused) {
                handleSlideChange();
              }
            } else {
              connectToDevice();
            }
          },
        );
      },
    );
  }
}
