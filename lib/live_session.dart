import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/presentation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:slidesui/state.dart';

class LiveSessionButton extends StatefulWidget {
  const LiveSessionButton({super.key, required this.controller});

  final PresentationController controller;

  @override
  State<LiveSessionButton> createState() => _LiveSessionButtonState();
}

class _LiveSessionButtonState extends State<LiveSessionButton> {
  bool _isConnected = false;

  void handleSlideChange() {
    http.post(apiURL(
        'v2/live/session/page', {'page': "${widget.controller.currentPage}"}));
  }

  Future<void> connectToDevice() async {
    final response = await http.put(
      apiURL('v2/live/session'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "deck": buildDeckRequestFromState(
                Provider.of<SlidesModel>(context, listen: false))
            .toJson(),
        "currentPage": widget.controller.currentPage
      }),
    );
    if (response.statusCode == 200 && mounted) {
      /*
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Live session started')));
          */
    }

    setState(() {
      _isConnected = true;
    });
    widget.controller.addListener(handleSlideChange);
  }

  disconnect() {
    // http.get(picastURL('close'));
    widget.controller.removeListener(handleSlideChange);
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon:
          Icon(_isConnected ? Icons.pause_presentation : Icons.present_to_all),
      tooltip: "Live session",
      onPressed: () async {
        if (_isConnected) {
          disconnect();
          return;
        }

        connectToDevice();
      },
    );
  }
}
