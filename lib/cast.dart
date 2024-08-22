import 'dart:convert';

import 'package:cast/cast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/state.dart';

const castAppId = 'E34D7CD2';
const namespace = 'urn:x-cast:com.mrozwadowski.slidesui';

class CastButton extends StatefulWidget {
  const CastButton({super.key, required this.controller});

  final PresentationController controller;

  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton> {
  bool _isConnected = false;
  CastSession? _session;

  List<Widget> buildDeviceDialogContent(
      AsyncSnapshot<List<CastDevice>> snapshot) {
    if (snapshot.hasError) {
      return [
        Center(
          child: Text(
            'Error: ${snapshot.error.toString()}',
          ),
        )
      ];
    }

    if (!snapshot.hasData) {
      return [
        const Center(
          child: CircularProgressIndicator(),
        )
      ];
    }

    if (snapshot.data!.isEmpty) {
      return [
        const Column(
          children: [
            Center(
              child: Text('No Chromecast devices found.'),
            ),
          ],
        )
      ];
    }

    return snapshot.requireData
        .map((device) => SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, device);
              },
              child: Text(device.name),
            ))
        .toList();
  }

  Future<CastDevice?> chooseDevice() async {
    return showDialog<CastDevice>(
        context: context,
        builder: (BuildContext context) {
          final devices = CastDiscoveryService().search();

          return FutureBuilder(
              future: devices,
              builder: (context, snapshot) {
                return SimpleDialog(
                  title: const Text('Select receiver device'),
                  children: buildDeviceDialogContent(snapshot),
                );
              });
        });
  }

  Future<void> connectToDevice(CastDevice device) async {
    final session = await CastSessionManager().startSession(device);

    void handleSlideChange() {
      session.sendMessage('$namespace.changePage', {
        'page': widget.controller.currentPage,
      });
    }

    session.stateStream.listen((state) {
      if (state == CastSessionState.connected) {
        session.sendMessage('$namespace.start', {
          'deckArgs': buildDeckRequestFromState(
                  Provider.of<SlidesModel>(context, listen: false))
              .toJson(),
          'currentPage': widget.controller.currentPage,
        });

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to remote display')));
        setState(() {
          _isConnected = true;
        });
        _session = session;
        widget.controller.addListener(handleSlideChange);
      } else if (state == CastSessionState.closed) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Remote display disconnected')));
        setState(() {
          _isConnected = false;
        });
        _session = null;
        widget.controller.removeListener(handleSlideChange);
      }
    });

    session.messageStream.listen((message) {
      print('received message: $message');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$message")));
      if (message['namespace'] == '$namespace.changePage') {
        Map<String, dynamic> data = jsonDecode(message['data']);
        int page = data['page'];
        print('going to page: $page');
        widget.controller.setCurrentPage(page);
      }
    });

    session.sendMessage(CastSession.kNamespaceReceiver, {
      'type': 'LAUNCH',
      'appId': castAppId,
    });
  }

  disconnect() {
    _session?.close();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isConnected ? Icons.cast_connected : Icons.cast),
      tooltip: "Cast",
      onPressed: () async {
        if (_isConnected) {
          disconnect();
          return;
        }

        final device = await chooseDevice();
        if (device != null) {
          connectToDevice(device);
        }
      },
    );
  }
}
