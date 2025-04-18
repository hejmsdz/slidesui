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
  final state = SlidesModel();
  try {
    final file = await getStateFile();
    if (file == null) {
      return state;
    }
    final json = await file.readAsString();
    state.loadFromJson(jsonDecode(json));

    return state;
  } catch (e) {
    return state;
  }
}
