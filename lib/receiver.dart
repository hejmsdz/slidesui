import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eventflux/eventflux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/confirm_exit.dart';
import 'package:slidesui/overlay_app_bar.dart';
import 'package:slidesui/pdf_presentation.dart';
import 'package:slidesui/presentation.dart';
import 'package:slidesui/strings.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

bool hasAnyConnection(List<ConnectivityResult> results) {
  return results.any((conn) => conn != ConnectivityResult.none);
}

const int reconnectDelaySeconds = 5;

class PresentationReceiver extends StatefulWidget {
  const PresentationReceiver({super.key, required this.liveSessionKey});

  final String liveSessionKey;

  @override
  State<PresentationReceiver> createState() => _PresentationReceiverState();
}

class StartEvent {
  final String url;
  final int currentPage;

  StartEvent({required this.url, required this.currentPage});

  factory StartEvent.fromJson(Map<String, dynamic> json) {
    return StartEvent(url: json['url'], currentPage: json['currentPage']);
  }
}

class PageEvent {
  final int page;

  PageEvent({required this.page});

  factory PageEvent.fromJson(Map<String, dynamic> json) {
    return PageEvent(page: json['page']);
  }
}

class _PresentationReceiverState extends State<PresentationReceiver> {
  EventFluxData? data;
  String? pdfFilePath;
  PresentationController controller = PresentationController();
  bool _isUiVisible = true;
  bool _isConnecting = false;
  bool _didConnectAtLeastOnce = false;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  StreamSubscription<EventFluxData>? sseSubscription;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final isOnline = hasAnyConnection(results);

      if (!isOnline) {
        goToPage(0);
        if (!_isConnecting) {
          await disconnect();
        }
      } else if (_didConnectAtLeastOnce) {
        connect();
      }
    });

    connect();
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return hasAnyConnection(results);
  }

  Future<void> connect() async {
    if (_isConnecting) return;

    _isConnecting = true;
    await disconnect();

    EventFlux.instance.connect(
      EventFluxConnectionType.get,
      '${rootURL}v2/live/${widget.liveSessionKey}',
      onSuccessCallback: (response) async {
        if (!mounted) return;

        _isConnecting = false;
        _didConnectAtLeastOnce = true;
        sseSubscription = response?.stream?.listen(handleEvent);
      },
      onError: (error) async {
        if (!mounted) return;

        _isConnecting = false;

        if (!_didConnectAtLeastOnce) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "${strings['presentationReceiverError']!} ${error.message ?? "???"}"),
            ),
          );
          Navigator.of(context).pop();

          return;
        }

        goToPage(0);

        if (await isOnline()) {
          Timer(Duration(seconds: reconnectDelaySeconds), () {
            if (mounted) {
              connect();
            }
          });
        }
      },
      autoReconnect: false,
    );
  }

  void handleEvent(EventFluxData data) async {
    if (!mounted) return;

    switch (data.event) {
      case 'start':
        final startEvent = StartEvent.fromJson(jsonDecode(data.data));

        controller.setCurrentPage(startEvent.currentPage);
        await downloadPdf(startEvent.url);

        break;

      case 'changePage':
        final pageEvent = PageEvent.fromJson(jsonDecode(data.data));
        goToPage(pageEvent.page);
        break;
    }
  }

  void goToPage(int page) {
    setState(() {
      controller.setCurrentPage(page);
    });
  }

  Future<void> downloadPdf(String url) async {
    await disposePdf();

    final task = DownloadTask(url: url);
    await FileDownloader().download(task);

    final path = await task.filePath();
    setState(() {
      pdfFilePath = path;
    });
  }

  Future<void> disposePdf() async {
    if (pdfFilePath != null) {
      await File(pdfFilePath!).delete();
      pdfFilePath = null;
    }
  }

  void handleError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings['presentationReceiverError']!),
      ),
    );

    Navigator.of(context).pop();
  }

  Future<void> disconnect() async {
    await sseSubscription?.cancel();
    sseSubscription = null;

    await EventFlux.instance.disconnect();
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    disconnect();
    disposePdf();
    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.restoreSystemUIOverlays();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: pdfFilePath == null
          ? Container()
          : ConfirmExit(
              message: strings['confirmExit']!,
              child: Stack(
                children: [
                  PdfPresentation(
                    pdfPath: pdfFilePath!,
                    currentPage: controller.currentPage,
                  ),
                  ExternalDisplayBroadcaster(
                    controller: controller,
                    filePath: pdfFilePath!,
                  ),
                  GestureDetector(onDoubleTap: () {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
                    setState(() {
                      _isUiVisible = !_isUiVisible;
                    });
                  }),
                  OverlayAppBar(
                    isUiVisible: _isUiVisible,
                    actions: [],
                  ),
                ],
              )),
    );
  }
}
