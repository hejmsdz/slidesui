import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:slidesui/model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import './state.dart';
import './strings.dart';
import './api.dart';

Future<String> moveFile(String source) async {
  const platform = MethodChannel("com.example.slidesui/filePicker");
  try {
    return await platform.invokeMethod("moveFile", {
      "source": source,
    });
  } on PlatformException catch (_) {
    return "";
  }
}

notifyOnDownloaded(
  BuildContext context,
  String taskId,
  String destinationFile,
) {
  final snackBar = SnackBar(
    content: Text(strings['slidesDownloadedInternal']!),
    action: SnackBarAction(
      label: strings['move']!,
      onPressed: () async {
        FlutterDownloader.remove(taskId: taskId);
        final moveTarget = await moveFile(destinationFile);
        if (moveTarget != "") {
          notifyOnMoved(context);
        }
      },
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

notifyOnMoved(BuildContext context) {
  final snackBar = SnackBar(
    content: Text(strings['slidesMoved']!),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

Future<String> getDownloadDirectory() async {
  final directory = await getExternalStorageDirectory();
  if (directory == null) {
    return "";
  }
  if (!(await directory.exists())) {
    await directory.create();
  }

  return directory.path;
}

createDeck(BuildContext context) async {
  if (!kIsWeb && Platform.isAndroid) {
    await Permission.storage.request();
  }
  final state = Provider.of<SlidesModel>(context, listen: false);
  final deckRequest = DeckRequest(
    date: state.date,
    items: state.items,
    hints: Settings.getValue<bool>('slides.hints'),
    ratio: Settings.getValue<String>('slides.aspectRatio'),
    fontSize: Settings.getValue<double>('slides.fontSize')?.toInt(),
  );
  final url = Uri.parse(await postDeck(deckRequest));

  if (!kIsWeb && Platform.isAndroid) {
    final destination = await getDownloadDirectory();
    final fileName = state.date.toIso8601String().substring(0, 10) + '.pdf';
    final taskId = await FlutterDownloader.enqueue(
      url: url.toString(),
      savedDir: destination,
      fileName: fileName,
      showNotification: false,
    );

    if (taskId != null) {
      notifyOnDownloaded(context, taskId, "$destination/$fileName");
    }
  } else if (await canLaunchUrl(url)) {
    await launchUrl(url);

    final snackBar = SnackBar(
      content: Text(strings['slidesOpeningInBrowser']!),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } else {}
}
