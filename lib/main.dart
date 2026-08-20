import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/survey_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/realtime_service.dart';
import 'theme/kpit_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SondageApp());
}

class SondageApp extends StatelessWidget {
  const SondageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(ApiClient())..bootstrap(),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
      ],
      child: MaterialApp(
        title: 'KPIT Sondage',
        debugShowCheckedModeBanner: false,
        theme: KpitTheme.dark(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: KpitTheme.lime),
          ),
        );
      case AuthStatus.unauthenticated:
        return const _LoggedOutGate(child: LoginScreen());
      case AuthStatus.authenticated:
        return const _LoggedInGate(child: HomeShell());
    }
  }
}

class _LoggedInGate extends StatefulWidget {
  const _LoggedInGate({required this.child});

  final Widget child;

  @override
  State<_LoggedInGate> createState() => _LoggedInGateState();
}

class _LoggedInGateState extends State<_LoggedInGate> {
  RealtimeService? _realtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final notif = context.read<NotificationProvider>();
    final surveys = context.read<SurveyProvider>();

    await notif.ensureStarted(auth.api);
    await surveys.ensureStarted(auth.api);

    final rt = RealtimeService(auth.api);
    _realtime = rt;
    await rt.start(
      userId: user.id,
      canManage: user.canManageSurveys,
      onNotification: notif.addFromRealtime,
      onSurveyChanged: ({required action, survey, surveyId}) {
        surveys.applyRealtime(
          action: action,
          survey: survey,
          surveyId: surveyId,
        );
      },
    );
  }

  @override
  void dispose() {
    _realtime?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LoggedOutGate extends StatefulWidget {
  const _LoggedOutGate({required this.child});

  final Widget child;

  @override
  State<_LoggedOutGate> createState() => _LoggedOutGateState();
}

class _LoggedOutGateState extends State<_LoggedOutGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().stop();
      context.read<SurveyProvider>().stop();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
