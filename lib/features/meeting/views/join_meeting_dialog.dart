import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

class JoinMeetingDialog extends StatefulWidget {
  const JoinMeetingDialog({super.key});

  @override
  State<JoinMeetingDialog> createState() => _JoinMeetingDialogState();
}

class _JoinMeetingDialogState extends State<JoinMeetingDialog> {
  final TextEditingController _meetingIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _meetingFound = false;
  String? _meetingId;
  Map<String, dynamic>? _meetingData;

  @override
  void dispose() {
    _meetingIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _searchMeeting() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _meetingFound = false;
      _meetingData = null;
      _meetingId = null;
    });

    try {
      final channelName = _meetingIdController.text.trim();
      final documentSnapshot = await _firebaseService.searchMeetingByMeetId(
        _meetingIdController.text,
        channelName,
      );

      if (documentSnapshot == null || !documentSnapshot.exists) {
        setState(() {
          _errorMessage = 'No active meeting found with this ID';
          _isLoading = false;
        });
        return;
      }

      final meetingData = documentSnapshot.data() as Map<String, dynamic>;

      // Check password if required
      if (meetingData['password'] != null &&
          meetingData['password'].isNotEmpty) {
        final enteredPassword = _passwordController.text;
        if (enteredPassword != meetingData['password']) {
          setState(() {
            _errorMessage = 'Incorrect password for this meeting';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _meetingFound = true;
        _meetingData = meetingData;
        _meetingId = documentSnapshot.id;
        _isLoading = false;
      });

      // If the meeting doesn't require approval, join immediately
      // Otherwise, request to join
      if (meetingData['requiresApproval'] == false) {
        _joinMeeting();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching for meeting: $e';
        _isLoading = false;
      });
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _listener;

  void listenForParticipantAddition(String meetingId, int userId) {
    _listener = _firestore
        .collection('meetings')
        .doc(meetingId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final List<dynamic> participants = data['participants'] ?? [];

            if (participants.contains(userId)) {
              // User has been added to the participants list, stop listening
              _listener?.cancel(); // Stop listening to prevent further triggers

              _meetingData = {'channelName': 'testing'};
              _joinMeeting(); // Pass meeting data if needed
            }
          }
        });
  }

  Future<void> _requestToJoin() async {
    if (_meetingId == null || _meetingData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AppLocalStorage.getUserDetails().userId;
      await _firebaseService.requestToJoinMeeting(_meetingId!, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request sent to join ${_meetingData!['meetingName']}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        listenForParticipantAddition(_meetingId ?? '-', userId);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error requesting to join: $e';
        _isLoading = false;
      });
    }
  }

  void _joinMeeting() {
    if (_meetingData == null) return;

    Navigator.pop(context); // Close dialog
    Navigator.pushNamed(
      context,
      AppRouter.meetingRoomRoute,
      arguments: {
        'channelName': _meetingData!['channelName'],
        'isHost': false,
        'meetingId': _meetingId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Join Meeting',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Meeting ID Field
              AppTextFormField(
                controller: _meetingIdController,
                labelText: 'Meeting ID',
                type: AppTextFormFieldType.text,
              ),
              const SizedBox(height: 16),

              // Password Field (Optional)
              AppTextFormField(
                controller: _passwordController,
                labelText: 'Password (Optional)',
                type: AppTextFormFieldType.password,
                isPasswordRequired: false ,
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Meeting Found UI
              if (_meetingFound && _meetingData != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Found: ${_meetingData!['meetingName']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Host: ${_meetingData!['hostId']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_meetingData!['requiresApproval'] == true) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'This meeting requires host approval to join',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  if (_meetingFound &&
                      _meetingData != null &&
                      _meetingData!['requiresApproval'] == true) ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _requestToJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Request to Join'),
                    ),
                  ] else if (_meetingFound && _meetingData != null) ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _joinMeeting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Join Now'),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _searchMeeting,
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Search'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
