import 'package:flutter/material.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class ExtendMeetingDialog extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final Function(int minutes, String? reason) onExtend;

  const ExtendMeetingDialog({super.key, required this.meetingId, required this.meetingTitle, required this.onExtend});

  @override
  State<ExtendMeetingDialog> createState() => _ExtendMeetingDialogState();
}

class _ExtendMeetingDialogState extends State<ExtendMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  int _selectedMinutes = 30;
  bool _isLoading = false;

  final List<int> _extensionOptions = [30, 60, 120, 180, 240, 300]; // in minutes

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleExtend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onExtend(
        _selectedMinutes,
        _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        AppToastUtil.showSuccessToast('Meeting extended successfully by $_selectedMinutes minutes');
      }
    } catch (e) {
      if (mounted) {
        AppToastUtil.showErrorToast('Failed to extend meeting: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.schedule, color: AppTheme.primaryColor),
          SizedBox(width: padding / 2),
          const Text('Extend Meeting'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth(context)),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Extend "${widget.meetingTitle}"',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: padding),

              Text(
                'Additional Duration:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: padding / 2),
              Wrap(
                spacing: padding / 2,
                runSpacing: padding / 2,
              children:
                  _extensionOptions.map((minutes) {
                    final isSelected = _selectedMinutes == minutes;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMinutes = minutes;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!),
                        ),
                        child: Text(
                          minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h ',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ),
              SizedBox(height: padding),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'Why are you extending this meeting?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
                maxLength: 200,
              ),
              SizedBox(height: padding / 2),
              Text(
                'The meeting will be extended by $_selectedMinutes minutes',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleExtend,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Extend Meeting'),
        ),
      ],
    );
  }
}
