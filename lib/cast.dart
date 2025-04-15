import 'package:cast/cast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/cast_service.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

const castAppId = 'E34D7CD2';
const namespace = 'urn:x-cast:lt.psal.psallite';

class CastButton extends StatefulWidget {
  const CastButton({
    super.key,
    required this.controller,
    this.onStateChange,
  });

  final PresentationController controller;
  final void Function(String, bool)? onStateChange;

  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton> {
  CastService? _castService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final castService = context.read<CastService>();
    _castService ??= castService;

    castService.addListener(handleCastServiceChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleCastServiceChange(isInitial: true);
    });

    if (castService.isConnected) {
      startPresentation();
    }
  }

  @override
  initState() {
    super.initState();
  }

  void handleCastServiceChange({bool isInitial = false}) {
    final isConnected = _castService?.isConnected ?? false;
    widget.onStateChange?.call("cast", isConnected);

    if (!isInitial) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(isConnected
              ? strings['castConnected']!
              : strings['castDisconnected']!),
        ));
    }
  }

  List<Widget> buildDeviceDialogContent(
      AsyncSnapshot<List<CastDevice>> snapshot) {
    if (snapshot.hasError) {
      return [
        Center(
          child: Text(strings['castError']!
              .replaceFirst('{error}', snapshot.error.toString())),
        )
      ];
    }

    if (!snapshot.hasData) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        )
      ];
    }

    if (snapshot.data!.isEmpty) {
      return [
        Column(
          children: [
            Center(
              child: Text(strings['castNoDevicesFound']!),
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
          final devices = _castService!.searchDevices();

          return FutureBuilder(
              future: devices,
              builder: (context, snapshot) {
                return SimpleDialog(
                  title: Text(strings['castSelectDevice']!),
                  children: buildDeviceDialogContent(snapshot),
                );
              });
        });
  }

  showConnectionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(strings['castConnectionFailed']!),
        actions: [
          TextButton(
            child: Text(strings['ok']!),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  handleSlideChange() {
    _castService?.requestSlideChange(widget.controller.currentPage);
  }

  startPresentation() {
    final deck = buildDeckRequestFromState(context.read<SlidesModel>());
    _castService?.startPresentation(deck, widget.controller.currentPage);
    widget.controller.addListener(handleSlideChange);
  }

  endPresentation() {
    widget.controller.removeListener(handleSlideChange);
    _castService?.endPresentation();
  }

  Future<void> confirmDisconnect() async {
    final isConfirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(strings['castDisconnect']!),
              content: Text(strings['castDisconnectMessage']!),
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
        ) ??
        false;

    if (isConfirmed) {
      _castService?.disconnect();
    }
  }

  @override
  void dispose() {
    _castService?.removeListener(handleCastServiceChange);
    endPresentation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CastService>(builder: (context, cast, child) {
      final isConnected = cast.isConnected;
      return IconButton(
        icon: Icon(isConnected ? Icons.cast_connected : Icons.cast),
        tooltip: strings['cast']!,
        onPressed: () async {
          if (isConnected) {
            confirmDisconnect();
            return;
          }

          final device = await chooseDevice();
          if (device != null) {
            try {
              await cast.connectToDevice(device);
              startPresentation();
            } catch (e) {
              print(e);
              showConnectionErrorDialog();
            }
          }
        },
      );
    });
  }
}
