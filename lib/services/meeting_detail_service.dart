import 'dart:math';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/models/participant_detail.dart';

class MeetingDetailService {
  Future<MeetingDetail> fetchMeetingDetail(String meetingId) async {
    // Simulate network delay to mimic a real API call
    await Future.delayed(const Duration(seconds: 2));

    // For demonstration, let's randomly throw an error sometimes
    if (Random().nextDouble() < 0.1) { // 10% chance of error
      throw Exception('Failed to connect to the server. Please check your network.');
    }

    // Generate a list of mock participants
    final participants = List.generate(15, (index) {
      final joinTime = DateTime.now().subtract(Duration(minutes: Random().nextInt(60)));
      final leaveTime = Random().nextBool() ? joinTime.add(Duration(minutes: Random().nextInt(30) + 5)) : null;
      return ParticipantDetail(
        userId: 'ID${1000 + index}',
        username: 'User ${String.fromCharCode(65 + index)}', // User A, User B, etc.
        joinTime: joinTime,
        leaveTime: leaveTime,
      );
    });

    // Create a mock MeetingDetail object
    return MeetingDetail(
      meetingTitle: 'Q3 Project Kick-off',
      meetingId: meetingId,
      meetingPass: 'SECURE2024',
      hostName: 'John Doe',
      hostId: 'HOST001',
      maxParticipants: 50,
      duration: const Duration(hours: 1),
      scheduledStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
      scheduledEndTime: DateTime.now().add(const Duration(minutes: 50)),
      actualStartTime: DateTime.now().subtract(const Duration(minutes: 8)),
      actualEndTime: null, // Meeting is ongoing
      status: 'ongoing',
      totalUniqueParticipants: participants.length,
      participants: participants,
    );
  }
}
