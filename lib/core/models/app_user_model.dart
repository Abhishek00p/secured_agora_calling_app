import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';

class AppUser {
  final int userId;
  final String firebaseUserId;
  final String name;
  final String email;
  final bool isMember;
  final DateTime createdAt;
  final Subscription subscription;
  final String memberCode;
  final String? planExpiryDate;

  AppUser({
    this.name = '',
    this.email = '',
    this.userId = 0,
    this.firebaseUserId = '',
    this.isMember = false,
    this.memberCode = '',
    this.planExpiryDate,
    DateTime? createdAt,
    Subscription? subscription,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       subscription = subscription ?? Subscription.toEmpty();

  factory AppUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AppUser.toEmpty();

    return AppUser(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isMember: json['isMember'] as bool? ?? false,
      userId: json['userId'] ?? 0,
      firebaseUserId: json['firebaseUserId'] ?? '',
      memberCode: json['memberCode'] as String? ?? '',
      createdAt:
          json['createdAt'] is String
              ? DateTime.parse(json['createdAt'])
              : json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp?)?.toDate()
              : null,
      subscription: Subscription.fromJson(json['subscription']),
      planExpiryDate:
          json['planExpiryDate'] == null ||
                  json['planExpiryDate'].toString().trim().isEmpty
              ? null
              : json['planExpiryDate'].toString().toDateTime.formatDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'isMember': isMember,
      'createdAt': createdAt.toIso8601String(),
      'subscription': subscription.toJson(),
      'userId': userId,
      'firebaseUserId': firebaseUserId,
      'memberCode': memberCode,
      'planExpiryDate': planExpiryDate,
    };
  }

  bool get isEmpty => name.isEmpty && email.isEmpty;
  static AppUser toEmpty() => AppUser();

  AppUser copyWith({
    String? name,
    String? email,
    bool? isMember,
    DateTime? createdAt,
    Subscription? subscription,
    int? userId,
    String? firebaseUserId,
    String? memberCode,
  }) {
    return AppUser(
      name: name ?? this.name,
      userId: userId ?? this.userId,
      firebaseUserId: firebaseUserId ?? this.firebaseUserId,
      email: email ?? this.email,
      isMember: isMember ?? this.isMember,
      createdAt: createdAt ?? this.createdAt,
      subscription: subscription ?? this.subscription,
      memberCode: memberCode ?? this.memberCode,
    );
  }

  @override
  String toString() {
    return 'AppUser(userId: $userId, firebaseUserId: $firebaseUserId, name: $name, email: $email, isMember: $isMember, memberCode: $memberCode, createdAt: $createdAt, subscription: $subscription)';
  }
}

class Subscription {
  final String plan;
  final DateTime startDate;
  final DateTime expiryDate;

  Subscription({this.plan = '', DateTime? startDate, DateTime? expiryDate})
    : startDate = startDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiryDate = expiryDate ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Subscription.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Subscription.toEmpty();
    print(
      " we are inside usermodel parsing user data and subscription data re : $json",
    );
    return Subscription(
      plan: json['plan'] as String? ?? '',
      startDate:
          json['startDate'] is String
              ? DateTime.parse(json['startDate'])
              : json['startDate'] is Timestamp
              ? (json['startDate'] as Timestamp?)?.toDate()
              : null,
      expiryDate:
          json['expiryDate'] is String
              ? DateTime.parse(json['expiryDate'])
              : json['expiryDate'] is Timestamp
              ? (json['expiryDate'] as Timestamp?)?.toDate()
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
    };
  }

  bool get isEmpty => plan.isEmpty;
  static Subscription toEmpty() => Subscription();

  Subscription copyWith({
    String? plan,
    DateTime? startDate,
    DateTime? expiryDate,
  }) {
    return Subscription(
      plan: plan ?? this.plan,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  String toString() {
    return 'Subscription(plan: $plan, startDate: $startDate, expiryDate: $expiryDate)';
  }
}
