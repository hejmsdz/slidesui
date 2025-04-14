import 'package:google_sign_in/google_sign_in.dart';

Future<String?> getGoogleIdToken() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['openid', 'profile', 'email'],
  );

  try {
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    return auth.idToken;
  } catch (error) {
    print('Error getting ID token: $error');
    return null;
  }
}
