import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("opts into Android predictive back callbacks", () {
    final manifest = File("android/app/src/main/AndroidManifest.xml").readAsStringSync();

    expect(
      manifest,
      contains('android:enableOnBackInvokedCallback="true"'),
    );
  });
}
