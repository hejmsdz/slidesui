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

  Future<void> openTeamsDialog() async {
    final state = context.read<SlidesModel>();
    final teams = await getTeams();
    if (!mounted) return;

    final team = await showDialog<Team>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(strings['selectTeam']!),
            children: <Widget>[
              ...teams.map((team) => SimpleDialogOption(
                    child: Text(team.name),
                    onPressed: () {
                      Navigator.pop(context, team);
                    },
                  )),
              const Divider(),
              SimpleDialogOption(
                child: Text(strings['addTeam']!),
                onPressed: () async {
                  final newTeam = await openAddTeamDialog();
                  Navigator.pop(context, newTeam);
                },
              ),
            ],
          );
        });

    if (team != null && team.id != state.currentTeam?.id) {
      state.removeAllItems();
      state.setCurrentTeam(team);
    }
  }

  Future<Team?> openAddTeamDialog() async {
    final teamNameController = TextEditingController();
    final teamName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings['addTeam']!),
        content: TextField(
          controller: teamNameController,
          decoration: InputDecoration(labelText: strings['teamName']!),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context, null);
            },
            child: Text(strings['cancel']!),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, teamNameController.text);
            },
            child: Text(strings['add']!.toUpperCase()),
          ),
        ],
      ),
    );

    if (teamName == null) {
      return null;
    }

    try {
      final newTeam = await postTeam(teamName);
      print(newTeam);
      return newTeam;
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings['addTeamError']!)));
      }
      return null;
    }
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
                    title: Text(strings['yourTeams']!),
                    onTap: () async {
                      await openTeamsDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(strings['yourAccount']!),
                    onTap: () {
                      launchUrl(
                          Uri.parse("https://psal.lt/dashboard/settings"));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(strings['logOut']!),
                    onTap: () {
                      state.setUser(null);
                      deleteAuthRefresh();
                      state.removeAllItems();
                      toggleUserMenu();
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
