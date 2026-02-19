import 'package:flutter/material.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String? description;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const DeleteConfirmationDialog({Key? key, this.description, required this.onDelete, required this.onCancel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return AlertDialog(
      title: const Text(
        'Are you sure you want to delete?',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: description != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogMaxWidth(context)),
              child: Padding(
                padding: EdgeInsets.only(right: padding),
                child: Text(description!, style: TextStyle(fontSize: 12)),
              ),
            )
          : null,
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: onDelete,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
      actionsPadding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
    );
  }
}
