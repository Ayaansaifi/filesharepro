import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/feed_provider.dart';

Future<void> saveMemeToGallery(MemeModel meme) async {
  final tempDir = await getTemporaryDirectory();
  final ext = meme.isGif ? '.gif' : '.jpg';
  final fileName = 'meme_${DateTime.now().millisecondsSinceEpoch}$ext';
  final filePath = '${tempDir.path}/$fileName';

  final dio = Dio();
  await dio.download(
    meme.url,
    filePath,
    options: Options(
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
      },
    ),
  );

  final file = File(filePath);
  if (await file.exists()) {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImage(filePath);
    try {
      await file.delete();
    } catch (_) {}
  }
}
