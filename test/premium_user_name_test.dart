import 'package:anon_mobile/widgets/premium_user_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    bool? isPremium,
    bool isAnonymous = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PremiumUserName(
          userId: 'user-1',
          name: isAnonymous ? 'Ẩn danh' : 'Quan Tran',
          isPremium: isPremium,
          isAnonymous: isAnonymous,
        ),
      ),
    );
  }

  testWidgets('shows the verified mark for a Premium user', (tester) async {
    await tester.pumpWidget(buildSubject(isPremium: true));

    expect(find.byType(PremiumUserName), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('hides the verified mark for a non-Premium user', (tester) async {
    await tester.pumpWidget(buildSubject(isPremium: false));

    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('never exposes Premium status for an anonymous identity',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(isPremium: true, isAnonymous: true),
    );

    expect(find.text('Ẩn danh', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
  });
}
