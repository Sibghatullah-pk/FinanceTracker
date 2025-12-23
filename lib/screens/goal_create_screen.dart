import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class GoalCreateScreen extends StatefulWidget {
  const GoalCreateScreen({super.key});

  @override
  State<GoalCreateScreen> createState() => _GoalCreateScreenState();
}

class _GoalCreateScreenState extends State<GoalCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _deadline;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Goal'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Goal title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Goal title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Target amount
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Target amount (Rs.)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Deadline picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _deadline == null
                      ? 'Pick deadline'
                      : _deadline!.toLocal().toString().split(' ').first,
                ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 30)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Submit button
              ElevatedButton.icon(
                onPressed: () async {
                  if (!_formKey.currentState!.validate() || _deadline == null) {
                    if (_deadline == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please pick a deadline')),
                      );
                    }
                    return;
                  }

                  final title = _titleCtrl.text.trim();
                  final amount = double.parse(_amountCtrl.text.trim());
                  final notes = _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim();

                  final err = await context.read<AppState>().createGoal(
                        title: title,
                        targetAmount: amount,
                        deadline: _deadline!,
                        notes: notes,
                      );

                  if (err == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Goal created')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Create Goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
