import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

DeckRequest buildDeckRequestFromState(
  SlidesModel state, {
  String format = "pdf",
  bool contents = false,
}) {
  return DeckRequest(
    date: state.date,
    items: state.items,
    hints: Settings.getValue<bool>('slides.hints'),
    ratio: Settings.getValue<String>('slides.aspectRatio'),
    fontSize: Settings.getValue<double>('slides.fontSize')?.toInt(),
    verticalAlign: Settings.getValue<String>('slides.verticalAlign'),
    format: format,
    contents: contents,
  );
}

Future<DeckResponse> createDeck(
  BuildContext context, {
  String format = "pdf",
  bool contents = false,
}) async {
  final state = Provider.of<SlidesModel>(context, listen: false);
  final deckRequest = buildDeckRequestFromState(
    state,
    format: format,
    contents: contents,
  );
  final response = await postDeck(deckRequest);
  final url = Uri.parse(response.url);

  if (!kIsWeb) {
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

    return DeckResponse(
      await task.filePath(),
      response.contents,
    );
  } else if (await canLaunchUrl(url)) {
    await launchUrl(url);

    final snackBar = SnackBar(
      content: Text(strings['slidesOpeningInBrowser']!),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  return response;
}
