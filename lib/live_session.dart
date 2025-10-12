import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/presentation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

bool acceptAnyStatus(int? status) => true;

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
      try {
        _live = LiveResponse.fromJson(jsonDecode(liveJson));
      } catch (e) {
        _live = null;
        prefs.remove('live.live');
      }
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

    try {
      await apiClient.post(
        'v2/live/${_live?.id}/page',
        params: {
          'page': "${page ?? widget.controller.currentPage}",
          'token': _live?.token,
        },
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isDeckSubmitted = false;

        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
            _live = null;
          }
        }
      });
      storeState();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(strings['liveSessionDisconnected']!),
          ));
      }
    }
  }

  Future<void> connect({bool isFirstConnection = false}) async {
    if (_isDeckSubmitted) {
      setState(() {
        _isConnected = true;
      });
      await broadcastSlideChange();
    } else {
      final state = Provider.of<SlidesModel>(context, listen: false);
      final body = {
        "deck": buildDeckRequestFromState(state).toJson(),
        "currentPage": widget.controller.currentPage,
      };

      Response? response;
      if (_live != null) {
        response = await apiClient.put(
          'v2/live/${_live?.id}',
          params: {'token': _live?.token},
          data: body,
          options: Options(validateStatus: acceptAnyStatus),
        );
      }

      if (response == null ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        response = await apiClient.post(
          'v2/live',
          data: body,
        );
      }

      if (!mounted) return;

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings['liveSessionStartError']!),
        ));

        return;
      }

      final liveResponse = LiveResponse.fromJson(response.data);
      setState(() {
        _live = liveResponse;
        _isConnected = true;
      });
      _isDeckSubmitted = true;
    }

    storeState();

    if (!mounted || _live == null) {
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
              final uri = Uri.parse(_live!.url);
              SharePlus.instance.share(ShareParams(
                uri: uri,
                sharePositionOrigin: Rect.fromLTWH(0, 0, 1, 1),
              ));
            }),
        duration: Duration(hours: 1),
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

    final tooltip = isConnected && _live != null
        ? strings['liveSessionActive']!.replaceFirst('{id}', _live!.id)
        : strings['liveSession']!;

    return IconButton(
      icon: Icon(isConnected
          ? Icons.stop_screen_share_outlined
          : Icons.screen_share_outlined),
      tooltip: tooltip,
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
