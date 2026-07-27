import 'package:flutter_test/flutter_test.dart';

import 'package:mvision_client/shared/platform_keys.dart';

void main() {
  test('primary shortcut label is available on the current platform', () {
    expect(PlatformKeys.label('S'), isNotEmpty);
  });
}
