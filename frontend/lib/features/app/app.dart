import 'package:flutter/material.dart';

import '../../core/presentation/app_theme.dart';
import '../auth/auth_screen.dart';
import '../shell/home_shell.dart';
import 'app_state.dart';

class PpmMobileApp extends StatefulWidget {
  const PpmMobileApp({super.key});

  @override
  State<PpmMobileApp> createState() => _PpmMobileAppState();
}

class _PpmMobileAppState extends State<PpmMobileApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PPM Mobile',
        theme: buildAppTheme(),
        home: AnimatedBuilder(
          animation: _state,
          builder: (context, _) {
            if (_state.isAuthenticated) {
              return const HomeShell();
            }
            return const AuthScreen();
          },
        ),
      ),
    );
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado en el arbol.');
    return scope!.notifier!;
  }
}
