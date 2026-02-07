import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ClipAudioDownloader {
  Future<File> saveToDownloads(File source) async {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = "";

    final mediaStore = MediaStore();

    if (await Permission.storage.isGranted) {
      final result = await mediaStore.saveFile(tempFilePath: source.path, dirType: DirType.download, dirName: DirName.download);

      if (result == null) {
        throw Exception("Failed to save to Downloads");
      }

      return File(result.uri.toFilePath());
    } else if (await Permission.storage.isDenied || await Permission.storage.isLimited) {
      debugPrint("Storage permission was not granted");
      PermissionStatus status = await Permission.storage.request();

      if (status != PermissionStatus.granted) {
        throw Exception("Storage permission not granted");
      }
      final result = await mediaStore.saveFile(tempFilePath: source.path, dirType: DirType.download, dirName: DirName.download);

      if (result == null) {
        throw Exception("Failed to save to Downloads");
      }

      return File(result.uri.toFilePath());
    } else {
      throw Exception("Storage permission not granted or permanently denied");
    }
  }

  Future<File> downloadClip({required String m3u8Url, required Duration clipStart, required Duration clipEnd}) async {
    final tempDir = await getTemporaryDirectory();

    /// STEP 1 — Download playlist
    final playlistResponse = await http.get(Uri.parse(m3u8Url));

    if (playlistResponse.statusCode != 200) {
      debugPrint("Playlist error → ${playlistResponse.statusCode}");
      throw Exception("Failed to fetch playlist");
    }

    final lines = playlistResponse.body.split('\n');

    double timeline = 0;
    final selectedSegments = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXTINF')) {
        final duration = double.parse(lines[i].split(':')[1].replaceAll(',', ''));

        final segmentLine = lines[i + 1].trim();

        final segStart = Duration(milliseconds: (timeline * 1000).toInt());
        final segEnd = Duration(milliseconds: ((timeline + duration) * 1000).toInt());

        if (segEnd > clipStart && segStart < clipEnd) {
          final resolved = Uri.parse(m3u8Url).resolve(segmentLine).toString();

          selectedSegments.add(resolved);
        }

        timeline += duration;
      }
    }

    if (selectedSegments.isEmpty) {
      throw Exception("No segments found");
    }

    /// STEP 2 — Download segments
    final segmentPaths = <String>[];

    for (int i = 0; i < selectedSegments.length; i++) {
      final res = await http.get(Uri.parse(selectedSegments[i]));

      if (res.statusCode != 200) {
        throw Exception("Segment download failed");
      }

      final path = '${tempDir.path}/seg_$i.ts';
      final file = File(path);

      await file.writeAsBytes(res.bodyBytes);

      segmentPaths.add(path);
    }

    /// sanity check
    for (final p in segmentPaths) {
      if (!await File(p).exists()) {
        throw Exception("Missing segment file");
      }
    }

    /// STEP 3 — concat file (escaped paths)
    final concatFile = File('${tempDir.path}/concat.txt');

    final concatContent = segmentPaths.map((p) => "file '${p.replaceAll("'", "\\'")}'").join('\n');

    await concatFile.writeAsString(concatContent);

    debugPrint("Concat file →\n$concatContent");

    /// STEP 4 — FFmpeg merge
    final outputPath = '${tempDir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final command = "-f concat -safe 0 -i ${concatFile.path} -vn -acodec aac $outputPath";

    debugPrint("FFmpeg CMD → $command");

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    debugPrint("FFmpeg return code → $returnCode");

    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getAllLogsAsString();
      debugPrint("FFmpeg logs →\n$logs");
      throw Exception("FFmpeg merge failed");
    }

    /// STEP 5 — Save to Downloads
    final downloadedFile = await saveToDownloads(File(outputPath));

    return downloadedFile;
  }
}
