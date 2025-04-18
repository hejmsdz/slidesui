import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/authentication.dart';
import 'package:slidesui/settings.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  bool _isLoading = false;

  Future<void> _logInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final idToken = await getGoogleIdToken();
      final authResponse = await postAuthGoogle(idToken);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(strings['logInSuccess']!
                .replaceAll('{}', authResponse.user.displayName))));
        context.read<SlidesModel>().setUser(authResponse.user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings['logInError']!)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlidesModel>(builder: (context, state, _) {
      if (state.user != null) {
        return UserAccountsDrawerHeader(
          accountName: Text(state.user!.displayName),
          accountEmail: Text(state.user!.email),
        );
      }

      return ListTile(
        leading: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person),
        title: Text(strings['logIn']!),
        onTap: _logInWithGoogle,
        enabled: !_isLoading,
      );
    });
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const UserInfo(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(strings['settings']!),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(strings['support']!),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: Text(strings['contact']!),
          ),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container();
              }

              return AboutListTile(
                icon: const Icon(Icons.info),
                applicationName: snapshot.data?.appName,
                applicationVersion: snapshot.data?.version,
                applicationLegalese: "© Mikołaj Rozwadowski",
                child: Text(strings['about']!),
              );
            },
          ),
        ],
      ),
    );
  }
}
