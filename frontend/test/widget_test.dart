import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ppm_mobile/features/auth/auth_screen.dart';
import 'package:ppm_mobile/features/app/app.dart';
import 'package:ppm_mobile/features/app/app_state.dart';

void main() {
  testWidgets('auth screen renders the mobile promise', (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          home: AuthScreen(),
        ),
      ),
    );

    expect(find.text('PPM Mobile'), findsOneWidget);
    expect(find.textContaining('Agregar un gasto'), findsOneWidget);
    expect(find.text('Entrar y cargar grupos'), findsOneWidget);
  });
}
