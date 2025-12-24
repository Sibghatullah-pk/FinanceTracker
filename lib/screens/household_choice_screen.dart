import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'join_household_screen.dart';

class HouseholdChoiceScreen extends StatelessWidget {
  const HouseholdChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household Setup')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final appState = context.read<AppState>();
                final success = await appState.createHousehold();
                if (success) {
                  Navigator.pushReplacementNamed(context, '/main');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create household')),
                  );
                }
              },
              child: const Text('Create Household'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinHouseholdScreen()),
                );
              },
              child: const Text('Join Household'),
            ),
          ],
        ),
      ),
    );
  }
}
