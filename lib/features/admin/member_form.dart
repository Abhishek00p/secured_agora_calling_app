import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';

class MemberForm extends StatefulWidget {
  final Member? member;
  const MemberForm({super.key, this.member});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController name, email, days, users;
  DateTime purchaseDate = DateTime.now();
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.member?.name ?? '');
    email = TextEditingController(text: widget.member?.email ?? '');
    days = TextEditingController(text: widget.member?.planDays.toString() ?? '');
    users = TextEditingController(text: widget.member?.totalUsers.toString() ?? '');
    purchaseDate = widget.member?.purchaseDate ?? DateTime.now();
    isActive = widget.member?.isActive ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    days.dispose();
    users.dispose();
    super.dispose();
  }

  void _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    final data = Member(
      id: widget.member?.id ?? '',
      name: name.text.trim(),
      email: email.text.trim(),
      purchaseDate: purchaseDate,
      planDays: int.parse(days.text),
      isActive: isActive,
      totalUsers: int.parse(users.text),
    );

    final ref = FirebaseFirestore.instance.collection('members');
    if (widget.member == null) {
      await ref.add(data.toMap());
    } else {
      await ref.doc(data.id).set(data.toMap());
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.member == null ? "Add Member" : "Edit Member")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              24.h,
              TextFormField(controller: name, decoration: const InputDecoration(labelText: "Name"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              TextFormField(controller: email, decoration: const InputDecoration(labelText: "Email"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              TextFormField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Subscription Days"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              TextFormField(controller: users, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total Users"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Active"),
                  Switch(value: isActive, onChanged: (v) => setState(() => isActive = v)),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveMember,
                child: const Text("Save Member"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
