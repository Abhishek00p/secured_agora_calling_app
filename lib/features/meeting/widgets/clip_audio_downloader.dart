// import 'dart:io';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:media_store_plus/media_store_plus.dart';
// import 'package:secured_calling/core/services/app_local_storage.dart';
// import 'package:secured_calling/core/services/download_controller.dart';
// import 'package:secured_calling/utils/app_logger.dart';

// class ClipAudioDownloader {
//   /// Downloads a recording from [m3u8Url] and saves it to the device Downloads folder.
//   ///
//   /// [clipStart] and [clipEnd] are offsets from the beginning of the HLS recording.
//   /// When omitted the full recording is downloaded.
//   ///
//   /// [onProgress] receives `(downloaded, total)` after each segment is saved,
//   /// allowing callers to update a notification or progress bar.
//   /// [onProcessing] is called once all segments are downloaded and the
//   /// audio-conversion step begins (Android FFmpeg merge).
//   /// [controller] lets the caller pause, resume, or cancel the download at
//   /// any segment boundary.
//   ///
//   /// Returns a human-readable message indicating where the file was saved.
//   /// Throws [DownloadCancelledException] if the controller cancels the task.
//   Future<String> download({
//     required String m3u8Url,
//     Duration? clipStart,
//     Duration? clipEnd,
//     String? fileName,
//     void Function(int downloaded, int total)? onProgress,
//     void Function()? onProcessing,
//     DownloadController? controller,
//   }) async {
//     final tempDir = await getTemporaryDirectory();

//     // ── Step 1: Fetch playlist ──────────────────────────────────────────────
//     final playlistResponse = await http.get(Uri.parse(m3u8Url), headers: {"Authorization": "Bearer ${AppLocalStorage.getToken()}"});
//     AppLogger.print("response of download audio :${playlistResponse.statusCode}, ${playlistResponse.body}");
//     if (playlistResponse.statusCode != 200) {
//       throw Exception('Failed to fetch playlist (HTTP ${playlistResponse.statusCode})');
//     }

//     final lines = playlistResponse.body.split('\n');
//     double timeline = 0;
//     final selectedSegments = <String>[];

//     for (int i = 0; i < lines.length; i++) {
//       if (!lines[i].startsWith('#EXTINF')) continue;

//       final durationStr = lines[i].split(':').elementAtOrNull(1)?.replaceAll(',', '') ?? '0';
//       final duration = double.tryParse(durationStr) ?? 0.0;

//       final segmentLine = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
//       if (segmentLine.isEmpty || segmentLine.startsWith('#')) {
//         timeline += duration;
//         continue;
//       }

//       final segStart = Duration(milliseconds: (timeline * 1000).toInt());
//       final segEnd = Duration(milliseconds: ((timeline + duration) * 1000).toInt());

//       final includeSegment =
//           (clipStart == null && clipEnd == null) || (clipStart != null && clipEnd != null && segEnd > clipStart && segStart < clipEnd);

//       if (includeSegment) {
//         selectedSegments.add(Uri.parse(m3u8Url).resolve(segmentLine).toString());
//       }

//       timeline += duration;
//     }

//     if (selectedSegments.isEmpty) {
//       throw Exception('No audio segments found in the recording');
//     }

//     // Notify caller of the total count so it can initialise the progress UI.
//     onProgress?.call(0, selectedSegments.length);

//     // ── Step 2: Download .ts segments one-at-a-time ─────────────────────────
//     // Streaming one segment at a time keeps peak memory low even for very long
//     // recordings: we write each response body to disk and discard it before
//     // fetching the next segment.
//     final segmentPaths = <String>[];
//     final baseTs = DateTime.now().millisecondsSinceEpoch;

//     for (int i = 0; i < selectedSegments.length; i++) {
//       // Honour pause / cancel signals between every segment.
//       await controller?.checkPoint();

//       final res = await http.get(Uri.parse(selectedSegments[i]), headers: {"Authorization": "Bearer ${AppLocalStorage.getToken()}"});
//       AppLogger.print("failed to download segment : ${res.statusCode}, ${res.body}");
//       if (res.statusCode != 200) {
//         throw Exception('Failed to download segment $i (HTTP ${res.statusCode})');
//       }
//       final path = '${tempDir.path}/seg_${baseTs}_$i.ts';
//       await File(path).writeAsBytes(res.bodyBytes);
//       segmentPaths.add(path);

//       // Report progress after each segment is persisted to disk.
//       onProgress?.call(i + 1, selectedSegments.length);
//     }

//     // Final check before we hand off to FFmpeg (can't easily cancel mid-encode).
//     await controller?.checkPoint();

//     final safeFileName = _sanitizeFileName(fileName ?? 'recording_$baseTs');

//     // Notify that we're now in the audio-processing phase.
//     onProcessing?.call();

//     // ── Step 3: Platform-specific processing & save ─────────────────────────
//     if (Platform.isAndroid) {
//       return await _processAndroid(tempDir, segmentPaths, safeFileName);
//     } else {
//       return await _processDesktop(tempDir, segmentPaths, safeFileName);
//     }
//   }

//   // ──────────────────────────────────────────────────────────────────────────
//   // Android path: FFmpeg merge → .m4a → MediaStore Downloads
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<String> _processAndroid(Directory tempDir, List<String> segmentPaths, String baseName) async {
//     final concatFile = File('${tempDir.path}/concat_${DateTime.now().millisecondsSinceEpoch}.txt');
//     await concatFile.writeAsString(segmentPaths.map((p) => "file '${p.replaceAll("'", "\\'")}'").join('\n'));

//     final outputPath = '${tempDir.path}/$baseName.m4a';
//     final command = '-f concat -safe 0 -i "${concatFile.path}" -vn -acodec aac -y "$outputPath"';

//     final session = await FFmpegKit.execute(command);
//     final returnCode = await session.getReturnCode();

//     if (returnCode == null || !returnCode.isValueSuccess()) {
//       final logs = await session.getAllLogsAsString();
//       debugPrint('FFmpeg error logs:\n$logs');
//       throw Exception('Audio conversion failed — FFmpeg returned $returnCode');
//     }

//     await _saveToAndroidDownloads(File(outputPath), '$baseName.m4a');
//     return '$baseName.m4a saved to Downloads';
//   }

//   Future<void> _saveToAndroidDownloads(File source, String fileName) async {
//     await MediaStore.ensureInitialized();
//     MediaStore.appFolder = 'secured_Calling';
//     final mediaStore = MediaStore();

//     final result = await mediaStore.saveFile(tempFilePath: source.path, dirType: DirType.download, dirName: DirName.download);

//     if (result == null) {
//       throw Exception('MediaStore failed to save the file to Downloads');
//     }

//     debugPrint("Saved to: $result");
//   }

//   // ──────────────────────────────────────────────────────────────────────────
//   // Desktop / Windows path: binary concat of TS → Downloads directory
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<String> _processDesktop(Directory tempDir, List<String> segmentPaths, String baseName) async {
//     final tempOutput = File('${tempDir.path}/$baseName.ts');
//     final sink = tempOutput.openWrite(mode: FileMode.writeOnly);

//     for (final path in segmentPaths) {
//       final f = File(path);
//       if (await f.exists()) {
//         sink.add(await f.readAsBytes());
//       }
//     }
//     await sink.flush();
//     await sink.close();

//     final savedPath = await _saveToDesktopDownloads(tempOutput, '$baseName.ts');
//     return 'Saved to: $savedPath';
//   }

//   Future<String> _saveToDesktopDownloads(File source, String fileName) async {
//     Directory? downloadsDir;
//     try {
//       downloadsDir = await getDownloadsDirectory();
//     } catch (_) {}
//     downloadsDir ??= await getApplicationDocumentsDirectory();

//     final destPath = '${downloadsDir.path}/$fileName';
//     await source.copy(destPath);
//     return destPath;
//   }

//   // ──────────────────────────────────────────────────────────────────────────
//   // Helpers
//   // ──────────────────────────────────────────────────────────────────────────
//   String _sanitizeFileName(String name) {
//     return name.replaceAll(RegExp(r'[^\w\-]'), '_').replaceAll(RegExp(r'_+'), '_');
//   }

//   // ──────────────────────────────────────────────────────────────────────────
//   // Legacy API kept for backward compatibility
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<File> downloadClip({required String m3u8Url, required Duration clipStart, required Duration clipEnd}) async {
//     final tempDir = await getTemporaryDirectory();

//     final playlistResponse = await http.get(Uri.parse(m3u8Url), headers: {"Authorization": "Bearer ${AppLocalStorage.getToken()}"});
//     AppLogger.print("downloadClip=> response of download audio :${playlistResponse.statusCode}, ${playlistResponse.body}");
//     if (playlistResponse.statusCode != 200) {
//       throw Exception('Failed to fetch playlist');
//     }

//     final lines = playlistResponse.body.split('\n');
//     double timeline = 0;
//     final selectedSegments = <String>[];

//     for (int i = 0; i < lines.length; i++) {
//       if (lines[i].startsWith('#EXTINF')) {
//         final duration = double.parse(lines[i].split(':')[1].replaceAll(',', ''));
//         final segmentLine = lines[i + 1].trim();
//         final segStart = Duration(milliseconds: (timeline * 1000).toInt());
//         final segEnd = Duration(milliseconds: ((timeline + duration) * 1000).toInt());

//         if (segEnd > clipStart && segStart < clipEnd) {
//           selectedSegments.add(Uri.parse(m3u8Url).resolve(segmentLine).toString());
//         }
//         timeline += duration;
//       }
//     }

//     if (selectedSegments.isEmpty) throw Exception('No segments found');

//     final segmentPaths = <String>[];
//     for (int i = 0; i < selectedSegments.length; i++) {
//       final res = await http.get(Uri.parse(selectedSegments[i]));
//       if (res.statusCode != 200) throw Exception('Segment download failed');
//       final path = '${tempDir.path}/seg_$i.ts';
//       await File(path).writeAsBytes(res.bodyBytes);
//       segmentPaths.add(path);
//     }

//     final concatFile = File('${tempDir.path}/concat.txt');
//     await concatFile.writeAsString(segmentPaths.map((p) => "file '${p.replaceAll("'", "\\'")}'").join('\n'));

//     final outputPath = '${tempDir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
//     final command = '-f concat -safe 0 -i ${concatFile.path} -vn -acodec aac $outputPath';
//     final session = await FFmpegKit.execute(command);
//     final returnCode = await session.getReturnCode();

//     if (returnCode == null || !returnCode.isValueSuccess()) {
//       throw Exception('FFmpeg merge failed');
//     }

//     await saveToDownloads(File(outputPath));
//     return File(outputPath);
//   }

//   Future<File> saveToDownloads(File source) async {
//     await MediaStore.ensureInitialized();
//     MediaStore.appFolder = 'secured_calling';
//     final mediaStore = MediaStore();

//     PermissionStatus status = await Permission.storage.status;
//     if (!status.isGranted) {
//       status = await Permission.storage.request();
//       if (!status.isGranted) throw Exception('Storage permission not granted');
//     }

//     final result = await mediaStore.saveFile(tempFilePath: source.path, dirType: DirType.audio, dirName: DirName.audiobooks);
//     if (result == null) throw Exception('Failed to save to Downloads');

//     return File(result.uri.toFilePath());
//   }
// // }
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';

class ClipAudioDownloader {
  /// 📥 FULL DOWNLOAD
  Future<String> downloadFull({required String audioUrl, String? fileName, void Function(int received, int total)? onProgress}) async {
    final tempDir = await getTemporaryDirectory();

    final baseName = _sanitizeFileName(fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}');

    final filePath = '${tempDir.path}/$baseName.m4a';

    final request = http.Request('GET', Uri.parse(audioUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    int received = 0;

    final file = File(filePath);
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }).asFuture();

    await sink.close();

    await _saveToDownloads(file, '$baseName.m4a');

    return file.path;
  }

  /// ✂️ CLIP DOWNLOAD (APPROX)
  Future<String> downloadClip({
    required String audioUrl,
    required Duration start,
    required Duration end,
    required Duration totalDuration,
    String? fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();

    final baseName = _sanitizeFileName(fileName ?? 'clip_${DateTime.now().millisecondsSinceEpoch}');

    final filePath = '${tempDir.path}/$baseName.m4a';

    final fileSize = await _getContentLength(audioUrl);

    final startByte = ((start.inMilliseconds / totalDuration.inMilliseconds) * fileSize).toInt();

    final endByte = ((end.inMilliseconds / totalDuration.inMilliseconds) * fileSize).toInt();

    final response = await http.get(Uri.parse(audioUrl), headers: {"Range": "bytes=$startByte-$endByte"});

    if (response.statusCode != 206 && response.statusCode != 200) {
      throw Exception('Clip download failed');
    }

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    await _saveToDownloads(file, '$baseName.m4a');

    return file.path;
  }

  /// 📦 GET FILE SIZE
  Future<int> _getContentLength(String url) async {
    final res = await http.head(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Failed to get file size');
    }
    return int.tryParse(res.headers['content-length'] ?? '0') ?? 0;
  }

  /// 💾 SAVE
  Future<void> _saveToDownloads(File source, String fileName) async {
    if (Platform.isWindows) {
      await _saveToWindowsDownloads(source, fileName);
      return;
    }

    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'secured_calling';

    final mediaStore = MediaStore();

    final result = await mediaStore.saveFile(tempFilePath: source.path, dirType: DirType.audio, dirName: DirName.music);

    if (result == null) {
      throw Exception('Failed to save file');
    }

    debugPrint("Saved to: $result");
  }

  /// Windows: copy into the user Downloads folder (mirrors a user-visible library save; [media_store_plus] is Android-only).
  Future<void> _saveToWindowsDownloads(File source, String fileName) async {
    Directory? downloadsDir;
    try {
      downloadsDir = await getDownloadsDirectory();
    } catch (_) {}
    downloadsDir ??= await getApplicationDocumentsDirectory();

    final subDir = Directory('${downloadsDir.path}/secured_calling');
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }

    final dest = File('${subDir.path}/$fileName');
    await source.copy(dest.path);
    debugPrint('Saved to: ${dest.path}');
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-]'), '_').replaceAll(RegExp(r'_+'), '_');
  }
}
