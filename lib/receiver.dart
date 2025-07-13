import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
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

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    EventFlux.instance.connect(
      EventFluxConnectionType.get,
      '${rootURL}v2/live/${widget.liveSessionKey}',
      onSuccessCallback: (response) {
        response?.stream?.listen(handleEvent);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings['presentationReceiverError']!),
          ),
        );
        Navigator.of(context).pop();
      },
      autoReconnect: true,
      reconnectConfig: ReconnectConfig(
        mode: ReconnectMode.linear,
      ),
    );
  }

  void handleEvent(EventFluxData data) async {
    switch (data.event) {
      case 'start':
        final startEvent = StartEvent.fromJson(jsonDecode(data.data));

        controller.setCurrentPage(startEvent.currentPage);
        await downloadPdf(startEvent.url);

        break;

      case 'changePage':
        final pageEvent = PageEvent.fromJson(jsonDecode(data.data));
        controller.setCurrentPage(pageEvent.page);
        setState(() {}); // to pass updated props to PdfPresentation
        break;
    }
  }

  Future<void> downloadPdf(String url) async {
    disposePdf();

    final task = DownloadTask(url: url);
    await FileDownloader().download(task);

    final path = await task.filePath();
    setState(() {
      pdfFilePath = path;
    });
  }

  void disposePdf() {
    if (pdfFilePath != null) {
      File(pdfFilePath!).delete();
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

  @override
  void dispose() {
    EventFlux.instance.disconnect();
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
