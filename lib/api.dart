import 'dart:convert';
import 'package:http/http.dart' as http;
import './model.dart';

const rootURL = 'slajdyrocha2.herokuapp.com';

Uri apiURL(String path, Map<String, dynamic> params) {
  return Uri.https(rootURL, path, params);
}

Future<List<Song>> getSongs(String query) async {
  final response = await http.get(apiURL('v2/songs', {'query': query}));

  if (response.statusCode != 200) {
    return null;
  }

  final body = Utf8Decoder().convert(response.body.codeUnits);
  final json = jsonDecode(body) as List;

  return json.map((itemJson) => Song.fromJson(itemJson)).toList();
}
