import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

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

Future<bool> logInWithGoogle(BuildContext context) async {
  try {
    final idToken = await getGoogleIdToken();
    final authResponse = await postAuthGoogle(idToken);

    if (context.mounted) {
      final state = context.read<SlidesModel>();
      await state.setUser(authResponse.user);

      if (state.currentTeam == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(strings['logInSuccessNoTeam']!
                .replaceAll('{}', authResponse.user.displayName))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(strings['logInSuccess']!
                .replaceAll('{}', authResponse.user.displayName))));
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings['logInError']!)));
    }
    return false;
  }

  return true;
}
