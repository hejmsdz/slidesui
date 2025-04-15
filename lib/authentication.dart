import 'package:google_sign_in/google_sign_in.dart';

Future<String> getGoogleIdToken() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['openid', 'profile', 'email'],
  );

  final GoogleSignInAccount? account = await googleSignIn.signIn();
  if (account == null) {
    throw Exception('No Google account');
  }

  final GoogleSignInAuthentication auth = await account.authentication;

  if (auth.idToken == null) {
    throw Exception('No ID token');
  }

  return auth.idToken!;
}
