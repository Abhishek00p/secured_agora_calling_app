import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/download_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ── Notification action IDs ────────────────────────────────────────────────
const _kActionPause = 'dl_pause';
const _kActionResume = 'dl_resume';
const _kActionCancel = 'dl_cancel';

// ── Top-level background handler (required by flutter_local_notifications) ──
// Called when the app is in background and the user taps an action button.
@pragma('vm:entry-point')
void _onBackgroundNotificationAction(NotificationResponse response) {
  // The singleton is accessible in the same process (background, not killed).
  DownloadManagerService.instance._dispatch(response);
}

/// Manages the full lifecycle of audio recording downloads:
///
/// • Wakelock – keeps the CPU alive during download + conversion.
/// • Progress notifications with Pause / Resume / Cancel action buttons.
/// • Notification body tap → opens [MeetingDetailPage] for that meeting.
/// • Notification launched app (app was killed) → deferred navigation.
///
/// Notifications are shown on Android and iOS only; the wakelock is enabled
/// on all platforms that support it.
class DownloadManagerService {
  DownloadManagerService._();
  static final DownloadManagerService instance = DownloadManagerService._();

  // ── Notification plugin ────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  static const String _channelId = 'sc_downloads';
  static const String _channelName = 'Downloads';
  static const String _channelDesc = 'Audio recording download progress';

  // ── In-flight download registry ─────────────────────────────────────────
  final Map<String, _DownloadEntry> _active = {};

  // Stores a navigation target when the app was launched from a notification
  // while it was terminated (no route stack yet).
  Map<String, String>? _pendingNavigation;

  bool get hasActiveDownloads => _active.isNotEmpty;

  bool isDownloading(String key) => _active.containsKey(key);

  // ── Init ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_notificationsInitialized) return;
    if (!_notificationsSupported) {
      _notificationsInitialized = true;
      return;
    }

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) await Permission.notification.request();
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _dispatch,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationAction,
    );

    _notificationsInitialized = true;
  }

  /// Called from [main] before [runApp]. Fetches launch details and stores any
  /// pending navigation so the first frame can execute it.
  Future<void> prepareLaunchNavigation() async {
    if (!_notificationsInitialized || !_notificationsSupported) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        final data = _parsePayload(details?.notificationResponse?.payload);
        if (data != null) {
          _pendingNavigation = {'meetingId': data['meetingId'] as String? ?? '', 'meetingName': data['meetingName'] as String? ?? ''};
        }
      }
    } catch (e) {
      debugPrint('[DownloadManagerService] launch details error: $e');
    }
  }

  /// Execute any navigation that was deferred from a terminated-app launch.
  /// Should be called from the first rendered frame (e.g. App widget's
  /// post-frame callback).
  void navigateToPendingIfAny() {
    final nav = _pendingNavigation;
    if (nav == null) return;
    _pendingNavigation = null;
    _navigateToMeeting(nav['meetingId'], nav['meetingName']);
  }

  // ── Public download lifecycle API ────────────────────────────────────────

  Future<void> onDownloadStarted({
    required String downloadKey,
    required String fileName,
    required String meetingId,
    required String meetingName,
    required DownloadController controller,
  }) async {
    _active[downloadKey] = _DownloadEntry(fileName: fileName, meetingId: meetingId, meetingName: meetingName, controller: controller);
    await _safeWakelock(true);
    await _showProgress(downloadKey);
  }

  Future<void> onProgress({required String downloadKey, required int downloaded, required int total}) async {
    final entry = _active[downloadKey];
    if (entry == null) return;
    entry.downloaded = downloaded;
    entry.total = total;
    await _showProgress(downloadKey);
  }

  Future<void> onProcessing({required String downloadKey}) async {
    final entry = _active[downloadKey];
    if (entry == null) return;
    entry.processing = true;
    await _showProgress(downloadKey);
  }

  Future<void> onDownloadComplete({required String downloadKey, required String savedMessage}) async {
    final entry = _active.remove(downloadKey);
    if (!hasActiveDownloads) await _safeWakelock(false);
    await _showComplete(downloadKey, entry?.fileName ?? '', savedMessage, entry?.meetingId, entry?.meetingName);
  }

  Future<void> onDownloadError({required String downloadKey, required String fileName, required String error}) async {
    final entry = _active.remove(downloadKey);
    if (!hasActiveDownloads) await _safeWakelock(false);
    await _showError(downloadKey, fileName, error, entry?.meetingId, entry?.meetingName);
  }

  // ── Pause / Resume / Cancel ──────────────────────────────────────────────

  Future<void> pauseDownload(String downloadKey) async {
    final entry = _active[downloadKey];
    if (entry == null || entry.processing) return;
    entry.controller.pause();
    entry.paused = true;
    await _showProgress(downloadKey);
  }

  Future<void> resumeDownload(String downloadKey) async {
    final entry = _active[downloadKey];
    if (entry == null) return;
    entry.controller.resume();
    entry.paused = false;
    await _showProgress(downloadKey);
  }

  Future<void> cancelDownload(String downloadKey) async {
    final entry = _active.remove(downloadKey);
    if (entry == null) return;
    entry.controller.cancel();
    if (!hasActiveDownloads) await _safeWakelock(false);
    try {
      await _plugin.cancel(id: _notifId(downloadKey));
    } catch (_) {}
  }

  // ── Notification dispatch ────────────────────────────────────────────────

  void _dispatch(NotificationResponse response) {
    if (response.notificationResponseType == NotificationResponseType.selectedNotification) {
      // User tapped the notification body.
      final data = _parsePayload(response.payload);
      if (data != null) {
        _navigateToMeeting(data['meetingId'] as String?, data['meetingName'] as String?);
      }
    } else {
      // User tapped an action button.
      final data = _parsePayload(response.payload);
      final key = data?['downloadKey'] as String?;
      if (key == null) return;

      switch (response.actionId) {
        case _kActionPause:
          pauseDownload(key);
        case _kActionResume:
          resumeDownload(key);
        case _kActionCancel:
          cancelDownload(key);
      }
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _navigateToMeeting(String? meetingId, String? meetingName) {
    if (meetingId == null || meetingId.isEmpty) return;
    try {
      Get.toNamed(AppRouter.meetingDetailRoute, arguments: {'meetingId': meetingId, 'meetingName': meetingName ?? ''});
    } catch (e) {
      debugPrint('[DownloadManagerService] navigation error: $e');
    }
  }

  // ── Notification builders ────────────────────────────────────────────────

  bool get _notificationsSupported => Platform.isAndroid || Platform.isIOS;

  int _notifId(String key) => (_channelId + key).hashCode.abs() % 8000 + 1000;

  String _buildPayload(String downloadKey, String meetingId, String meetingName) {
    return jsonEncode({'downloadKey': downloadKey, 'meetingId': meetingId, 'meetingName': meetingName});
  }

  Map<String, dynamic>? _parsePayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showProgress(String downloadKey) async {
    if (!_notificationsInitialized || !_notificationsSupported) return;
    final entry = _active[downloadKey];
    if (entry == null) return;

    final String body;
    if (entry.processing) {
      body = 'Converting audio…  (cannot pause during conversion)';
    } else if (entry.paused) {
      body = 'Paused — ${entry.downloaded} / ${entry.total} segments';
    } else if (entry.total > 0) {
      final pct = (entry.downloaded / entry.total * 100).toInt();
      body = '${entry.downloaded} / ${entry.total} segments  •  $pct%';
    } else {
      body = 'Preparing…';
    }

    // Build action buttons based on current state.
    final List<AndroidNotificationAction> actions;
    if (entry.processing) {
      // FFmpeg is running — only Cancel is meaningful.
      actions = [const AndroidNotificationAction(_kActionCancel, '✕  Cancel', cancelNotification: false)];
    } else if (entry.paused) {
      actions = [
        const AndroidNotificationAction(_kActionResume, '▶  Resume', cancelNotification: false),
        const AndroidNotificationAction(_kActionCancel, '✕  Cancel', cancelNotification: false),
      ];
    } else {
      actions = [
        const AndroidNotificationAction(_kActionPause, '⏸  Pause', cancelNotification: false),
        const AndroidNotificationAction(_kActionCancel, '✕  Cancel', cancelNotification: false),
      ];
    }

    final payload = _buildPayload(downloadKey, entry.meetingId, entry.meetingName);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showProgress: !entry.processing && !entry.paused,
      maxProgress: entry.total,
      progress: entry.downloaded,
      indeterminate: entry.total == 0 || entry.processing,
      actions: actions,
    );

    try {
      await _plugin.show(
        id: _notifId(downloadKey),
        title: entry.fileName,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DownloadManagerService] show progress error: $e');
    }
  }

  Future<void> _showComplete(String downloadKey, String fileName, String savedMessage, String? meetingId, String? meetingName) async {
    if (!_notificationsInitialized || !_notificationsSupported) return;

    final payload = meetingId != null ? _buildPayload(downloadKey, meetingId, meetingName ?? '') : null;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
      playSound: true,
    );

    try {
      await _plugin.show(
        id: _notifId(downloadKey),
        title: '✅  Download complete',
        body: savedMessage,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DownloadManagerService] show complete error: $e');
    }
  }

  Future<void> _showError(String downloadKey, String fileName, String error, String? meetingId, String? meetingName) async {
    if (!_notificationsInitialized || !_notificationsSupported) return;

    final payload = meetingId != null ? _buildPayload(downloadKey, meetingId, meetingName ?? '') : null;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    try {
      await _plugin.show(
        id: _notifId(downloadKey),
        title: '❌  Download failed — $fileName',
        body: error,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DownloadManagerService] show error notification: $e');
    }
  }

  // ── Wakelock helper ──────────────────────────────────────────────────────

  Future<void> _safeWakelock(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('[DownloadManagerService] wakelock error: $e');
    }
  }
}

// ── Internal model ───────────────────────────────────────────────────────────

class _DownloadEntry {
  final String fileName;
  final String meetingId;
  final String meetingName;
  final DownloadController controller;

  int downloaded = 0;
  int total = 0;
  bool processing = false;
  bool paused = false;

  _DownloadEntry({required this.fileName, required this.meetingId, required this.meetingName, required this.controller});
}
