import 'dart:async';

import 'package:cast/cast.dart';
import 'package:flutter/material.dart';

const castAppId = 'AD7648A2';
const namespace = 'urn:x-cast:lt.psal.psallite';

class CastService extends ChangeNotifier {
  bool _isConnected = false;
  CastSession? _session;
  final StreamController<int> _pageChangesController = StreamController<int>();

  bool get isConnected => _isConnected;
  Stream<int> get pageChanges => _pageChangesController.stream;

  Future<List<CastDevice>> searchDevices() {
    return CastDiscoveryService().search();
  }

  Future<void> connectToDevice(CastDevice device) async {
    if (_isConnected && _session != null) {
      return;
    }

    final completer = Completer<void>();
    final session = await CastSessionManager().startSession(device);

    session.stateStream.listen((state) {
      if (state == CastSessionState.connected) {
        _isConnected = true;
        notifyListeners();
        completer.complete();
      } else if (state == CastSessionState.closed) {
        _isConnected = false;
        notifyListeners();
      }
    });

    session.messageStream.listen((message) {
      if (message.containsKey("page") && message["page"] is int) {
        _pageChangesController.add(message["page"]);
      }
    });

    session.sendMessage(CastSession.kNamespaceReceiver, {
      'type': 'LAUNCH',
      'appId': castAppId,
    });

    _session = session;

    return completer.future;
  }

  void startPresentation(String url, int currentPage) {
    _session!.sendMessage('$namespace.start', {
      'url': url,
      'currentPage': currentPage,
    });
  }

  void endPresentation() {
    if (isConnected) {
      requestSlideChange(0);
    }
  }

  void requestSlideChange(int page) {
    if (isConnected) {
      _session!.sendMessage('$namespace.changePage', {
        'page': page,
      });
    }
  }

  void disconnect() {
    _session?.close();
    _isConnected = false;
    notifyListeners();
  }
}
