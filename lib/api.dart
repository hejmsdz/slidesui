import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import './model.dart';

const rootURL = 'https://api.psal.lt/';

class ApiError implements Exception {}

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: rootURL,
          contentType: 'application/json; charset=UTF-8',
        )),
        _storage = const FlutterSecureStorage() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _storage.read(key: 'accessToken') ?? '';
        if (accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !_isRefreshing &&
            await _storage.containsKey(key: 'refreshToken')) {
          try {
            _isRefreshing = true;
            await _refreshToken();
            _isRefreshing = false;

            // Retry the original request
            final opts = Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers,
            );
            final response = await _dio.request(
              error.requestOptions.path,
              options: opts,
              data: error.requestOptions.data,
              queryParameters: error.requestOptions.queryParameters,
            );
            return handler.resolve(response);
          } catch (e) {
            _isRefreshing = false;
            return handler.reject(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null) {
      throw ApiError();
    }

    print("REFRESHING TOKEN: $refreshToken");
    final response = await _dio.post(
      '/v2/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    print("REFRESH RESPONSE: ${response.statusCode}");
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiError();
    }

    final authResponse = AuthResponse.fromJson(response.data);
    await storeAuthResponse(authResponse);
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path,
      {Map<String, dynamic>? params, Object? data}) async {
    return _dio.post(path, queryParameters: params, data: data);
  }

  Future<Response> put(String path,
      {Map<String, dynamic>? params, Object? data}) async {
    return _dio.put(path, queryParameters: params, data: data);
  }

  void close() {
    _dio.close();
  }
}

final apiClient = ApiClient();

Future<List<Song>> getSongs(String query) async {
  final response = await apiClient.get('v2/songs', params: {'query': query});

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return (response.data as List)
      .map((itemJson) => Song.fromJson(itemJson))
      .toList();
}

Future<List<String>> getLyrics(String songId, {bool raw = false}) async {
  final response = await apiClient.get(
    "v2/lyrics/$songId",
    params: {'raw': raw ? '1' : null},
  );

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return (response.data as List).map((item) => item.toString()).toList();
}

Future<DeckResponse> postDeck(deckRequest) async {
  final response = await apiClient.post('v2/deck', data: deckRequest);
  return DeckResponse.fromJson(response.data);
}

Future<BootstrapResponse> getBootstrap() async {
  final response = await apiClient.get('v2/bootstrap');

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return BootstrapResponse.fromJson(response.data);
}

Future<Liturgy> getLiturgy(DateTime date) async {
  final dateString = date.toIso8601String().substring(0, 10);
  final response = await apiClient.get("v2/liturgy/$dateString");

  if (response.statusCode != 200) {
    throw ApiError();
  }

  return Liturgy.fromJson(response.data);
}

Future<AuthResponse> postAuthGoogle(String idToken) async {
  final response = await apiClient.post(
    'v2/auth/google',
    data: {'idToken': idToken},
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw ApiError();
  }

  final authResponse = AuthResponse.fromJson(response.data);
  await storeAuthResponse(authResponse);

  return authResponse;
}

Future<User> getAuthMe() async {
  final response = await apiClient.get('v2/auth/me');
  return User.fromJson(response.data);
}

Future<void> storeAuthResponse(AuthResponse authResponse) async {
  final storage = FlutterSecureStorage();
  await storage.write(key: 'accessToken', value: authResponse.token);
  await storage.write(key: 'refreshToken', value: authResponse.refreshToken);
}
