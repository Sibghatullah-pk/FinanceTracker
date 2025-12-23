// lib/providers/app_state.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/transaction.dart' as app;
import '../models/user_model.dart';
import '../models/household.dart';
import '../models/comment.dart';
import '../models/savings_goal.dart';

class AppState extends ChangeNotifier {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // App State
  UserModel? _currentUser;
  Household? _household;

  // Caches
  final List<app.Transaction> _transactions = [];
  final Map<String, List<Comment>> _comments = {}; // transactionId -> List<Comment>
  final Map<String, UserModel> _householdMembers = {};
  final List<SavingsGoal> _goals = [];

  // ================= GETTERS =================
  UserModel? get currentUser => _currentUser;
  Household? get household => _household;
  List<app.Transaction> get transactions => _transactions;
  List<SavingsGoal> get goals => _goals;

  bool get isLoggedIn => _currentUser != null;
  bool get hasHousehold => _household != null;
  bool get isAdmin => _household?.roles[_currentUser?.uid] == 'admin';

  double get totalSpent => _transactions
      .where((t) => t.type == app.TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalIncome => _transactions
      .where((t) => t.type == app.TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get monthlyLimit => _household?.monthlyLimit ?? 0;
  double get remaining => monthlyLimit - totalSpent;
  double get balance => totalIncome - totalSpent;

  List<UserModel> get members => _householdMembers.values.toList();

  // ================= HELPERS =================
  String _generateId({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ================= AUTH =================
  Future<String?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user!;
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return "User document not found";

      _currentUser = UserModel.fromJson(user.uid, userDoc.data()!);

      if (_currentUser!.householdId != null) {
        await _loadHousehold(_currentUser!.householdId!);
        await _loadTransactions();
        await _loadGoals();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signup(
    String name,
    String email,
    String password,
    double monthlyBudget,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user!;
      final householdId = _db.collection('households').doc().id;
      final inviteCode = _generateId();

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'householdId': householdId,
        'monthlyBudget': monthlyBudget,
        'createdAt': Timestamp.now(),
      });

      await _db.collection('households').doc(householdId).set({
        'memberIds': [user.uid],
        'roles': {user.uid: 'admin'},
        'monthlyLimit': monthlyBudget,
        'inviteCode': inviteCode,
      });

      _currentUser = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        householdId: householdId,
      );

      _household = Household(
        id: householdId,
        memberIds: [user.uid],
        roles: {user.uid: 'admin'},
        monthlyLimit: monthlyBudget,
        inviteCode: inviteCode,
      );

      _householdMembers[user.uid] = _currentUser!;

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _household = null;
    _transactions.clear();
    _comments.clear();
    _householdMembers.clear();
    _goals.clear();
    notifyListeners();
  }

  // ================= HOUSEHOLD =================
  Future<void> _loadHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _household = Household(
      id: householdId,
      memberIds: List<String>.from(data['memberIds']),
      roles: Map<String, String>.from(data['roles']),
      monthlyLimit: (data['monthlyLimit'] as num).toDouble(),
      inviteCode: data['inviteCode'],
    );

    // Load member details
    _householdMembers.clear();
    for (final uid in _household!.memberIds) {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        _householdMembers[uid] = UserModel.fromJson(uid, userDoc.data()!);
      }
    }
  }

  Future<void> updateBudgetLimit(double amount) async {
    if (_household == null) return;
    await _db.collection('households').doc(_household!.id).update({
      'monthlyLimit': amount,
    });
    _household = Household(
      id: _household!.id,
      memberIds: _household!.memberIds,
      roles: _household!.roles,
      monthlyLimit: amount,
      inviteCode: _household!.inviteCode,
    );
    notifyListeners();
  }

  Future<bool> joinHousehold(String inviteCode) async {
    try {
      final query = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();
      if (query.docs.isEmpty) return false;

      final householdDoc = query.docs.first;
      final householdId = householdDoc.id;

      await _db.collection('households').doc(householdId).update({
        'memberIds': FieldValue.arrayUnion([_currentUser!.uid]),
        'roles.${_currentUser!.uid}': 'member',
      });

      await _db.collection('users').doc(_currentUser!.uid).update({
        'householdId': householdId,
      });

      await _loadHousehold(householdId);
      await _loadTransactions();
      await _loadGoals();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Join household error: $e");
      return false;
    }
  }

  void leaveHousehold() {
    // TODO: implement leave logic when needed
  }

  // ================= TRANSACTIONS =================
  Future<void> _loadTransactions() async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();

    _transactions
      ..clear()
      ..addAll(snap.docs.map((d) => app.Transaction.fromMap(d.id, d.data())));

    notifyListeners();
  }

  Future<void> addTransaction(app.Transaction transaction) async {
    if (_household == null || _currentUser == null) return;

    final enriched = transaction.copyWith(
      createdBy: _currentUser!.uid,
      createdByName: _currentUser!.name,
    );

    final docRef = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .add(enriched.toMap());

    _transactions.add(enriched.copyWith(id: docRef.id));
    notifyListeners();
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_household == null) return;
    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .delete();
    _transactions.removeWhere((t) => t.id == transactionId);
    notifyListeners();
  }

  // ================= COMMENTS =================
  List<Comment> getComments(String transactionId) => _comments[transactionId] ?? [];

  Future<void> loadComments(String transactionId) async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .get();

    final list = snap.docs.map((d) => Comment.fromJson(d.id, d.data())).toList();
    _comments[transactionId] = list;
    notifyListeners();
  }

  Future<void> addComment(String transactionId, String text) async {
    if (_household == null || _currentUser == null) return;

    final commentCol = _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .collection('comments');

    final docRef = commentCol.doc();

    final commentData = {
      'userId': _currentUser!.uid,
      'userName': _currentUser!.name,
      'text': text,
      'timestamp': Timestamp.now(),
    };

    await docRef.set(commentData);

    final newComment = Comment(
      id: docRef.id,
      userId: _currentUser!.uid,
      userName: _currentUser!.name,
      text: text,
      timestamp: DateTime.now(),
    );

    final list = _comments[transactionId] ?? [];
    list.add(newComment);
    _comments[transactionId] = list;
    notifyListeners();
  }

  // ================= SAVINGS GOALS =================
  Future<void> _loadGoals() async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .orderBy('createdAt', descending: true)
        .get();

    _goals
      ..clear()
      ..addAll(snap.docs.map((d) => SavingsGoal.fromMap(d.id, d.data())));
    notifyListeners();
  }

  Future<String?> createGoal({
    required String title,
    required double targetAmount,
    required DateTime deadline,
    String? notes,
  }) async {
    if (_household == null || _currentUser == null) return 'Not in a household';

    final goalsCol = _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals');

    final docRef = goalsCol.doc();

    final goal = SavingsGoal(
      id: docRef.id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: 0,
      deadline: deadline,
      createdBy: _currentUser!.uid,
      createdAt: DateTime.now(),
      notes: notes,
      archived: false,
    );

    await docRef.set({
      'title': goal.title,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': Timestamp.fromDate(goal.deadline),
      'createdBy': goal.createdBy,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'notes': goal.notes,
      'archived': goal.archived,
    });

    _goals.insert(0, goal);
    notifyListeners();
    return null;
  }

  Future<String?> updateGoal(
    SavingsGoal goal, {
    String? title,
    double? targetAmount,
    DateTime? deadline,
    String? notes,
    bool? archived,
  }) async {
    if (_household == null) return 'Not in a household';

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (targetAmount != null) updates['targetAmount'] = targetAmount;
    if (deadline != null) updates['deadline'] = Timestamp.fromDate(deadline);
    if (notes != null) updates['notes'] = notes;
    if (archived != null) updates['archived'] = archived;

    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goal.id)
        .update(updates);

    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = SavingsGoal(
        id: goal.id,
        title: title ?? goal.title,
        targetAmount: targetAmount ?? goal.targetAmount,
        currentAmount: goal.currentAmount,
        deadline: deadline ?? goal.deadline,
        createdBy: goal.createdBy,
        createdAt: goal.createdAt,
        notes: notes ?? goal.notes,
        archived: archived ?? goal.archived,
      );
      notifyListeners();
    }
    return null;
  }

  Future<String?> allocateToGoal(String goalId, double amount) async {
    if (_household == null || amount <= 0) return 'Invalid amount';

    final docRef = _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goalId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) throw Exception('Goal not found');

      final data = snap.data()!;
      final current = (data['currentAmount'] as num).toDouble();
      final newAmount = current + amount;
      txn.update(docRef, {'currentAmount': newAmount});
    });

    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final g = _goals[idx];
      _goals[idx] = SavingsGoal(
        id: g.id,
        title: g.title,
        targetAmount: g.targetAmount,
        currentAmount: g.currentAmount + amount,
        deadline: g.deadline,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        notes: g.notes,
        archived: g.archived,
      );
      notifyListeners();
    }
    return null;
  }

  Future<void> archiveGoal(String goalId) async {
    if (_household == null) return;

    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goalId)
        .update({'archived': true});

    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final g = _goals[idx];
      _goals[idx] = SavingsGoal(
        id: g.id,
        title: g.title,
        targetAmount: g.targetAmount,
        currentAmount: g.currentAmount,
        deadline: g.deadline,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        notes: g.notes,
        archived: true,
      );
      notifyListeners();
    }
  }

  // ================= REPORTS =================
  Future<void> exportMonthlyReport(int year, int month) async {
    if (_household == null) return;

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

    final query = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final txns = query.docs
        .map((doc) => app.Transaction.fromMap(doc.id, doc.data()))
        .toList();

    final totalExpenses = txns
        .where((t) => t.type == app.TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = txns
        .where((t) => t.type == app.TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final balance = totalIncome - totalExpenses;
    final remainingBudget = monthlyLimit - totalExpenses;

    final categoryBreakdown = <String, double>{};
    for (final t in txns.where((t) => t.type == app.TransactionType.expense)) {
      categoryBreakdown[t.category] =
          (categoryBreakdown[t.category] ?? 0) + t.amount;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Financial Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('Month: $month/$year', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Household Code: ${_household!.inviteCode}',
                style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            pw.Text('Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Amount'],
              data: [
                ['Total Budget', 'Rs. ${monthlyLimit.toStringAsFixed(2)}'],
                ['Total Income', 'Rs. ${totalIncome.toStringAsFixed(2)}'],
                ['Total Expenses', 'Rs. ${totalExpenses.toStringAsFixed(2)}'],
                ['Remaining Budget', 'Rs. ${remainingBudget.toStringAsFixed(2)}'],
                ['Balance (Income - Expense)', 'Rs. ${balance.toStringAsFixed(2)}'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Spending by Category',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Category', 'Amount'],
              data: categoryBreakdown.entries
                  .map((e) => [e.key, 'Rs. ${e.value.toStringAsFixed(2)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('All Transactions',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
              data: txns
                  .map((t) => [
                        t.date.toString().split(' ').first,
                        t.title,
                        t.category,
                        t.type == app.TransactionType.expense ? 'Expense' : 'Income',
                        'Rs. ${t.amount.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
      return;
    }

    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {
      targetDir = null;
    }
    targetDir ??= await getApplicationDocumentsDirectory();

    final filePath = '${targetDir.path}/monthly_report_${month}_$year.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    try {
      await Printing.sharePdf(bytes: bytes, filename: 'monthly_report_${month}_$year.pdf');
    } catch (_) {}
  }

  // ================= DEMO =================
  Future<void> demoLogin() async {
    await signup(
      'Demo User',
      'demo${_generateId()}@mail.com',
      'password',
      50000,
    );
  }
}
