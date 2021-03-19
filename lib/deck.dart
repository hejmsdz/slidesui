import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:url_launcher/url_launcher.dart';
import './state.dart';
import './strings.dart';
import './api.dart';

Future<String> getExternalDownloadPathIfAvailable() async {
  // external storage doesn't seem to work because of permission issues
  return Future(() => null);

  /*
  final volume = await Directory('/storage').list().firstWhere(
      (volume) =>
          !volume.path.endsWith('emulated') && !volume.path.endsWith('self'),
      orElse: () => null);
  return volume?.path;
  */
}

createDeck(BuildContext context) async {
  if (Platform.isAndroid) {
    await Permission.storage.request();
  }
  final items = Provider.of<SlidesModel>(context, listen: false).items;
  final url = await postDeck(items);

  if (Platform.isAndroid && await Permission.storage.isGranted) {
    final externalDestination = await getExternalDownloadPathIfAvailable();
    final isExternal = externalDestination != null;
    final destination = isExternal ? externalDestination : '/sdcard';
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: destination,
      showNotification: false,
    );

    final snackBar = SnackBar(
      content: Text(isExternal
          ? strings['slidesDownloadedExternal']
          : strings['slidesDownloadedInternal']),
      action: SnackBarAction(
        label: strings['open'],
        onPressed: () {
          FlutterDownloader.open(taskId: taskId);
        },
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } else if (await canLaunch(url)) {
    await launch(url);

    final snackBar = SnackBar(
      content: Text(strings['slidesOpeningInBrowser']),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } else {}
}
