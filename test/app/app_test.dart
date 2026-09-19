import "dart:async";

import "package:flow/app/app.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("text fields clear focus outside but retain it when the keyboard is minimized", (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(FlowApp(preferences: MemoryFlowPreferences()));
    await tester.pumpAndSettle();
    final firstFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    var completed = false;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: firstFocus,
                  decoration: const InputDecoration(hintText: "First field"),
                ),
                const TextField(decoration: InputDecoration(hintText: "Second field")),
                const SizedBox(height: 100, child: Center(child: Text("Outside"))),
                ListenableBuilder(
                  listenable: firstFocus,
                  builder: (_, _) => firstFocus.hasFocus
                      ? TextButton(
                          onPressed: () {
                            completed = true;
                            firstFocus.requestFocus();
                          },
                          child: const Text("Complete text"),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(EditableText);
    final secondFocus = tester.widget<EditableText>(fields.last).focusNode;

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    final completionTap = await tester.startGesture(tester.getCenter(find.text("Complete text")));
    await tester.pump();
    await completionTap.up();
    await tester.pump();
    expect(completed, isTrue);
    expect(firstFocus.hasFocus, isTrue);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.tap(find.text("Outside"));
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);

    await tester.tap(find.byType(TextField).first);
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);

    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);
    tester.view.resetViewInsets();
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      "flow/keyboard",
      const StandardMethodCodec().encodeMethodCall(const MethodCall("dismissFocus")),
      (_) {},
    );
    await tester.pump();
    expect(secondFocus.hasFocus, isFalse);

    unawaited(
      showDialog<void>(
        context: tester.element(find.text("Outside")),
        builder: (_) => const AlertDialog(
          title: Text("Dialog title"),
          content: TextField(autofocus: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dialogFocus = tester
        .widget<EditableText>(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(EditableText)),
        )
        .focusNode;
    expect(dialogFocus.hasFocus, isTrue);
    await tester.tap(find.text("Dialog title"));
    await tester.pump();
    expect(dialogFocus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets("launches even when settings storage fails", (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(FlowApp(preferences: _UnavailablePreferences()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnavailablePreferences extends MemoryFlowPreferences {
  @override
  Future<bool> readAdProxyEnabled() async => throw StateError("Storage unavailable");
}
