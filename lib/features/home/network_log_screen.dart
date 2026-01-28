import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class NetworkLogScreen extends StatefulWidget {
  const NetworkLogScreen({super.key});

  @override
  State<NetworkLogScreen> createState() => _NetworkLogScreenState();
}

class _NetworkLogScreenState extends State<NetworkLogScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = AppApiFunctionLogger.instance.getAllLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                AppApiFunctionLogger.instance.clearLogs();
              });
            },
          ),
        ],
      ),
      body:
          logs.isEmpty
              ? const Center(child: Text('No network calls yet'))
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _NetworkLogTile(log: log);
                },
              ),
    );
  }
}

class _NetworkLogTile extends StatelessWidget {
  final FunctionCallLog log;

  const _NetworkLogTile({required this.log});

  Color get _statusColor {
    if (log.statusCode == null) return AppTheme.warningColor;
    if (log.statusCode! >= 200 && log.statusCode! < 300) {
      return AppTheme.successColor;
    }
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(log.url.split('/api').last, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${log.statusCode ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _statusColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Text('${log.timeTakenMs ?? 0} ms', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        children: [
          _kv('Method', log.method),
          _kv('URL', log.url),
          _kv('Started', log.startTime.toIso8601String()),
          if (log.responseBody != null) _kv('Response', log.responseBody!),
          if (log.error != null) _kv('Error', log.error!),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: log.curl));
                AppToastUtil.showSuccessToast('cURL copied');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy cURL'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(v, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
