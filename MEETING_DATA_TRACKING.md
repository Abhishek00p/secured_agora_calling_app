# Meeting Data Tracking Implementation

## Overview
Enhanced meeting data tracking system that captures comprehensive information about meetings, participants, and meeting statistics in Firestore.

## New Fields Added to Meeting Model

### 1. **Time Tracking Fields**
- `scheduledStartTime`: When the meeting was scheduled to start
- `scheduledEndTime`: When the meeting was scheduled to end
- `actualStartTime`: When the meeting actually started (nullable)
- `actualEndTime`: When the meeting actually ended (nullable)
- `createdAt`: When the meeting was created

### 2. **Meeting Statistics**
- `totalParticipantsCount`: Total number of unique participants throughout the meeting
- `actualDuration`: Actual duration of the meeting in seconds

### 3. **Detailed Participant Tracking**
- `participantHistory`: List of `ParticipantLog` objects tracking each participant's session

## ParticipantLog Model

```dart
class ParticipantLog {
  final int userId;
  final String userName;
  final DateTime joinTime;
  final DateTime? leaveTime;
  final Duration? duration;
}
```

### Fields:
- `userId`: Unique identifier of the participant
- `userName`: Display name of the participant
- `joinTime`: When the participant joined the meeting
- `leaveTime`: When the participant left (nullable if still in meeting)
- `duration`: How long the participant stayed in the meeting

## Data Flow

### 1. **Meeting Creation**
```dart
// Creates meeting with initial tracking fields
await createMeeting({
  hostId: 'host123',
  meetingName: 'Team Meeting',
  scheduledStartTime: DateTime.now(),
  duration: 60, // minutes
  // ... other fields
});
```

**Firestore Document Created:**
```json
{
  "meet_id": "meeting123",
  "meetingName": "Team Meeting",
  "scheduledStartTime": "2024-01-15T10:00:00.000Z",
  "scheduledEndTime": "2024-01-15T11:00:00.000Z",
  "actualStartTime": null,
  "actualEndTime": null,
  "totalParticipantsCount": 0,
  "actualDuration": 0,
  "participantHistory": [],
  "status": "scheduled"
}
```

### 2. **Meeting Start**
```dart
// Records actual start time when meeting begins
await startMeeting(meetingId);
```

**Firestore Update:**
```json
{
  "status": "live",
  "actualStartTime": "2024-01-15T10:05:00.000Z"
}
```

### 3. **Participant Joins**
```dart
// Tracks participant join with detailed information
await addParticipants(meetingId, userId);
```

**Firestore Update:**
```json
{
  "participants": [123, 456],
  "allParticipants": [123, 456],
  "totalParticipantsCount": 2,
  "participantHistory": [
    {
      "userId": 123,
      "userName": "John Doe",
      "joinTime": "2024-01-15T10:05:30.000Z",
      "leaveTime": null,
      "duration": null
    },
    {
      "userId": 456,
      "userName": "Jane Smith",
      "joinTime": "2024-01-15T10:06:00.000Z",
      "leaveTime": null,
      "duration": null
    }
  ]
}
```

### 4. **Participant Leaves**
```dart
// Records leave time and calculates duration
await removeParticipants(meetingId, userId);
```

**Firestore Update:**
```json
{
  "participants": [456],
  "participantHistory": [
    {
      "userId": 123,
      "userName": "John Doe",
      "joinTime": "2024-01-15T10:05:30.000Z",
      "leaveTime": "2024-01-15T10:45:00.000Z",
      "duration": 2370
    },
    {
      "userId": 456,
      "userName": "Jane Smith",
      "joinTime": "2024-01-15T10:06:00.000Z",
      "leaveTime": null,
      "duration": null
    }
  ]
}
```

### 5. **Meeting Ends**
```dart
// Records end time and calculates total duration
// Triggered when last participant leaves
```

**Firestore Update:**
```json
{
  "status": "ended",
  "actualEndTime": "2024-01-15T11:15:00.000Z",
  "actualDuration": 4200
}
```

## Analytics Methods

### 1. **Get Meeting Statistics**
```dart
final stats = await getMeetingStatistics(meetingId);
// Returns:
{
  "totalParticipants": 5,
  "completedSessions": 4,
  "averageSessionDuration": 1800, // seconds
  "actualMeetingDuration": 4200, // seconds
  "scheduledDuration": 3600 // seconds
}
```

### 2. **Get Participant History**
```dart
final history = await getParticipantHistory(meetingId);
// Returns list of participant logs with join/leave times
```

### 3. **Get Meetings with Participant Count**
```dart
final meetings = await getMeetingsWithParticipantCount();
// Returns meetings with participantCount field
```

## Use Cases

### 1. **Meeting Analytics**
- Track meeting attendance
- Calculate average session duration
- Compare scheduled vs actual duration
- Identify most/least engaged participants

### 2. **Reporting**
- Generate meeting reports
- Track participant engagement
- Monitor meeting efficiency
- Historical meeting data analysis

### 3. **User Experience**
- Show participant count in meeting list
- Display meeting duration
- Track individual participation
- Meeting history for users

### 4. **Admin Features**
- Meeting statistics dashboard
- Participant engagement metrics
- Meeting performance analysis
- Usage analytics

## Data Structure in Firestore

### Meeting Document Example:
```json
{
  "meet_id": "meeting123",
  "meetingName": "Weekly Team Sync",
  "hostId": "host123",
  "hostName": "John Manager",
  "scheduledStartTime": "2024-01-15T10:00:00.000Z",
  "scheduledEndTime": "2024-01-15T11:00:00.000Z",
  "actualStartTime": "2024-01-15T10:05:00.000Z",
  "actualEndTime": "2024-01-15T11:15:00.000Z",
  "createdAt": "2024-01-15T09:30:00.000Z",
  "totalParticipantsCount": 5,
  "actualDuration": 4200,
  "duration": 60,
  "status": "ended",
  "participantHistory": [
    {
      "userId": 123,
      "userName": "Alice Johnson",
      "joinTime": "2024-01-15T10:05:30.000Z",
      "leaveTime": "2024-01-15T11:10:00.000Z",
      "duration": 3870
    },
    {
      "userId": 456,
      "userName": "Bob Smith",
      "joinTime": "2024-01-15T10:06:00.000Z",
      "leaveTime": "2024-01-15T11:15:00.000Z",
      "duration": 4140
    }
  ],
  "participants": [],
  "allParticipants": [123, 456, 789, 101, 112],
  "maxParticipants": 10,
  "requiresApproval": false,
  "password": null,
  "memberCode": "TEAM2024"
}
```

## Benefits

1. **Comprehensive Tracking**: Complete meeting lifecycle tracking
2. **Detailed Analytics**: Rich data for reporting and insights
3. **User Engagement**: Track individual participation patterns
4. **Performance Monitoring**: Compare scheduled vs actual meeting times
5. **Historical Data**: Maintain complete meeting history
6. **Scalable**: Efficient data structure for large-scale usage

## Implementation Notes

- All timestamps stored in ISO 8601 format
- Duration calculated in seconds for precision
- Participant history preserved even after meeting ends
- Automatic calculation of meeting statistics
- Efficient queries for analytics and reporting
