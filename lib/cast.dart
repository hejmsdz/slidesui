import 'dart:io';

import 'package:cast/cast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/cast_service.dart';
import 'package:slidesui/deck.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class CastDeviceDialog extends StatefulWidget {
  final CastService castService;
  final void Function(CastDevice) onDeviceSelected;

  const CastDeviceDialog({
    super.key,
    required this.castService,
    required this.onDeviceSelected,
  });

  @override
  State<CastDeviceDialog> createState() => _CastDeviceDialogState();
}

class _CastDeviceDialogState extends State<CastDeviceDialog> {
  List<CastDevice> _devices = [];
  bool _isSearching = true;
  bool _isSamsung = false;

  @override
  void initState() {
    super.initState();
    checkIsSamsung();
    searchDevices();
  }

  Future<void> checkIsSamsung() async {
    if (!Platform.isAndroid) {
      return;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final isSamsung =
        androidInfo.manufacturer.toLowerCase().contains('samsung');

    setState(() {
      _isSamsung = isSamsung;
    });
  }

  Future<void> searchDevices() async {
    setState(() {
      _isSearching = true;
    });
    final devices = await widget.castService.searchDevices();
    setState(() {
      _devices = devices;
      _isSearching = false;
    });
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildNoDevicesFound() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(strings['castNoDevicesFoundDescription1']!),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_isSamsung
                ? strings['castNoDevicesFoundDescription2Samsung']!
                : strings['castNoDevicesFoundDescription2']!),
          ),
          _buildSearchAgainButton(),
        ],
      ),
    );
  }

  Widget _buildSearchAgainButton() {
    return TextButton(
      onPressed: searchDevices,
      child: Text(strings['searchAgain']!),
    );
  }

  List<Widget> _buildDeviceList() {
    return [
      ..._devices.map((device) => SimpleDialogOption(
            onPressed: () => widget.onDeviceSelected(device),
            child: Text(
              device.name,
              overflow: TextOverflow.ellipsis,
            ),
          )),
      _buildSearchAgainButton(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasNoDevicesFound = !_isSearching && _devices.isEmpty;

    return SimpleDialog(
      title: Text(hasNoDevicesFound
          ? strings['castNoDevicesFound']!
          : strings['castSelectDevice']!),
      contentPadding: const EdgeInsets.all(16),
      children: _isSearching
          ? [_buildLoadingIndicator()]
          : hasNoDevicesFound
              ? [_buildNoDevicesFound()]
              : _buildDeviceList(),
    );
  }
}

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

  Future<CastDevice?> chooseDevice() async {
    return showDialog<CastDevice>(
      context: context,
      builder: (BuildContext context) {
        return CastDeviceDialog(
          castService: _castService!,
          onDeviceSelected: (device) {
            Navigator.pop(context, device);
          },
        );
      },
    );
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

  Future<void> startPresentation() async {
    final deckRequest = buildDeckRequestFromState(context.read<SlidesModel>());
    final deckResponse = await postDeck(deckRequest);
    _castService?.startPresentation(
        deckResponse.url, widget.controller.currentPage);
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
