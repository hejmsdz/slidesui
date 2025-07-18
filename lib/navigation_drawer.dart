import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slidesui/api.dart';
import 'package:slidesui/authentication.dart';
import 'package:slidesui/receiver.dart';
import 'package:slidesui/settings.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';
import 'package:slidesui/model.dart';
import 'package:slidesui/web_view.dart';
import 'package:url_launcher/url_launcher.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key, required this.toggleUserMenu});

  final void Function() toggleUserMenu;

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  bool _isLoading = false;

  Future<void> _logInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await logInWithGoogle(context);
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlidesModel>(builder: (context, state, _) {
      if (state.user != null) {
        final color = Theme.of(context).colorScheme.onPrimary;
        final textStyle = TextStyle(color: color);
        final hasTeam = state.currentTeam != null;
        return Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                state.currentTeam?.name ?? strings['noTeam']!,
                style: hasTeam
                    ? textStyle
                    : textStyle.copyWith(
                        color: color.withAlpha(128),
                      ),
              ),
              accountEmail: Text(state.user!.displayName, style: textStyle),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              arrowColor: color,
              onDetailsPressed: () {
                widget.toggleUserMenu();
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
          return AlertDialog(
            title: Text(strings['selectTeam']!),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ...teams.map((team) => RadioListTile(
                      title: Text(team.name),
                      value: team.id,
                      groupValue: state.currentTeam?.id,
                      onChanged: (_) {
                        Navigator.pop(context, team);
                      },
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, null);
                },
                child: Text(strings['close']!),
              ),
              TextButton(
                child: Text(strings['newTeam']!),
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
        title: Text(strings['newTeam']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings['newTeamDescription']!),
            SizedBox(height: 8),
            TextField(
              controller: teamNameController,
              decoration: InputDecoration(labelText: strings['teamName']!),
              autofocus: true,
            )
          ],
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
            child: Text(strings['add']!),
          ),
        ],
      ),
    );

    if (teamName == null) {
      return null;
    }

    try {
      final newTeam = await postTeam(teamName);
      return newTeam;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings['addTeamError']!)));
      }
      return null;
    }
  }

  Future<void> _showInvitationDialog(BuildContext context, Team team) async {
    final invitation = await postTeamInvite(team.id);
    final invitationLink = invitation.url;

    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController(text: invitationLink);

        return AlertDialog(
          title: Text(strings['inviteToTeam']!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings['inviteLinkDescription']!
                  .replaceAll('{}', team.name)),
              TextField(
                controller: controller,
                readOnly: true,
                onTap: () => controller.selection = TextSelection(
                    baseOffset: 0, extentOffset: controller.value.text.length),
              ),
              Text(
                strings['linkExpiration']!.replaceAll('{}',
                    '${(invitation.expiresAt.difference(DateTime.now()).inMinutes / 60.0).round()}h'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text(strings['close']!),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.text));
              },
              child: Text(strings['copy']!),
            ),
            TextButton(
              onPressed: () async {
                await Share.share(controller.text);
              },
              child: Text(strings['share']!),
            ),
          ],
        );
      },
    );
  }

  Future<String?> showLiveSessionKeyDialog(BuildContext context) async {
    final state = context.read<SlidesModel>();
    final frontendUrl = state.bootstrap?.frontendUrl.replaceAll('https://', '');

    TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
          title: Text(strings['enterLiveSessionKey']!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (frontendUrl != null)
                Text(strings['enterLiveSessionKeyDescription']!
                    .replaceFirst('{}', frontendUrl)),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLines: 1,
                maxLength: 4,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(strings['cancel']!),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(strings['ok']!),
              onPressed: () {
                if (controller.text.length != 4) {
                  return;
                }

                Navigator.of(context).pop(controller.text);
              },
            ),
          ]),
    );
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
                  if (state.currentTeam != null)
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: Text(strings['inviteToTeam']!),
                      onTap: () =>
                          _showInvitationDialog(context, state.currentTeam!),
                    ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text(strings['yourAccount']!),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => WebViewPage(
                                path: "dashboard/settings",
                                title: strings['yourAccount']!,
                                onClose: (_) async {
                                  await state.loadUser();
                                  if (state.user == null) {
                                    toggleUserMenu();
                                  }
                                })),
                      );
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
                      storeAuthResponse(null);
                      toggleUserMenu();
                    },
                  ),
                ],
              );
            }),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(strings['addSong']!),
              onTap: () {
                final state = context.read<SlidesModel>();
                if (state.currentTeam == null) {
                  final isLoggedIn = state.user != null;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(strings['teamRequired']!),
                      content: Text(isLoggedIn
                          ? strings['teamRequiredDescriptionLoggedIn']!
                          : strings['teamRequiredDescriptionLoggedOut']!),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(strings['ok']!),
                        ),
                      ],
                    ),
                  );

                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WebViewPage(
                      path: "dashboard/songs/new",
                      title: strings['addSong']!,
                    ),
                  ),
                );
              },
            ),
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
              leading: const Icon(Icons.slideshow),
              title: Text(strings['presentationReceiver']!),
              onTap: () async {
                final liveSessionKey = await showLiveSessionKeyDialog(context);

                if (liveSessionKey == null || !context.mounted) {
                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) =>
                          PresentationReceiver(liveSessionKey: liveSessionKey)),
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
