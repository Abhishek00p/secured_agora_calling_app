import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/home/views/delete_confirmation_dialog.dart';
import 'package:secured_calling/features/home/views/user_creation_form.dart';
import 'package:secured_calling/widgets/persistent_call_bar.dart';
import 'package:secured_calling/widgets/user_credentials_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = AppLocalStorage.getUserDetails();
      final users = await AppFirebaseService.instance.getUsersByMemberCodeData(currentUser.memberCode);
      print('Total users fetched: ${users.length}');
      // Filter users based on member code
      final filteredUsers = users.where((user) => user.memberCode == currentUser.memberCode).toList();

      setState(() {
        _users = filteredUsers;
        _filteredUsers = filteredUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users \n $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers =
          _users.where((user) {
            final name = user.name.toLowerCase();
            final email = user.email.toLowerCase();
            final searchLower = query.toLowerCase();
            return name.contains(searchLower) || email.contains(searchLower);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Associated Users'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          const PersistentCallBar(),
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Users List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                        ],
                      ),
                    )
                    : _filteredUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty ? 'No users found' : 'No users match your search',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (_searchController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterUsers('');
                              },
                              child: const Text('Clear search'),
                            ),
                          ],
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  if (user.createdAt != null)
                                    Text(
                                      'Joined: ${_formatDate(user.createdAt)}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            trailing: InkWell(
                              onTap: () {
                                UserCredentialsBottomSheet.show(
                                  context,
                                  targetEmail: user.email,
                                  targetName: user.name,
                                  isMember: false,
                                  userId: user.userId.toString(),
                                );
                              },
                              child: Card(
                                color: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  child: Text('View more', style: TextStyle(fontSize: 12, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserCreationForm()),
          );
          // Reload users after creation
          if (result == true) {
            _loadUsers();
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
