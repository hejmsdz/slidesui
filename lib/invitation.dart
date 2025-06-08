import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:slidesui/authentication.dart';
import 'package:slidesui/state.dart';
import 'package:slidesui/strings.dart';
import './api.dart';

class InvitationPage extends StatefulWidget {
  const InvitationPage({super.key, required this.token});

  final String token;

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  @override
  void initState() {
    super.initState();
    processInvitation();
  }

  Future<void> processInvitation() async {
    final state = context.read<SlidesModel>();

    if (state.user == null) {
      final loggedIn = await logInWithGoogle(context);
      if (!loggedIn) {
        _goToHome();
        return;
      }
    }

    try {
      final team = await postJoinTeam(widget.token);
      await state.setCurrentTeam(team);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(strings['joinTeamSuccess']!.replaceAll('{}', team.name))));
    } catch (e) {
      String message = strings['joinTeamError']!;

      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          message = strings['joinTeamErrorNotFound']!;
        } else if (e.response?.statusCode == 409) {
          message = strings['joinTeamErrorAlreadyMember']!;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _goToHome();
    }
  }

  void _goToHome() {
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dołącz do zespołu')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
