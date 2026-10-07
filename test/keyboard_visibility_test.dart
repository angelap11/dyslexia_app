import 'package:dyslexia_app/core/keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('isKeyboardVisible tracks MediaQuery.viewInsets.bottom', (
    tester,
  ) async {
    late bool visible;

    Widget host({required double inset}) {
      return MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
        child: Builder(
          builder: (context) {
            visible = isKeyboardVisible(context);
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(host(inset: 0));
    expect(visible, isFalse);

    await tester.pumpWidget(host(inset: 280));
    expect(visible, isTrue);

    await tester.pumpWidget(host(inset: 0));
    expect(visible, isFalse);
  });

  testWidgets('chrome follows keyboard visibility, not FocusNode.hasFocus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    Future<void> pumpWithInset(double inset) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
            child: Builder(
              builder: (context) {
                final keyboardOpen = isKeyboardVisible(context);
                return Scaffold(
                  body: Column(
                    children: [
                      TextField(focusNode: focusNode),
                      if (!keyboardOpen) const Text('Play'),
                      if (!keyboardOpen) const Text('Nav'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    await pumpWithInset(300);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(find.text('Play'), findsNothing);
    expect(find.text('Nav'), findsNothing);

    // Keyboard dismissed while focus can still be true — chrome must return.
    await pumpWithInset(0);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Nav'), findsOneWidget);
  });
}
