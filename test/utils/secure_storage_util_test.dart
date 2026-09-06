import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:listen_core/utils/sp_util.dart';
import 'package:listen_core/utils/secure_storage_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.init();
    await SecureStorageUtil.init(prefix: 'test_');
  });

  test('SecureStorageUtil fallback to memory and SpUtil works', () async {
    await SecureStorageUtil.put('token', 'abc123secret');
    final val = await SecureStorageUtil.get('token');
    expect(val, 'abc123secret');

    final exists = await SecureStorageUtil.containsKey('token');
    expect(exists, isTrue);

    await SecureStorageUtil.remove('token');
    final afterRemove = await SecureStorageUtil.get('token');
    expect(afterRemove, isNull);

    final existsAfterRemove = await SecureStorageUtil.containsKey('token');
    expect(existsAfterRemove, isFalse);
  });
}
