import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:anon_mobile/main.dart';
import 'package:anon_mobile/state/auth_state.dart';

void main() {
  testWidgets('shows sign-in screen when logged out',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AuthState(),
        child: const AnonWorkApp(),
      ),
    );

    expect(find.text('AnonWork'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
