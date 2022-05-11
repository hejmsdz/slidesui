import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import './state.dart';

Future<File?> getStateFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/state.json');
  } catch (e) {
    return null;
  }
}

startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

saveStateChanges(SlidesModel state) async {
  final file = await getStateFile();
  if (file == null) {
    return;
  }

  state.addListener(() async {
    final json = jsonEncode(state);
    file.writeAsString(json);
  });
}

Future<SlidesModel> loadSavedState() async {
  final emptyModel = SlidesModel();
  try {
    final file = await getStateFile();
    if (file == null) {
      return emptyModel;
    }
    final json = await file.readAsString();
    final state = SlidesModel.fromJson(jsonDecode(json));

    if (state.date.isBefore(startOfToday())) {
      // discard saved state if it's for a past date
      return emptyModel;
    }
    return state;
  } catch (e) {
    return emptyModel;
  }
}
