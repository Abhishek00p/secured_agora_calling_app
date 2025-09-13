import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for join requests stored in Firestore sub-collection
/// Structure: /meetings/{meetingId}/joinRequests/{requestId}
class JoinRequestModel {
  final String requestId;
  final int userId;
  final String status; // 'pending', 'accepted', 'rejected', 'joined'
  final DateTime requestedAt;
  final String? userName; // Optional: store for easier display
  final String? userEmail; // Optional: store for easier display

  const JoinRequestModel({
    required this.requestId,
    required this.userId,
    required this.status,
    required this.requestedAt,
    this.userName,
    this.userEmail,
  });

  /// Create from Firestore document
  factory JoinRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JoinRequestModel(
      requestId: doc.id,
      userId: data['userId'] as int,
      status: data['status'] as String,
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      userName: data['userName'] as String?,
      userEmail: data['userEmail'] as String?,
    );
  }

  /// Create from Map
  factory JoinRequestModel.fromMap(Map<String, dynamic> map) {
    return JoinRequestModel(
      requestId: map['requestId'] as String,
      userId: map['userId'] as int,
      status: map['status'] as String,
      requestedAt: (map['requestedAt'] as Timestamp).toDate(),
      userName: map['userName'] as String?,
      userEmail: map['userEmail'] as String?,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (userName != null) 'userName': userName,
      if (userEmail != null) 'userEmail': userEmail,
    };
  }

  /// Create a copy with updated fields
  JoinRequestModel copyWith({
    String? requestId,
    int? userId,
    String? status,
    DateTime? requestedAt,
    String? userName,
    String? userEmail,
  }) {
    return JoinRequestModel(
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  /// Check if request is pending
  bool get isPending => status == 'pending';

  /// Check if request is accepted
  bool get isAccepted => status == 'accepted';

  /// Check if request is rejected
  bool get isRejected => status == 'rejected';

  /// Check if request is joined (user has successfully joined)
  bool get isJoined => status == 'joined';

  @override
  String toString() {
    return 'JoinRequestModel(requestId: $requestId, userId: $userId, status: $status, requestedAt: $requestedAt, userName: $userName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JoinRequestModel &&
        other.requestId == requestId &&
        other.userId == userId &&
        other.status == status &&
        other.requestedAt == requestedAt &&
        other.userName == userName &&
        other.userEmail == userEmail;
  }

  @override
  int get hashCode {
    return requestId.hashCode ^
        userId.hashCode ^
        status.hashCode ^
        requestedAt.hashCode ^
        userName.hashCode ^
        userEmail.hashCode;
  }
}
