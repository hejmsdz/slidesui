import 'dart:convert';
import 'package:http/http.dart' as http;
import './model.dart';

const rootURL = 'slajdyrocha2.herokuapp.com';

Uri apiURL(String path, [Map<String, dynamic> params]) {
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

Future<String> postDeck(DateTime date, List<DeckItem> items) async {
  final deckRequest = DeckRequest(date, items);
  final response = await http.post(
    apiURL('v2/deck'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(deckRequest),
  );
  final body = Utf8Decoder().convert(response.body.codeUnits);
  final deckResponse = DeckResponse.fromJson(jsonDecode(body));

  return deckResponse.url;
}

Future<Manual> getManual() async {
  final response = await http.get(apiURL('v2/manual'));

  if (response.statusCode != 200) {
    return null;
  }

  final body = Utf8Decoder().convert(response.body.codeUnits);
  return Manual.fromJson(jsonDecode(body));
}

Future<BootstrapResponse> getBootstrap() async {
  final response = await http.get(apiURL('v2/bootstrap'));

  if (response.statusCode != 200) {
    return null;
  }

  final body = Utf8Decoder().convert(response.body.codeUnits);
  return BootstrapResponse.fromJson(jsonDecode(body));
}

Future<void> postReload() async {
  await http.post(apiURL('v2/reload'));
}
