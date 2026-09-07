import "package:flow/app/app.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
