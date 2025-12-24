import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class JoinRequestsScreen extends StatelessWidget {
  const JoinRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final householdId = appState.household?.id;
    if (householdId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Join Requests')),
        body: const Center(child: Text('No household selected')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('join_requests')
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'User';
              final email = data['email'] ?? '';
              final userId = data['userId'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(email +
                      (createdAt != null
                          ? ' • ${createdAt.toLocal().toString().split(" ").first}'
                          : '')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          final ok = await appState.acceptJoinRequest(
                              d.id, userId, householdId);
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Failed to accept request')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          final ok = await appState.rejectJoinRequest(d.id);
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Failed to reject request')));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
