import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/authentication.dart';
import 'package:slidesui/settings.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';
import 'package:slidesui/model.dart';
import 'package:url_launcher/url_launcher.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key, required this.toggleUserMenu});

  final void Function() toggleUserMenu;

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  bool _isLoading = false;
  List<Team>? _teams;

  Future<void> _loadTeams() async {
    if (_teams != null) return;

    try {
      final teams = await getTeams();
      setState(() => _teams = teams);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

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
        return Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(state.currentTeam?.name ?? ""),
              accountEmail: Text(state.user!.displayName),
              onDetailsPressed: () {
                widget.toggleUserMenu();
                _loadTeams();
              },
            ),
          ],
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

class AppNavigationDrawer extends StatefulWidget {
  const AppNavigationDrawer({super.key});

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  bool _isUserMenuOpen = false;

  void toggleUserMenu() {
    setState(() => _isUserMenuOpen = !_isUserMenuOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          UserInfo(toggleUserMenu: toggleUserMenu),
          if (_isUserMenuOpen) ...[
            Consumer<SlidesModel>(builder: (context, state, _) {
              if (state.user == null) return Container();

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: Text("Wybierz zespół"),
                    onTap: () async {
                      final teams = await getTeams();
                      if (!mounted) return;

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Wybierz zespół"),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: teams.length,
                              itemBuilder: (context, index) {
                                final team = teams[index];
                                return ListTile(
                                  title: Text(team.name),
                                  selected: team.id == state.currentTeam?.id,
                                  onTap: () {
                                    state.setCurrentTeam(team);
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(strings['logOut']!),
                    onTap: () {
                      context.read<SlidesModel>().setUser(null);
                      storeAuthResponse(null);
                    },
                  ),
                ],
              );
            }),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(strings['settings']!),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            Consumer<SlidesModel>(builder: (context, state, _) {
              if (state.bootstrap?.supportUrl == null) {
                return Container();
              }

              return ListTile(
                leading: const Icon(Icons.favorite),
                title: Text(strings['support']!),
                onTap: () {
                  launchUrl(Uri.parse(state.bootstrap!.supportUrl!));
                },
              );
            }),
            Consumer<SlidesModel>(builder: (context, state, _) {
              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text(strings['contact']!),
                onTap: () {
                  launchUrl(Uri.parse(state.bootstrap!.contactUrl!));
                },
              );
            }),
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
          ]
        ],
      ),
    );
  }
}
