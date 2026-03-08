import 'dart:async';

/// Controls a single in-flight download: supports pause, resume, and cancel.
///
/// The download loop calls [checkPoint] at every segment boundary.
/// - If cancelled, [checkPoint] throws [DownloadCancelledException].
/// - If paused, [checkPoint] suspends until [resume] or [cancel] is called.
class DownloadController {
  bool _cancelled = false;
  bool _paused = false;
  Completer<void>? _pauseCompleter;

  bool get isCancelled => _cancelled;
  bool get isPaused => _paused;

  /// Pauses the download. A [checkPoint] call that follows will suspend until
  /// [resume] or [cancel] is invoked.
  void pause() {
    if (_cancelled || _paused) return;
    _paused = true;
    _pauseCompleter = Completer<void>();
  }

  /// Resumes a paused download.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
  }

  /// Cancels the download. Also unblocks any pause suspension so the loop
  /// can exit cleanly.
  void cancel() {
    _cancelled = true;
    if (_paused) {
      _paused = false;
      _pauseCompleter?.complete();
      _pauseCompleter = null;
    }
  }

  /// Called by the download loop at each segment boundary.
  /// Throws [DownloadCancelledException] if cancelled.
  /// Suspends (awaits) if paused until resumed or cancelled.
  Future<void> checkPoint() async {
    if (_cancelled) throw const DownloadCancelledException();
    if (_paused) {
      await _pauseCompleter!.future;
      // Re-check after unblocking (cancel() also completes the completer).
      if (_cancelled) throw const DownloadCancelledException();
    }
  }
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'Download was cancelled by the user';
}
