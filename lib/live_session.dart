import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/presentation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class LiveSessionButton extends StatefulWidget {
  const LiveSessionButton({
    super.key,
    required this.controller,
    this.onStateChange,
  });

  final PresentationController controller;
  final void Function(String, bool)? onStateChange;

  @override
  State<LiveSessionButton> createState() => _LiveSessionButtonState();
}

class _LiveSessionButtonState extends State<LiveSessionButton> {
  bool _isDeckSubmitted = false;
  LiveResponse? _live;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(broadcastSlideChange);

    loadState().then((_) {
      if (_live != null && _isConnected) {
        connect();
      }
    });
  }

  Future<void> loadState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final liveJson = prefs.getString('live.live');
    if (liveJson != null) {
      _live = LiveResponse.fromJson(jsonDecode(liveJson));
    }
    _isConnected = prefs.getBool('live.isConnected') ?? false;
  }

  storeState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('live.isConnected', _isConnected);
    prefs.setString('live.live', jsonEncode(_live));

    widget.onStateChange?.call('liveSession', _isConnected && _live != null);
  }

  Future<void> broadcastSlideChange({int? page}) async {
    if (!_isConnected || _live == null) {
      return;
    }

    await http.post(apiURL('v2/live/${_live?.id}/page', {
      'page': "${page ?? widget.controller.currentPage}",
      'token': _live?.token,
    }));
  }

  Future<void> connect({bool isFirstConnection = false}) async {
    if (_isDeckSubmitted) {
      setState(() {
        _isConnected = true;
      });
      await broadcastSlideChange();
    } else {
      final state = Provider.of<SlidesModel>(context, listen: false);
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      };
      final body = jsonEncode({
        "deck": buildDeckRequestFromState(state).toJson(),
        "currentPage": widget.controller.currentPage,
      });

      http.Response? response;
      if (_live != null) {
        response = await http.put(
          apiURL('v2/live/${_live?.id}', {'token': _live?.token}),
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
      setState(() {
        _live = liveResponse;
        _isConnected = true;
      });
      _isDeckSubmitted = true;
    }

    storeState();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            strings['liveSessionStarted']!.replaceFirst('{url}', _live!.url)),
        action: SnackBarAction(
            label: strings['shareLink']!,
            onPressed: () {
              Share.share(_live!.url);
            }),
      ));
  }

  Future<void> disconnect() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await broadcastSlideChange(page: 0);
    setState(() {
      _isConnected = false;
    });
    storeState();
  }

  @override
  void dispose() async {
    broadcastSlideChange(page: 0);
    widget.controller.removeListener(broadcastSlideChange);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _isConnected && _live != null;

    return IconButton(
      icon: Icon(isConnected
          ? Icons.stop_screen_share_outlined
          : Icons.screen_share_outlined),
      tooltip: strings['liveSession']!,
      onPressed: () async {
        if (isConnected) {
          disconnect();
        } else {
          connect();
        }
      },
    );
  }
}
