import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

bool _googleSignInInitialized = false;

Future<void> _ensureGoogleSignInInitialized() async {
  if (!_googleSignInInitialized) {
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }
}

Future<String> getGoogleIdToken() async {
  await _ensureGoogleSignInInitialized();

  final GoogleSignInAccount account;
  try {
    account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw Exception('No Google account');
    }
    rethrow;
  }

  final GoogleSignInAuthentication auth = account.authentication;
  final String? idToken = auth.idToken;

  if (idToken == null) {
    throw Exception('No ID token');
  }

  return idToken;
}

Future<bool> logInWithGoogle(BuildContext context,
    {bool showSuccessMessage = true}) async {
  try {
    final idToken = await getGoogleIdToken();
    final authResponse = await postAuthGoogle(idToken);

    if (context.mounted) {
      final state = context.read<SlidesModel>();
      await state.setUser(authResponse.user);

      if (showSuccessMessage) {
        final messageKey =
            state.currentTeam == null ? 'logInSuccessNoTeam' : 'logInSuccess';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings[messageKey]!
                .replaceAll('{}', authResponse.user.displayName)),
          ),
        );
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
