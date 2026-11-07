// Basic smoke test for the Intercom app.
//
// For now this only verifies the widget tree can be inflated without errors.
// Full integration tests require Firebase emulators and a WebRTC mock.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intercom_app/app.dart';

void main() {
  testWidgets('IntercomApp renders role selection screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: IntercomApp()),
    );

    // The first screen should be the role selection screen.
    expect(find.text('Intercom Setup'), findsOneWidget);
    expect(find.text('Director'), findsOneWidget);
    expect(find.text('Crew'), findsOneWidget);
  });
}
