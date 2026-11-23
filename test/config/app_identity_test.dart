import 'package:modu_reader/config/app_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('小陈笔记 public identity is stable', () {
    expect(AppIdentity.zhDisplayName, '小陈笔记');
    expect(AppIdentity.globalDisplayName, '小陈笔记');
    expect(AppIdentity.bundleId, 'com.modu.reader');
  });
}
