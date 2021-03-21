import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import './state.dart';

Future<File> getStateFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/state.json');
}

startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

saveStateChanges(SlidesModel state) async {
  final file = await getStateFile();
  state.addListener(() async {
    final json = jsonEncode(state);
    file.writeAsString(json);
  });
}

Future<SlidesModel> loadSavedState() async {
  try {
    final file = await getStateFile();
    final json = await file.readAsString();
    final state = SlidesModel.fromJson(jsonDecode(json));

    if (state.date.isBefore(startOfToday())) {
      // discard saved state if it's for a past date
      return SlidesModel();
    }
    return state;
  } catch (e) {
    return SlidesModel();
  }
}
