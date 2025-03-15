import 'dart:convert';
import 'package:http/http.dart' as http;
import './model.dart';

const rootURL = 'slajdy.swro.ch';

class ApiError implements Exception {}

Uri apiURL(String path, [Map<String, dynamic>? params]) {
  return Uri.https(rootURL, path, params);
}

Future<List<Song>> getSongs(String query) async {
  final response = await http.get(apiURL('v2/songs', {'query': query}));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  final json = jsonDecode(response.body) as List;

  return json.map((itemJson) => Song.fromJson(itemJson)).toList();
}

Future<List<String>> getLyrics(String songId, {bool raw = false}) async {
  final response =
      await http.get(apiURL("v2/lyrics/$songId", {'raw': raw ? '1' : null}));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  final json = jsonDecode(response.body) as List;

  return json.map((itemJson) => itemJson.toString()).toList();
}

Future<DeckResponse> postDeck(deckRequest) async {
  final response = await http.post(
    apiURL('v2/deck'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(deckRequest),
  );
  final deckResponse = DeckResponse.fromJson(jsonDecode(response.body));

  return deckResponse;
}

Future<BootstrapResponse> getBootstrap() async {
  final response = await http.get(apiURL('v2/bootstrap'));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return BootstrapResponse.fromJson(jsonDecode(response.body));
}

Future<Liturgy> getLiturgy(DateTime date) async {
  final dateString = date.toIso8601String().substring(0, 10);
  final response = await http.get(apiURL("v2/liturgy/$dateString"));

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return Liturgy.fromJson(jsonDecode(response.body));
}
