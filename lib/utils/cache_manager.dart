import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheManager {
  CacheManager._();

  static Future<String> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      double size = await _getTotalSizeOfDir(tempDir);
      return _formatSize(size);
    } catch (e) {
      return '0 MB';
    }
  }

  static Future<void> clearAllCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      //
    }
  }

  static Future<double> _getTotalSizeOfDir(FileSystemEntity file) async {
    if (file is File) {
      return file.lengthSync().toDouble();
    }
    if (file is Directory) {
      final children = file.listSync();
      double total = 0;
      if (children.isNotEmpty) {
        for (final child in children) {
          total += await _getTotalSizeOfDir(child);
        }
      }
      return total;
    }
    return 0;
  }

  static String _formatSize(double size) {
    if (size <= 0) return '0 MB';
    const List<String> unitArr = ['B', 'K', 'M', 'G'];
    int index = 0;
    while (size > 1024 && index < unitArr.length - 1) {
      index++;
      size = size / 1024;
    }
    if (index < 2) return '0.1 MB';
    return '${size.toStringAsFixed(2)} ${unitArr[index]}';
  }
}
