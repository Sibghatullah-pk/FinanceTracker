import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'login_screen.dart';
import 'join_household_screen.dart';
import 'join_requests_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primary
                              .withAlpha((0.1 * 255).round()),
                          child: Text(
                            appState.currentUser?.name
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(appState.currentUser?.name ?? 'User',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      )),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: appState.isAdmin
                                          ? Colors.green[100]
                                          : Colors.blue[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      appState.isAdmin
                                          ? 'ADMIN'
                                          : 'CONTRIBUTOR',
                                      style: TextStyle(
                                        color: appState.isAdmin
                                            ? Colors.green[800]
                                            : Colors.blue[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(appState.currentUser?.email ?? '',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!appState.isAdmin)
                  Card(
                    color: Colors.blue[50],
                    child: const ListTile(
                      leading: Icon(Icons.info_outline, color: Colors.blue),
                      title: Text('Contributor Permissions'),
                      subtitle: Text(
                        'You can add expenses and comments. Only the admin can add income, edit budget, or delete transactions.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Household Section
                Text('Household',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 12),

                if (appState.hasHousehold) ...[
                  // Invite Code Card (Admin only)
                  if (appState.isAdmin)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.share,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Invite Member',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share this code with family members to link accounts',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      appState.household?.inviteCode ?? '',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                      text:
                                          appState.household?.inviteCode ?? '',
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Code copied to clipboard!'),
                                        backgroundColor:
                                            theme.colorScheme.secondary,
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.copy,
                                      color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Members list
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Household Members'),
                      subtitle: Text('${appState.members.length} members'),
                      onTap: () => _showMembersDialog(context, appState),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Join requests (Admin only)
                  if (appState.isAdmin)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.how_to_reg),
                        title: const Text('Join Requests'),
                        subtitle:
                            const Text('View and accept pending requests'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const JoinRequestsScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Budget setting (Admin only)
                  if (appState.isAdmin)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet),
                        title: const Text('Monthly Budget'),
                        subtitle: Text(
                            'Rs. ${appState.monthlyLimit.toStringAsFixed(0)}'),
                        onTap: () => _showBudgetDialog(context, appState),
                      ),
                    ),
                ] else ...[
                  // Join household
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.group_add),
                      title: const Text('Join Household'),
                      subtitle: const Text('Enter invite code to join'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinHouseholdScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // App Section
                Text('App',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('Notifications'),
                        subtitle: const Text('Manage notification preferences'),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('About'),
                        subtitle: const Text('Version 1.0.0'),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Account Section
                Text('Account',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      if (appState.hasHousehold)
                        ListTile(
                          leading: Icon(Icons.exit_to_app,
                              color: theme.colorScheme.error),
                          title: const Text('Leave Household'),
                          subtitle:
                              const Text('Remove yourself from the household'),
                          onTap: () => _showLeaveDialog(context, appState),
                        ),
                      if (appState.hasHousehold) const Divider(height: 1),
                      ListTile(
                        leading:
                            Icon(Icons.logout, color: theme.colorScheme.error),
                        title: const Text('Sign Out'),
                        subtitle: const Text('Sign out of your account'),
                        onTap: () => _showLogoutDialog(context, appState),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMembersDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => Consumer<AppState>(
        builder: (context, appState, _) => AlertDialog(
          title: const Text('Household Members'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: appState.members.map((member) {
              final role =
                  appState.household?.roles[member.uid] ?? 'contributor';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withAlpha((0.1 * 255).round()),
                  child: Text(
                    member.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(member.name),
                subtitle: Text(role.toUpperCase()),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(
      text: appState.monthlyLimit.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Rs. ',
            labelText: 'Budget Amount',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                appState.updateBudgetLimit(amount);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Household'),
        content: const Text(
          'Are you sure you want to leave this household? You will lose access to shared expenses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              appState.leaveHousehold();
              Navigator.pop(context);
            },
            child: Text(
              'Leave',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              appState.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
