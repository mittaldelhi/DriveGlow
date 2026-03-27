import 'package:flutter_test/flutter_test.dart';
import 'package:shinex/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AquaGlossApp());

    // Verify that the brand name is present in the header.
    expect(find.text('AquaGloss'), findsOneWidget);
  });
}
