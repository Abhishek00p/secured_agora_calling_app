import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  String id;
  String name;
  String email;
  DateTime purchaseDate;
  int planDays;
  bool isActive;
  int totalUsers;
  String memberCode;
  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.purchaseDate,
    required this.planDays,
    required this.isActive,
    required this.totalUsers,
    this.memberCode = '',
  });

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    return Member(
      id: id,
      name: data['name'],
      email: data['email'],
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      planDays: data['planDays'],
      isActive: data['isActive'],
      totalUsers: data['totalUsers'],
      memberCode: data['memberCode'] ?? '',
      
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'purchaseDate': purchaseDate,
      'planDays': planDays,
      'isActive': isActive,
      'totalUsers': totalUsers,
      'memberCode': memberCode,
    };
  }

  DateTime get expiryDate => purchaseDate.add(Duration(days: planDays));
}
