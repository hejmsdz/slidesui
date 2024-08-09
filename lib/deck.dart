import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:slidesui/model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './state.dart';
import './strings.dart';
import './api.dart';

Future<String> moveFile(String source) async {
  const platform = MethodChannel("com.mrozwadowski.slidesui/filePicker");
  try {
    return await platform.invokeMethod("moveFile", {
      "source": source,
    });
  } on PlatformException catch (_) {
    return "";
  }
}

Future<void> notifyOnDownloaded(
  BuildContext context,
  String destinationFile,
) async {
  final moveTarget = await moveFile(destinationFile);
  if (moveTarget != "") {
    notifyOnMoved(context);
  }
}

notifyOnMoved(BuildContext context) {
  final snackBar = SnackBar(
    content: Text(strings['slidesMoved']!),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

Future<String> getDownloadDirectory() async {
  final directory = await getApplicationDocumentsDirectory();
  if (!(await directory.exists())) {
    await directory.create();
  }

  return directory.path;
}

DeckRequest buildDeckRequestFromState(SlidesModel state,
    {String format = "pdf"}) {
  return DeckRequest(
    date: state.date,
    items: state.items,
    hints: Settings.getValue<bool>('slides.hints'),
    ratio: Settings.getValue<String>('slides.aspectRatio'),
    fontSize: Settings.getValue<double>('slides.fontSize')?.toInt(),
    format: format,
  );
}

Future<String> createDeck(BuildContext context, {String format = "pdf"}) async {
  if (!kIsWeb && Platform.isAndroid) {
    await Permission.storage.request();
  }
  final state = Provider.of<SlidesModel>(context, listen: false);
  final deckRequest = buildDeckRequestFromState(
    state,
    format: format,
  );
  final url = Uri.parse(await postDeck(deckRequest));

  if (!kIsWeb && Platform.isAndroid) {
    // FlutterDownloader.registerCallback(downloaderCallback);
    final destination = await getDownloadDirectory();
    final extension = format.endsWith("zip") ? "zip" : "pdf";
    final fileName =
        '${state.date.toIso8601String().substring(0, 10)}.$extension';

    final fullPath = "$destination/$fileName";
    final file = File(fullPath);

    if (await file.exists()) {
      await file.delete();
    }

    final task = DownloadTask(
      url: url.toString(),
      filename: fileName,
    );

    await FileDownloader().download(task);

    return task.filePath();
  } else if (await canLaunchUrl(url)) {
    await launchUrl(url);

    final snackBar = SnackBar(
      content: Text(strings['slidesOpeningInBrowser']!),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  return url.toString();
}
